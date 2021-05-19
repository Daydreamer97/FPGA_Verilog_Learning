`timescale 1ns / 1ps
module led_test
(
	input clk,
	input rst_n,
	output reg[3:0] led
);

reg [31:0] timer;
always@(posedge clk or negedge rst_n)
begin
	if (rst_n == 1'b0)
		timer <= 32'd0;
	else if (timer == 32'd199_999_999)
		timer <= 32'd0;
	else
		timer <= timer + 32'd1;
end
always@(posedge clk or negedge rst_n)
begin
	if (rst_n == 1'b0)
		led <= 4'b0000;
	else if (timer == 32'd49_999_999)
		led <= 4'b0001;
	else if (timer == 32'd99_999_999)
		led <= 4'b0010;
	else if (timer == 32'd149_999_999)
		led <= 4'b0100;
	else if (timer == 32'd199_999_999)
		led <= 4'b1000;
end
endmodule
