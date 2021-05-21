module CP_1kHz_1Hz(nRST,CLK_50,_1Hz,_10Hz,_100Hz,_1kHz);
	input CLK_50,nRST;
	output _1Hz,_10Hz,_100Hz,_1kHz;
	Divider50MHz U0(.CLK_50M(CLK_50),.nCLR(nRST),.CLK_1HzOut(_1KHz));
	defparam U2.N=15,
				U2.CLK_Freq=50000000,
				U2.OUT_Freq=1000;
	Divider50MHz U1(.CLK_50M(CLK_50),.nCLR(nRST),.CLK_1HzOut(_100Hz));
	defparam U3.N=18,
				U3.CLK_Freq=50000000,
				U3.OUT_Freq=100;
	Divider50MHz U2(.CLK_50M(CLK_50),.nCLR(nRST),.CLK_1HzOut(_10Hz));
	defparam U4.N=22,
				U4.CLK_Freq=50000000,
				U4.OUT_Freq=10;
	Divider50MHz U3(.CLK_50M(CLK_50),.nCLR(nRST),.CLK_1HzOut(_1Hz));
	defparam U5.N=25,
				U5.CLK_Freq=50000000,
				U5.OUT_Freq=1;
endmodule

module Divider50MHz(CLK_50M,nCLR,CLK_1HzOut);
	parameter N=25;
	parameter CLK_Freq=50000000;
	parameter OUT_Freq=1;
	input nCLR,CLK_50M;
	output reg CLK_1HzOut;
	reg [N-1:0] Count_DIV;
always @(posedge CLK_50M or negedge nCLR)
	begin
		if(!nCLR)
			begin
				CLK_1HzOut<=0;
				Count_DIV<=0;
			end
		else
			begin
				if(Count_DIV<(CLK_Freq/(2*OUT_Freq)-1))
					Count_DIV<=Count_DIV+1'b1;
				else
					begin
						Count_DIV<=0;
						CLK_1HzOut<=~CLK_1HzOut;
					end
			end
	end
endmodule
