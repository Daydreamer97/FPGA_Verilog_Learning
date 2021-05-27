//顶层模块，1秒计时器+调用底层模块来实现“数码管显示数字每秒加一的功能”
module seg_test
(
	input      clk,
	input      rst_n,
	output[5:0]seg_sel,
	output[7:0]seg_data
);					 
reg[31:0] timer_cnt;//存储内部时间计数器
reg en_1hz;
//1秒计时，用以改变输出信息c
always@(posedge clk or negedge rst_n)
begin
//reset
	 if(rst_n == 1'b0)
    beginc
        en_1hz <= 1'b0;
        timer_cnt <= 32'd0;
    end
//通过clk+计数器计时到1秒，输出1个高电平脉冲信号（宽度为T/2）
    else if(timer_cnt >= 32'd49_999_999)
    begin
        en_1hz <= 1'b1;
        timer_cnt <= 32'd0;
    end
//计数
    else
    begin
        en_1hz <= 1'b0;
        timer_cnt <= timer_cnt + 32'd1; 
    end
end
//搞6个计数器，用以对应6个数码管的模10计数
//调用模10计数器，命名为m0
wire[3:0] count0;
wire t0;
count_m10 count10_m0(
    .clk    (clk),
    .rst_n  (rst_n),
    .en     (en_1hz),//每秒计1下
    .clr    (1'b0),
    .data   (count0),
    .t      (t0)
 );
 //调用模10计数器，命名为m1
wire[3:0] count1;
wire t1;
count_m10 count10_m1(
     .clk    (clk),
     .rst_n  (rst_n),
     .en     (t0),//m0有进位，计1下
     .clr    (1'b0),
     .data   (count1),
     .t      (t1)
 );
//调用模10计数器，命名为m2
wire[3:0] count2;
wire t2;
count_m10 count10_m2(
    .clk   (clk),
    .rst_n (rst_n),
    .en    (t1),//m1有进位，计1下
    .clr   (1'b0),
    .data  (count2),
    .t     (t2)
);
//调用模10计数器，命名为m3
wire[3:0] count3;
wire t3;
count_m10 count10_m3(
    .clk   (clk),
    .rst_n (rst_n),
    .en    (t2),//m2有进位，计1下
    .clr   (1'b0),
    .data  (count3),
    .t     (t3)
);
//调用模10计数器，命名为m4
wire[3:0] count4;
wire t4;
count_m10 count10_m4(
    .clk   (clk),
    .rst_n (rst_n),
    .en    (t3),//m3有进位，计1下
    .clr   (1'b0),
    .data  (count4),
    .t     (t4)
);
//调用模10计数器，命名为m5（最高位）
wire[3:0] count5;
wire t5;
count_m10 count10_m5(
    .clk   (clk),
    .rst_n (rst_n),
    .en    (t4),//m4有进位，计1下
    .clr   (1'b0),
    .data  (count5),
    .t     (t5)
);
//搞6个7段译码器，对应6个数码管的显像
//调用7段译码器，命名为m0（最左边的数码管，显示的是最高位，所以调用的counter是m5）
wire[6:0] seg_data_0;
seg_decoder seg_decoder_m0(
    .bin_data  (count5),
    .seg_data  (seg_data_0)
);
//调用7段译码器，命名为m1
wire[6:0] seg_data_1;
seg_decoder seg_decoder_m1(
    .bin_data  (count4),
    .seg_data  (seg_data_1)
);
//调用7段译码器，命名为m2
wire[6:0] seg_data_2;
seg_decoder seg_decoder_m2(
    .bin_data  (count3),
    .seg_data  (seg_data_2)
);
//调用7段译码器，命名为m3
wire[6:0] seg_data_3;
seg_decoder seg_decoder_m3(
    .bin_data  (count2),
    .seg_data  (seg_data_3)
);
//调用7段译码器，命名为m4
wire[6:0] seg_data_4;
seg_decoder seg_decoder_m4(
    .bin_data  (count1),
    .seg_data  (seg_data_4)
);
//调用7段译码器，命名为m5（最右边的数码管，显示的是最低位，所以调用的counter是m0）
wire[6:0] seg_data_5;
seg_decoder seg_decoder_m5(
    .bin_data  (count0),
    .seg_data  (seg_data_5)
);
//调用扫描模块，命名为m0
seg_scan seg_scan_m0(
    .clk        (clk),
    .rst_n      (rst_n),
    .seg_sel    (seg_sel),
    .seg_data   (seg_data),
    .seg_data_0 ({1'b1,seg_data_0}),//最高位数码管
    .seg_data_1 ({1'b1,seg_data_1}), 
    .seg_data_2 ({1'b1,seg_data_2}),
    .seg_data_3 ({1'b1,seg_data_3}),
    .seg_data_4 ({1'b1,seg_data_4}),
    .seg_data_5 ({1'b1,seg_data_5})//最低位数码管
);
endmodule 