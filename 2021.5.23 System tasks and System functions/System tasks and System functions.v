`timescale 1ns/1ns
module System_tasks_and_System_functions;
	reg clk;
  reg rst_n;
  wire[3:0] led;
  reg a,b,c,d,e,f,g;

//对比$monitor、$display和$write
initial
	begin
		$display("display01:hello world") ;
		$display("display02:hello world") ;
		$write("write01:hello world") ;
		$write("write02:hello world") ;
		$monitor("monitor01:clk=%b",clk) ;
		clk = 1'b0;
		rst_n = 1'b0;
		#100 rst_n = 1'b1;
	end

//对比$strobe与$display
always@(posedge clk)
	begin
		$strobe("strobe01:a=%d,b=%d", a,b) ;
		a = $random%100 ;
		$display("display03:a=%d,b=%d", a,b) ; 
		b = $random%100 ; 
	end
always@(posedge clk)
	begin
		$strobe("strobe02:c=%d,d=%d", c,d) ;
		c = $random%100 ;
		$display("display04:c=%d,d=%d", c,d) ; 
		d = $random%100 ; 
	end

//对比$random、$random%100、{$rando}%100
always@(posedge clk)
	begin
		e = $random ;
		f = $random%100 ;
		g = {$random}%100 ;
		$display("display05:e=%d,f=%d,g=%d",e,f,g) ; 
	end

//产生50MhZ的时钟
always #10 clk = ~clk;
	led_test dut( .clk (clk),.rst_n (rst_n),.led (led));
endmodule
