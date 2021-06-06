module spi_master
(
	input       sys_clk,	
	input       rst,
	output      nCS,
	output      DCLK,
	output      MOSI,
	input       MISO,
	input       CPOL,
	input       CPHA,
	input       nCS_ctrl,
	input[15:0] clk_div,
	input       wr_req,
	output      wr_ack,
	input[7:0]  data_in,
	output[7:0] data_out
);
localparam IDLE            = 0;
localparam DCLK_EDGE       = 1;
localparam DCLK_IDLE       = 2;
localparam ACK             = 3;
localparam LAST_HALF_CYCLE = 4;
localparam ACK_WAIT        = 5;

reg        DCLK_reg;
reg[7:0]   MOSI_shift;
reg[7:0]   MISO_shift;
reg[2:0]   state;
reg[2:0]   next_state;
reg [15:0] clk_cnt;
reg[4:0]   clk_edge_cnt;

assign MOSI = MOSI_shift[7];
assign DCLK = DCLK_reg;
assign data_out = MISO_shift;
assign wr_ack = (state == ACK);
assign nCS = nCS_ctrl;

always @(posedge sys_clk or posedge rst)
begin
	//重置
	if(rst)
		state <= IDLE;
	//跳转至下一状态
	else
		state <= next_state;
end

always @(*)
begin
	case(state)
		//空闲状态
		IDLE:
			//如果有写请求，则跳转至“DCLK_IDLE”状态
			if(wr_req == 1'b1)
				next_state <= DCLK_IDLE;
			else
				next_state <= IDLE;

//以下实现了8个周期的SPI时钟
		//DCLK空闲状态
		DCLK_IDLE:
			//half a SPI clock cycle produces a clock edge
			if(clk_cnt == clk_div)
				next_state <= DCLK_EDGE;
			else
				next_state <= DCLK_IDLE;
		//DCLK边沿状态
		DCLK_EDGE:
			//通过时钟边沿计数器判定，如果计了16个SPI边沿，则跳转至“LAST_HALF_CYCLE”状态，目的是等第16个周期走完（等最后一个数据发送完成）
			if(clk_edge_cnt == 5'd15)
				next_state <= LAST_HALF_CYCLE;
			//如果还没有计满16个SPI边沿，在下一个sys_clk到来的时候，状态会跳转为“DCLK_IDLE”
			else
				next_state <= DCLK_IDLE;
//以上，两个状态机之间循环，计数16个SPI边沿，共计8个周期SPI时钟

		//等待最后半个周期状态
		LAST_HALF_CYCLE:
			//等待最后半个周期之后，进入应答状态
			if(clk_cnt == clk_div)
				next_state <= ACK;
			else
				next_state <= LAST_HALF_CYCLE; 
		//应答状态 send one byte complete		
		ACK:
			next_state <= ACK_WAIT;
		//应答等待状态 wait for one clock cycle, to ensure that the cancel request signal
		ACK_WAIT:
			next_state <= IDLE;
		default:
			next_state <= IDLE;
	endcase
end
//模拟的一个SPI时钟，处于“DCLK_EDGE”状态才发生跳转变化，并将该模拟SPI时钟输出至模块之外
always @(posedge sys_clk or posedge rst)
begin
	//重置，则将时钟输出拉低
	if(rst)
		DCLK_reg <= 1'b0;
	//如果处于空闲状态，则SPI时钟应当处于空闲状态（SPI空闲状态的时钟电平由CPOL决定，top.v中已经定义CPOL(1'b1)）
	else if(state == IDLE)
		DCLK_reg <= CPOL;
	//处于“DCLK_EDGE”状态时，每个sys_clk上升沿时，都伴随着SPI时钟的跳转
	//由于本案设定clk_div=0，所以每2个sys_clk上升沿才会有1个“DCLK_EDGE”状态，这就导致SPI时钟跳转1下需要2个sys_clk上升沿，即SPI时钟频率为sys_clk的四分之一
	else if(state == DCLK_EDGE)
		DCLK_reg <= ~DCLK_reg;
end
//SPI时钟等待计数器
always @(posedge sys_clk or posedge rst)
begin
	if(rst)
		clk_cnt <= 16'd0;
	//如果处于“DCLK_IDLE”状态或是“LAST_HALF_CYCLE”状态，则开始计数工作
	else if(state == DCLK_IDLE || state == LAST_HALF_CYCLE) 
		clk_cnt <= clk_cnt + 16'd1;
	else
		clk_cnt <= 16'd0;
end
//SPI时钟（上升沿）计数器
always @(posedge sys_clk or posedge rst)
begin
	if(rst)
		clk_edge_cnt <= 5'd0;
	//如果在“DCLK_EDGE”状态，则计数器开始工作，每一个sys_clk都自增1（“DCLK_EDGE”状态一共需要16个sys_clk上升沿）
	else if(state == DCLK_EDGE)
		clk_edge_cnt <= clk_edge_cnt + 5'd1;
	//如果在“IDLE”状态，则计数器清零
	else if(state == IDLE)
		clk_edge_cnt <= 5'd0;
end
//往spi_flash写入数据（MOSI：串行数据输出）
always @(posedge sys_clk or posedge rst)
begin
	if(rst)
		MOSI_shift <= 8'd0;
	else if(state == IDLE && wr_req)
		MOSI_shift <= data_in;
	//处于“DCLK_EDGE”状态，循环移位
	else if(state == DCLK_EDGE)
		if(CPHA == 1'b0 && clk_edge_cnt[0] == 1'b1)
			MOSI_shift <= {MOSI_shift[6:0],MOSI_shift[7]};
		else if(CPHA == 1'b1 && (clk_edge_cnt != 5'd0 && clk_edge_cnt[0] == 1'b0))
			MOSI_shift <= {MOSI_shift[6:0],MOSI_shift[7]};
end
//从spi_flash读取数据（MISO：串行数据输入）
always @(posedge sys_clk or posedge rst)
begin
	if(rst)
		MISO_shift <= 8'd0;
	else if(state == IDLE && wr_req)
		MISO_shift <= 8'h00;
	//处于“DCLK_EDGE”状态，循环移位
	else if(state == DCLK_EDGE)
		if(CPHA == 1'b0 && clk_edge_cnt[0] == 1'b0)
			MISO_shift <= {MISO_shift[6:0],MISO};
		else if(CPHA == 1'b1 && (clk_edge_cnt[0] == 1'b1))
			MISO_shift <= {MISO_shift[6:0],MISO};
end
endmodule
