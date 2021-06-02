`timescale 1ns / 1ps
module rom_test
(
	input clk,
	input rst_n
);

reg[4:0] rom_addr;
wire[7:0] rom_data;

//产生ROM地址读取数据测试
always @(posedge clk or negedge rst_n)
begin
	//重置
	if(rst_n==1'b0)
		rom_addr <= 10'd0;
	//地址+1
	else 
		rom_addr <= rom_addr+1'b1;
end
//引用ROM IP，实例化ROM	
rom_ip  	rom_ip_inst
(
	.clock  (clk     ), // input clock
	.address(rom_addr), // input [4 : 0] address
	.q      (rom_data)  // output [7 : 0] q
);
endmodule
