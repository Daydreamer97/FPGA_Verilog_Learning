`timescale 1 ns/1 ns
module counter24_and_counter60_tb();
	reg clk,nCR,EN;
	wire [3:0] CntH,CntL;
	wire [7:0] Cnt;

initial 
begin 
  clk = 1'b0; 
  nCR = 1'b0; 
  #100 nCR = 1'b1; 
  EN = 1'b0; 
  #100 EN = 1'b1;   
end 

//产生50MHz的时钟
always #10 clk = ~clk ;

//引用两个被测试模块
counter24 T0
(
	.CntH(CntH),.CntL(CntL),.nCR(nCR),.EN(EN),.CP(clk)
);
counter60 T1
(
	.Cnt(Cnt),.nCR(nCR),.En(EN),.CP(clk)
);
endmodule 