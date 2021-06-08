`include "spi_flash_defines.v"
module spi_flash_ctrl(
	input             sys_clk,
	input             rst,
	input             flash_read,                     //flash read request
	input             flash_write,                    //flash write request
	input             flash_bulk_erase,               //flash full erase request
	input             flash_sector_erase,             //flash sector erase request
	output            flash_read_ack,                 //flash read request response
	output            flash_write_ack,                //flash write request response
	output            flash_bulk_erase_ack,           //flash full erase request response
	output            flash_sector_erase_ack,         //flash sector erase request response
	input[23:0]       flash_read_addr,                //flash read address
	input[23:0]       flash_write_addr,               //flash write address
	input[23:0]       flash_sector_addr,              //flash sector erase address
	input[7:0]        flash_write_data_in,            //flash write data
	input[8:0]        flash_read_size,                //flash read size
	input[8:0]        flash_write_size,               //flash write size
	output            flash_write_data_req,           //flash write data request,ahead of a clock cycle
	output reg[7:0]   flash_read_data_out,            //flash read data
	output reg        flash_read_data_valid,          //flash read valid
	// to flash cmd
	output reg[7:0]   cmd,       //flash command
	output reg        cmd_valid, //flash command valid
	input             cmd_ack,   //flash command response
	output reg[23:0]  addr,      //flash command address
	output[7:0]       data_in,   //flash command write data
	output reg[8:0]   size,      //flash command data size
	input             data_req,  //data request, ahead of a clock cycle
	input[7:0]        data_out,  //flash command read data
	input             data_valid //flash command read data valid
);
//State machine code
localparam S_IDLE       = 0;
localparam S_SE         = 1; //sector erase
localparam S_BE         = 2; //bulk erase
localparam S_READ       = 3; //read
localparam S_WRITE      = 4; //write
localparam S_ACK        = 5;
localparam S_CK_STATE   = 6;
localparam S_WREN       = 7;

reg[4:0] state,next_state;
reg[7:0] state_reg;//Status register
assign data_in = flash_write_data_in;

//读应答：处在应答状态 且 收到 读flash的请求（flash_read信号来自于test模块）
assign flash_read_ack = (state == S_ACK) && flash_read == 1'b1 ? 1'b1 : 1'b0;
//写应答：处在应答状态 且 收到 写flash的请求（flash_write信号来自于test模块）
assign flash_write_ack = (state == S_ACK) && flash_write == 1'b1 ? 1'b1 : 1'b0;

//块擦除应答：处在应答状态 且 收到 块擦除请求（flash_bulk_erase信号来自于test模块）
assign flash_bulk_erase_ack = (state == S_ACK) && flash_bulk_erase == 1'b1 ? 1'b1 : 1'b0;
//页擦除应答：处在应答状态 且 收到 页擦除请求（flash_sector_erase信号来自于test模块）
assign flash_sector_erase_ack = (state == S_ACK) && flash_sector_erase == 1'b1 ? 1'b1 : 1'b0;

//写数据拉取（data_req信号来自于cmd模块，目的是要求拉取需要往flash中写的数据）
assign flash_write_data_req = data_req;

//跳转后的状态赋值
always @(posedge sys_clk or posedge rst)
begin
	if(rst)
		state <= S_IDLE;
	else
		state <= next_state;
end
//状态跳转及状态内的组合逻辑判定
always @(*)
begin
	case(state)
		//空闲状态，由if-else语句来判断，根据不同的命令，跳转至不同的状态
		S_IDLE:
			//有块擦除需求，则需要先跳转至写使能状态（首先要拉起写使能信号，才能进行后续的写操作（擦除flash、往flash写东西，都属于写操作））
			if(flash_bulk_erase == 1'b1)
				next_state <= S_WREN;
			//有页擦除需求，同上备注
			else if(flash_sector_erase == 1'b1)
				next_state <= S_WREN;
			//有读需求，则跳转至读状态
			else if(flash_read == 1'b1)
				next_state <= S_READ;
			//有写需求，同上擦除部分备注
			else if(flash_write == 1'b1)
				next_state <= S_WREN;
			else
				next_state <= S_IDLE;
		//写使能状态，发送完WREN再判断具体时间什么命令，决定下一个跳转的状态（跳转至不同的状态，发送不同的指令，由SPI通讯协议定义）
		S_WREN:
			//cmd_ack=1表示命令已经发送完毕（cmd_ack来自于cmd模块）在此表示写使能命令已发送完成 且 有块擦除需求，则跳转至块擦除状态
			if(cmd_ack == 1'b1 && flash_bulk_erase == 1'b1)
				next_state <= S_BE;
			//类同上方备注
			else if(cmd_ack == 1'b1 && flash_sector_erase == 1'b1)
				next_state <= S_SE;
			//类同上方备注
			else if(cmd_ack == 1'b1 && flash_write == 1'b1)
				next_state <= S_WRITE;
			else
				next_state <= S_WREN;
		//块擦除状态（并不只是简单的指示BE状态和跳转至其他状态，该状态还会影响到发送指令的模块是否发送BE指令）
		S_BE:
			//cmd_ack=1表示命令已经发送完毕，在此表示BE命令已发送完成，跳转至确认状态（确认BE命令确实已经发送完毕）
			if(cmd_ack == 1'b1)
				next_state <= S_CK_STATE;
			else
				next_state <= S_BE;
		//页擦除状态
		S_SE:
			//cmd_ack=1表示命令已经发送完毕，在此表示SE命令已发送完毕，跳转至确认状态（确认SE命令确实已经发送完毕）
			if(cmd_ack == 1'b1)
				next_state <= S_CK_STATE;
			else
				next_state <= S_SE;
		//读状态
		S_READ:
			//cmd_ack=1表示命令已经发送完毕，在此表示状态读完了之后直接跳转至应答状态
			if(cmd_ack == 1'b1)
				next_state <= S_ACK;
			else
				next_state <= S_READ;
		//写状态
		S_WRITE:
			//cmd_ack=1表示命令已经发送完毕。写完了跳转至确认状态，check一下状态寄存器的情况
			if(cmd_ack == 1'b1)
				next_state <= S_CK_STATE;
			else
				next_state <= S_WRITE;
		//确认状态
		S_CK_STATE:
			//cmd_ack=1表示命令已经发送完毕，check状态寄存器的最后一位是否为0，为0的话表示已不在写入状态，可以跳转至应答状态（state_reg[0]就是WIP位，显示SPI是否在写入状态）
			if(cmd_ack == 1'b1  &&  state_reg[0] == 1'b0)//status register, not busy
				next_state <= S_ACK;
			else
				next_state <= S_CK_STATE;
		//应答状态
		S_ACK:
			next_state <= S_IDLE;
		default:
			next_state <= S_IDLE;
	endcase
end
//由上一个always块确定出来的state，决定出向cmd模块发出的指令（cmd模块执行）
always @(posedge sys_clk or posedge rst)
begin
	if(rst)
		cmd <= `CMD_READ;
	else
		case(state)
			//块擦除状态，请求flash进行块擦除
			S_BE:
				cmd <= `CMD_BE;
			//页擦除状态，请求flash进行页擦除
			S_SE:
				cmd <= `CMD_SE;
			//确认状态，请求flash的读状态寄存器
			S_CK_STATE:
				cmd <= `CMD_RDSR;
			//读状态，向flash发送读指令，读取flash内存信息
			S_READ:
				cmd <= `CMD_READ;
			//写状态，向flash发送页编程指令，往flash内存写信息
			S_WRITE:
				cmd <= `CMD_PP;
			//写使能状态，向flash发送写使能指令
			S_WREN:
				cmd <= `CMD_WREN;
			default:
				cmd <= `CMD_READ;
		endcase
end
//Command length
always @(posedge sys_clk or posedge rst)
begin
	if(rst)
		size <= 9'd0;
	else
		case(state)
			S_CK_STATE:
				size <= 9'd1;
			S_READ:
				size <= flash_read_size;
			S_WRITE:
				size <= flash_write_size;
			default:
				size <= 9'd0;
		endcase
end
//address selection
always @(posedge sys_clk or posedge rst)
begin
	if(rst)
		addr <= 1'b0;
	else if(state == S_IDLE && flash_sector_erase == 1'b1)
		addr <= flash_sector_addr;
	else if(state == S_IDLE && flash_read == 1'b1)
		addr <= flash_read_addr;
	else if(state == S_IDLE && flash_write == 1'b1)
		addr <= flash_write_addr;
end
//status register
always @(posedge sys_clk or posedge rst)
begin
	if(rst)
		state_reg <= 8'd0;
	else if(state == S_CK_STATE && data_valid == 1'b1)
		state_reg <= data_out;
	else
		state_reg <= state_reg;
end

always @(posedge sys_clk or posedge rst)
begin
	if(rst)
		flash_read_data_out <= 8'd0;
	else if(state == S_READ && data_valid == 1'b1)
		flash_read_data_out <= data_out;
	else
		flash_read_data_out <= data_out;
end

always @(posedge sys_clk or posedge rst)
begin
	if(rst)
		flash_read_data_valid <= 1'd0;
	else if(state == S_READ && data_valid == 1'b1)
		flash_read_data_valid <= 1'b1;
	else
		flash_read_data_valid <= 1'b0;
end

always @(posedge sys_clk or posedge rst)
begin
	if(rst)
		cmd_valid <= 1'b0;
	else
		case(state)
			S_READ,S_WRITE,S_BE,S_WREN,S_SE:
				if(cmd_ack == 1'b1)
					cmd_valid <= 1'b0;
				else
					cmd_valid <= 1'b1;
			S_CK_STATE:
				if(cmd_ack == 1'b1)
					cmd_valid <= 1'b0;
				else
					cmd_valid <= 1'b1;
			default:
				cmd_valid <= 1'b0;
		endcase
end

endmodule