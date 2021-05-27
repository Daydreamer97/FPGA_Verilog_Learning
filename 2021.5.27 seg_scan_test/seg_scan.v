module seg_scan
(
	input           clk,
	input           rst_n,
	output reg[5:0] seg_sel,      //数码管选择信号（通过指定的pin，选择到具体的数码管）
	output reg[7:0] seg_data,     //输出指定数码管需要显示的数字
	input[7:0]      seg_data_0,
	input[7:0]      seg_data_1,
	input[7:0]      seg_data_2,
	input[7:0]      seg_data_3,
	input[7:0]      seg_data_4,
	input[7:0]      seg_data_5
);
parameter SCAN_FREQ = 200;//扫描频率
parameter CLK_FREQ = 50000000; //时钟频率

parameter SCAN_COUNT = CLK_FREQ /(SCAN_FREQ * 6) - 1;//计算出视觉暂留时间

reg[31:0] scan_timer;//点亮时间计时
reg[3:0] scan_sel;//选择点亮那一个数码管
//1.选择点亮的数码管；2.控制某一数码管点亮的时间长度
always@(posedge clk or negedge rst_n)
begin
//重置
	if(rst_n == 1'b0)
	begin
		scan_timer <= 32'd0;
		scan_sel <= 4'd0;
	end
//某一数码管的点亮时间>视觉暂留时间，则跳转点亮下一个数码管
	else if(scan_timer >= SCAN_COUNT)
	begin
		scan_timer <= 32'd0;
		if(scan_sel == 4'd5)
			scan_sel <= 4'd0;
		else
			scan_sel <= scan_sel + 4'd1;
	end
//点亮时间计时计时
	else
		begin
			scan_timer <= scan_timer + 32'd1;
		end
end
//
always@(posedge clk or negedge rst_n)
begin
//重置，全部熄灭
	if(rst_n == 1'b0)
	begin
		seg_sel <= 6'b111111;
		seg_data <= 8'hff;
	end
//根据所选数码管的data来点亮该数码管，低有效选择点亮的数码管
	else
	begin
		case(scan_sel)
			4'd0:
			begin
				seg_sel <= 6'b11_1110;
				seg_data <= seg_data_0;
			end
			4'd1:
			begin
				seg_sel <= 6'b11_1101;
				seg_data <= seg_data_1;
			end
			4'd2:
			begin
				seg_sel <= 6'b11_1011;
				seg_data <= seg_data_2;
			end
			4'd3:
			begin
				seg_sel <= 6'b11_0111;
				seg_data <= seg_data_3;
			end
			4'd4:
			begin
				seg_sel <= 6'b10_1111;
				seg_data <= seg_data_4;
			end
			4'd5:
			begin
				seg_sel <= 6'b01_1111;
				seg_data <= seg_data_5;
			end
			default:
			begin
				seg_sel <= 6'b11_1111;
				seg_data <= 8'hff;
			end
		endcase
	end
end

endmodule
