module counter10(Q,nCR,En,CP);
	input CP,nCR,En;
	output [3:0] Q;
	reg [3:0] Q;
always @(posedge CP or negedge nCR)
	begin
		if(~nCR)
			Q<=4'b0000;
		else if(~En)
			Q<=Q;
		else if(Q==4'b1001)
			Q<=4'b0000;
		else
			Q<=Q+1'b1;
	end
endmodule

module counter6(Q,nCR,En,CP);
	input CP,nCR,En;
	output [3:0] Q;
	reg [3:0] Q;
always @(posedge CP or negedge nCR)
	begin
		if(~nCR)
			Q<=4'b0000;
		else if(~En)
			Q<=Q;
		else if(Q==4'b0101)
			Q<=4'b0000;
		else
			Q<=Q+1'b1;
	end
endmodule

module counter60(Cnt,nCR,En,CP);
	input CP,nCR,En;
	output [7:0] Cnt;
	wire [7:0] Cnt;
	wire ENP;
	counter10 UC0(Cnt[3:0],nCR,En,CP);
	assign ENP=(Cnt[3:0]==4'h9);
	counter6 UC1(Cnt[7:4],nCR,ENP,CP);
endmodule
