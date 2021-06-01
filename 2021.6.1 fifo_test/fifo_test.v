`timescale 1ns / 1ps
module fifo_test
(
	input clk,
	input rst_n
);
localparam	W_IDLE = 1;
localparam	W_FIFO = 2; 
localparam	R_IDLE = 1;
localparam	R_FIFO = 2; 

reg[2:0]   write_state;
reg[2:0]   next_write_state;
reg[2:0]   read_state;
reg[2:0]   next_read_state;

reg[15:0]  w_data;//FIFO写数据
wire       wr_en;	//FIFO写使能
wire       rd_en;	//FIFO读使能
wire[15:0] r_data;//FIFO读数据
wire       full; 	//FIFO满信号
wire       empty; //FIFO空信号
wire[8:0]  rd_data_count;//通过读端口，读取目前FIFO内部存储数据量
wire[8:0]  wr_data_count;//通过写端口，读取目前FIFO内部存储数据量

///FIFO写入部分
always @(posedge clk or negedge rst_n)
begin
//重置
	if(rst_n == 1'b0)
		write_state <= W_IDLE;
//进入下一状态
	else
		write_state <= next_write_state;
end

always @(*)
begin
	case(write_state)
		//初始状态
		W_IDLE:
			//FIFO已经读完了，下一状态转向写FIFO
			if(empty == 1'b1)
				next_write_state <= W_FIFO;
			//还没读完FIFO,状态不变
			else
				next_write_state <= W_IDLE;
		//写状态
		W_FIFO:
			//FIFO写满了，状态跳转至IDLE
			if(full == 1'b1)
				next_write_state <= W_IDLE;
			//FIFO尚未写满，状态不变
			else
				next_write_state <= W_FIFO;
		default:
			next_write_state <= W_IDLE;
	endcase
end
//写使能，处于W_FIFO状态时，写使能拉高
assign wr_en = (next_write_state == W_FIFO) ? 1'b1 : 1'b0; 
//数据值变化
always@(posedge clk or negedge rst_n)
begin
//重置
	if(rst_n == 1'b0)
		w_data <= 16'd0;
//改变数据值
	else
	   if (wr_en == 1'b1)
		    w_data <= w_data + 1'b1;
		else
          w_data <= 16'd0;		
end
//FIFO读部分
always @(posedge clk or negedge rst_n)
begin
//重置
	if(rst_n == 1'b0)
		read_state <= R_IDLE;
//进入下一状态
	else
		read_state <= next_read_state;
end
//读端口状态机
always @(*)
begin
	case(read_state)
		//初始状态
		R_IDLE:
			//FIFO已经写满了,下一状态转向读FIFO
			if(full == 1'b1)
				next_read_state <= R_FIFO;
			//FIFO尚未写满,状态不变
			else
				next_read_state <= R_IDLE;
		//读状态
		R_FIFO:
			//FIFO已经读空了，下一状态转向IDLE
			if(empty == 1'b1)
				next_read_state <= R_IDLE;
			//FIFO尚未读空，下一状态保持读取
			else
				next_read_state <= R_FIFO;
		default:
			next_read_state <= R_IDLE;
	endcase
end

//读使能，若下一阶段是R_FIFO，则读使能拉高
assign rd_en = (next_read_state == R_FIFO) ? 1'b1 : 1'b0; 

//引用FIFO IP，实例化FIFO
fifo_ip fifo_ip_inst
(
	.aclr    (~rst_n       ),// input aclr
	.wrclk   (clk          ),// input wrclk
	.rdclk   (clk          ),// input rdclk
	.data    (w_data       ),// input [15 : 0] data
	.wrreq   (wr_en        ),// input wrreq
	.rdreq   (rd_en        ),// input rdreq
	.q       (r_data       ),// output [15 : 0] q
	.wrfull  (full         ),// output full
	.rdempty (empty        ),// output empty
	.rdusedw (rd_data_count),
	.wrusedw (wr_data_count)
);	
endmodule
