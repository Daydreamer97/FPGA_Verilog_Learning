`timescale 1ns / 1ps
module led_test
(
	input           clk,
	input           rst_n,
	output reg[3:0] led
);


//define the time counter
reg [31:0]      timer;

// cycle counter
always@(posedge clk or negedge rst_n)
begin
	if (rst_n == 1'b0)
		timer <= 32'd0;
	else if (timer == 32'd199)
		timer <= 32'd0;
	else
		timer <= timer + 32'd1;
end

// LED control
always@(posedge clk or negedge rst_n)
begin
	if (rst_n == 1'b0)
		led <= 4'b0000;
	else if (timer == 32'd49)
		led <= 4'b0001;
	else if (timer == 32'd99)
		led <= 4'b0010;
	else if (timer == 32'd149)
		led <= 4'b0100;
	else if (timer == 32'd199)
		led <= 4'b1000;
end
endmodule
