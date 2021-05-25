`timescale 1 ns/1 ns
module Verilog_basic_module_test_tb();
	reg cin ;
	reg clk ;
	wire a,b,c,aa,bb,cc;
	wire BByuCC,BBhuoCC,BBfei,BBfyihuoCC,q;
	wire sum0,count0,sum1,count1;

//产生cin、clk初始值，定义cin取值随机跳变
initial
	begin
		cin = 0 ;
		clk = 0 ;
		forever
			begin 
				#({$random}%100)
				cin = ~cin ;
			end
	end

//产生50MHz的时钟，引用被测试模块
always #10 clk = ~clk ;
Verilog_basic_module_test U0
(
	.cin(cin),.clk(clk),
	.a(a),.b(b),.c(c),.aa(aa),.bb(bb),.cc(cc),
	.BByuCC(BByuCC),.BBhuoCC(BBhuoCC),.BBfei(BBfei),.BBfyihuoCC(BBfyihuoCC),.q(q),
	.sum0(sum0),.count0(count0),.sum1(sum1),.count1(count1)
) ;

endmodule
