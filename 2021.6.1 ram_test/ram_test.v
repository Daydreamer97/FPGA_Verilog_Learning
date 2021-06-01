`timescale 1ns / 1ps
module ram_test
(
	input clk,
	input rst_n
);
reg[8:0]   w_addr;//写地址
reg[15:0]  w_data;//写数据
reg        wea;//写使能
reg[8:0]   r_addr;//读地址
wire[15:0] r_data;//读数据

//RAM地址读取数据测试
always @(posedge clk or negedge rst_n)
begin
//重置
	if(rst_n==1'b0) 
		r_addr <= 9'd0;
//读地址+1
	else 
		r_addr <= r_addr+1'b1;
end
///RAM写入测试
always @(posedge clk or negedge rst_n)
begin	
//重置
	if(rst_n==1'b0)
		begin
			wea <= 1'b0;//写使能拉低
			w_addr <= 9'd0;//首地址
			w_data <= 16'd0;
		end
//写操作
	else
		begin
			if(w_addr==511)//写到了最后一个地址，表示ram写入完毕，使能端拉低
				begin
					wea <= 1'b0;
				end
			else//没有写到最后一个地址，ram写使能拉高，地址（addr）和数据（data）继续+1
				begin
					wea<=1'b1;
					w_addr <= w_addr + 1'b1;
					w_data <= w_data + 1'b1;
				end
		end 
end 

//引用双口RAM IP，实例化RAM	
ram_ip ram_ip_inst 
(
	.wrclock   (clk   ),// input wrclock
	.wren      (wea   ),// input [0 : 0] wren
	.wraddress (w_addr),// input [8 : 0] wraddress
	.data      (w_data),// input [15 : 0] data
	.rdclock   (clk   ),// input rdclock
	.rdaddress (r_addr),// input [8 : 0] rdaddress
	.q         (r_data) // output [15 : 0] q
);
	
endmodule
