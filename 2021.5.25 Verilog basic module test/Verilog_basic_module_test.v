module Verilog_basic_module_test
(
	input cin,
	input clk,
	output reg a,b,c,aa,bb,cc,
	output wire BByuCC,BBhuoCC,BBfei,BBfyihuoCC,q,
	output wire sum0,count0,sum1,count1
);

//测试“=”阻塞赋值和“<=”非阻塞赋值
always @(posedge clk) 
	begin
		a = cin;
		b = a;
		c = b;
		
		aa <= cin;
		bb <= aa;
		cc <= bb;
	end

//测试与、或、非、异或门及比较器
	assign BByuCC	= bb&cc;
	assign BBhuoCC = bb|cc;
	assign BBfei = ~bb;
	assign BBfyihuoCC = bb^cc;
	
	assign q=bb>cc;

//测试半加器(sum0、count0）和全加器（sum1、count1）
	assign sum0 = bb^cc;
	assign count0 = bb&cc;
	
	assign {count1,sum1} = bb+cc+cin;


endmodule
