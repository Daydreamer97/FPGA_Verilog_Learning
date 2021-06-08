//处理来自于ctrl的命令，并依spi_flash规范向master发起指令
`include "spi_flash_defines.v"
module spi_flash_cmd(
	input            sys_clk,
	input            rst,
	input[7:0]       cmd,        //flash command
	input            cmd_valid,  //flash command valid
	output           cmd_ack,    //flash command response
	input[23:0]      addr,       //flash command address
	input[7:0]       data_in,    //flash command write data
	input[8:0]       size,       //flash command data size
	output reg       data_req,   //data request, ahead of a clock cycle
	output reg[7:0]  data_out,   //flash command read data
	output reg       data_valid, //flash command read data valid
	//to spi master
	output reg       CS_reg,
	output reg       wr_req,
	input            wr_ack,
	output reg[7:0]  send_data,
	input[7:0]       data_recv
);
//State machine code
parameter S_IDLE         = 0;
parameter S_CS_LOW       = 1;
parameter S_CS_HIGH      = 2;
parameter S_KEEP_CS_LOW  = 3;
parameter S_READ_BYTES   = 4;
parameter S_WRITE_BYTES  = 5;
parameter S_CMD_LATCH    = 6;
parameter S_WR_CMD_CODE  = 7;
parameter S_CMD_ACK      = 8;

reg[4:0] state,next_state;
reg[8:0] byte_cnt; //byte counter
reg      wr_ack_d0;//delay wr_ack
reg[7:0] cmd_code;
reg[8:0] byte_size;//Command length correction

assign cmd_ack = (state == S_CMD_ACK) ? 1'b1 : 1'b0;//命令应答指示，=1表示命令已经发送完毕

//对spi_master接口的写应答反馈进行1个sys_clk周期的延迟
always @(posedge sys_clk or posedge rst)
begin
	if(rst == 1'b1)
		wr_ack_d0 <= 1'b0;
	else
		wr_ack_d0 <= wr_ack;
end
//对spi_master接口的写请求
always @(posedge sys_clk or posedge rst)
begin
	if(rst == 1'b1)
		wr_req <= 1'b0;
	//满足以下条件：读状态 || 发送1个字节指令状态 || 写状态 时，则对spi_master接口发起写请求
	else
		wr_req <= (state == S_READ_BYTES || state == S_WR_CMD_CODE || state == S_WRITE_BYTES ) ? 1'b1 : 1'b0;
end
//请求数据
always @(posedge sys_clk or posedge rst)
begin
	if(rst == 1'b1)
		data_req <= 1'b0;
	//满足以下条件：处于写操作 && 计数值>= 9'd2 && 计数值!= byte_size - 9'd1 && 写应答==1，则请求数据
	else
		data_req <= ( (state == S_WRITE_BYTES ) && (byte_cnt >= 9'd2) && (byte_cnt != byte_size - 9'd1) && wr_ack_d0 == 1'b1 ) ? 1'b1 : 1'b0;
end
//状态跳转
always @(posedge sys_clk or posedge rst)
begin
	if(rst == 1'b1)
		state <= S_IDLE;
	else
		state <= next_state;
end
//
always @(posedge sys_clk or posedge rst)
begin
	if(rst == 1'b1)
		CS_reg <= 1'b0;
	else if(state == S_CS_LOW)
		CS_reg <= 1'b0;
	else if(state == S_CS_HIGH || state == S_IDLE)
		CS_reg <= 1'b1;
end
//
always @(posedge sys_clk or posedge rst)
begin
	if(rst == 1'b1)
		data_valid <= 1'b0;
	else if(state == S_READ_BYTES && byte_cnt >= 9'd3 && wr_ack == 1'b1 && cmd == `CMD_READ )
		data_valid <= 1'b1;
	else if(state == S_READ_BYTES && byte_cnt >= 9'd0 && wr_ack == 1'b1 && (cmd == `CMD_RDID  || cmd == `CMD_RDSR) )
		data_valid <= 1'b1;
	else
		data_valid <= 1'b0;
end
//
always @(posedge sys_clk or posedge rst)
begin
	if(rst == 1'b1)
		data_out <= 8'd0;
	else if(state == S_READ_BYTES && byte_cnt >= 9'd3 && wr_ack == 1'b1 && cmd == `CMD_READ)
		data_out <= data_recv;
	else if(state == S_READ_BYTES && byte_cnt >= 9'd0 && wr_ack == 1'b1 && (cmd == `CMD_RDID  || cmd == `CMD_RDSR) )
		data_out <= data_recv;
	else
		data_out <= data_out;
end
//
always @(posedge sys_clk or posedge rst)
begin
	if(rst == 1'b1)
		send_data <= 8'd0;
	else if(state == S_WR_CMD_CODE)
		send_data <= cmd_code;
	else if(state == S_READ_BYTES)
		if(byte_cnt == 8'd0)
			send_data <= addr[23:16];
		else if(byte_cnt == 8'd1)
			send_data <= addr[15:8];
		else if(byte_cnt == 8'd2)
			send_data <= addr[7:0];
		else
			send_data <= 8'h0;
	else if(state == S_WRITE_BYTES)
		if(byte_cnt == 8'd0)
			send_data <= addr[23:16];
		else if(byte_cnt == 8'd1)
			send_data <= addr[15:8];
		else if(byte_cnt == 8'd2)
			send_data <= addr[7:0];
		else
			send_data <= data_in;
	else
		send_data <= 8'h0;
end
//
always @(posedge sys_clk or posedge rst)
begin
	if(rst == 1'b1)
		byte_cnt <= 9'd0;
	//如果处于读状态或是写状态
	else if(state == S_READ_BYTES || state == S_WRITE_BYTES)
		begin
			//如果处于写应答状态，则开始计数
			if(wr_ack == 1'b1)
				byte_cnt <= byte_cnt + 9'd1;
			else
				byte_cnt <= byte_cnt;
		end
	else
		byte_cnt <= 9'd0;
end
//定义某一命令的字节长度，定义依据来源于SPI通讯协议规范。size来源于输入的数据长度
always @(posedge sys_clk or posedge rst)
begin
	if(rst == 1'b1)
		byte_size <= 9'd0;
	//如果处于锁存状态，则依cmd寄存器存储的内容（cmd信号来自于ctrl模块）来给“byte_size”寄存器赋值（将用该值来比对计数器的计数结果，用以确认该cmd已经发送完成）
	else if(state == S_CMD_LATCH)
		case(cmd)
			`CMD_RDID       :  byte_size <= size;
			`CMD_RDSR       :  byte_size <= size;
			`CMD_WRSR       :  byte_size <= 9'd1;
			`CMD_READ       :  byte_size <= 9'd3 + size;
			`CMD_FAST_READ  :  byte_size <= 9'd3 + size;
			`CMD_PP         :  byte_size <= 9'd3 + size;
			`CMD_SE         :  byte_size <= 9'd3 + size;
			default         :  byte_size <= 9'd0;
		endcase
	else
		byte_size <= byte_size;
end
//
always @(posedge sys_clk or posedge rst)
begin
	if(rst == 1'b1)
		cmd_code <= 8'd0;
	else if(state == S_CMD_LATCH)
		cmd_code <= cmd;
	else
		cmd_code <= cmd_code;
end
//实现命令数据流的状态机
always @(*)
begin
	case(state)
		//空闲状态
		S_IDLE:
			//收到有效的命令请求后（cmd_valid == 1'b1），进入命令锁存状态
			if(cmd_valid == 1'b1)
				next_state <= S_CMD_LATCH;
			else
				next_state <= S_IDLE;
		//命令锁存状态，记录请求的命令，而后跳转至片选信号低状态
		S_CMD_LATCH:
			next_state <= S_CS_LOW;
		//片选信号低状态，拉低片选信号
		S_CS_LOW:
			next_state <= S_WR_CMD_CODE;
		//发送1个字节指令状态
		S_WR_CMD_CODE:
			//以下三个只发送1个指令，后边没跟数据，归为一类，发送完成之后keep cs low即可
			if(wr_ack  == 1'b1 && ((cmd == `CMD_WREN) || (cmd == `CMD_WRDI)  || (cmd == `CMD_BE)))
				next_state <= S_KEEP_CS_LOW;
			//以下命令归属“读”一类，满足条件即跳转至“S_READ_BYTES”状态进行后续信息的发送
			else if(wr_ack  == 1'b1 && ((cmd == `CMD_RDSR) || (cmd == `CMD_RDID) || (cmd == `CMD_READ)  || (cmd == `CMD_FAST_READ)) )
				next_state <= S_READ_BYTES;
			//以下命令归属“写”一类，满足条件即跳转至“S_WRITE_BYTES”状态进行后续信息的发送
			else if(wr_ack  == 1'b1 && ((cmd == `CMD_WRSR) || (cmd == `CMD_PP) || (cmd == `CMD_SE)))
				next_state <= S_WRITE_BYTES;
			//跳转至写1个字节命令状态后，如果有条件不满足，则维持该状态，在该状态等待
			else
				next_state <= S_WR_CMD_CODE;
		//读状态
		S_READ_BYTES:
			//byte_cnt计数，计的具体值由上面的always模块定义，定义依据是具体写指令的发送信息规范。计数完成之后跳转至“S_KEEP_CS_LOW”状态
			if(wr_ack  == 1'b1 && byte_cnt == byte_size - 9'd1)
				next_state <= S_KEEP_CS_LOW;
			//如果不满足跳转条件，则维持读状态，继续进行读操作及byte_cnt计数工作
			else
				next_state <= S_READ_BYTES;
		//写状态
		S_WRITE_BYTES:
			//byte_cnt计数，计的具体值由上面的always模块定义，定义依据是具体写指令的发送信息规范。计数完成之后跳转至“S_KEEP_CS_LOW”状态
			if(wr_ack  == 1'b1 && byte_cnt == byte_size - 9'd1)
				next_state <= S_KEEP_CS_LOW;
			//如果不满足跳转条件，则维持写状态，继续进行写操作及byte_cnt计数工作
			else
				next_state <= S_WRITE_BYTES;
		//片选信号保持低状态
		S_KEEP_CS_LOW:
			next_state <= S_CS_HIGH;
		//片选信号高状态
		S_CS_HIGH:
			next_state <= S_CMD_ACK;
		//命令应答状态（该状态关联前方定义的cmd_ack信号，cmd_ack = (state == S_CMD_ACK) ? 1'b1 : 1'b0;）
		S_CMD_ACK:
			next_state <= S_IDLE;
		default:
			next_state <= S_IDLE;
	endcase
end
endmodule
