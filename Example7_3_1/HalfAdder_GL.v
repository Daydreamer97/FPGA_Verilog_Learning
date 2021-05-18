/* Gate-level description of a half adder */
module HalfAdder_GL(A,B,Sum,Carry);
	input A,B;
	output Sum,Carry;
	wire A,B,Sum,Carry;
	xor X1(Sum,A,B);
	and A1(Carry,A,B);
endmodule
