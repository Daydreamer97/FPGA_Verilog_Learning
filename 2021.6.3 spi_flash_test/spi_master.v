//master模块实现1个字节spi数据的读写（1个字节有8位数据）
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
	input[7:0]  data_in,//data_in：输入给spi_flash的数据，对接cmd模块的“send_data”
	output[7:0] data_out//data_out：从spi_flash中输出的数据
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
reg[15:0]  clk_cnt;
reg[4:0]   clk_edge_cnt;

assign MOSI = MOSI_shift[7];//MOSI：spi串行数据输出。定义数据依MOSI_shift[7]内容，一位一位地输出
assign DCLK = DCLK_reg;//输出一个模拟的spi时钟
assign data_out = MISO_shift;//MISO：spi串行数据输入。data_out：从spi_flash中输出的数据
assign wr_ack = (state == ACK);//写应答（处于ACK状态，则表示写应答信号有效，意味着完成了1个字节的写操作）
assign nCS = nCS_ctrl;//低有效片选信号

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
			//如果有写请求（来自于spi_flash_cmd的写请求），则跳转至“DCLK_IDLE”状态
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
	//由于本案设定clk_div=0，所以每2个sys_clk上升沿才会有1个“DCLK_EDGE”状态，这就导致SPI时钟跳转1下需要2个sys_clk上升沿。这就导致在clk_div=0的前提下，SPI时钟频率为sys_clk的四分之一
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
//SPI时钟（边沿）计数器
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
/////以下为：往spi_flash进行的操作/////

//往spi_flash写入数据（MOSI：串行数据输出）
always @(posedge sys_clk or posedge rst)
begin
	if(rst)
		MOSI_shift <= 8'd0;
	//如果处于空闲状态且有写请求，那么将中间寄存器data_in中的数据存入MOSI_shift寄存器中，以便后续移位并一位一位地写入spi_flash中
	else if(state == IDLE && wr_req)
		MOSI_shift <= data_in;
	//处于“DCLK_EDGE”状态，循环移位（每个SPI边沿）
	else if(state == DCLK_EDGE)
		begin
			if(CPHA == 1'b0 && clk_edge_cnt[0] == 1'b1)
				MOSI_shift <= {MOSI_shift[6:0],MOSI_shift[7]};
			//top模块已设定CPHA=1，则采用以下判定条件
			//当SPI时钟边沿计数器不等于0（clk_edge_cnt != 5'd0）且计数器的末位为0（clk_edge_cnt[0] == 1'b0）时，MOSI数据整体左移（MOSI = MOSI_shift[7]，每个SPI时钟边沿到来的时候输出最高位的数据）
			//SPI时钟边沿计数器末尾为0（clk_edge_cnt[0] == 1'b0）时发送数据，表示数据在第一个边沿发送（符合CPHA=1的规定）
			else if(CPHA == 1'b1 && (clk_edge_cnt != 5'd0 && clk_edge_cnt[0] == 1'b0))
				MOSI_shift <= {MOSI_shift[6:0],MOSI_shift[7]};
		end
end
//从spi_flash读取数据（MISO：串行数据输入）
always @(posedge sys_clk or posedge rst)
begin
	//重置，清空MISO_shift寄存器
	if(rst)
		MISO_shift <= 8'd0;
	//如果处于空闲状态且有写请求，那么也清空MISO_shift寄存器
	else if(state == IDLE && wr_req)
		MISO_shift <= 8'h00;
	//处于“DCLK_EDGE”状态，循环移位
	else if(state == DCLK_EDGE)
		begin
			if(CPHA == 1'b0 && clk_edge_cnt[0] == 1'b0)
				MISO_shift <= {MISO_shift[6:0],MISO};
			//top模块已设定CPHA=1，则采用以下判定条件
			//当SPI时钟边沿计数器的末位为1（clk_edge_cnt[0] == 1'b1）时，将MOSI数据整体左移，读取到的MISO数据放在MISO_shift寄存器的最低位
			//SPI时钟边沿计数器末尾为1（clk_edge_cnt[0] == 1'b1）时读取接收到的数据，表示数据在第二个边沿采样接收（符合CPHA=1的规定）
			else if(CPHA == 1'b1 && (clk_edge_cnt[0] == 1'b1))
				MISO_shift <= {MISO_shift[6:0],MISO};
		end
end
endmodule
