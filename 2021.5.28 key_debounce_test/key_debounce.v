//顶层模块，调用消抖模块及数码管点亮模块（视觉暂留的扫描式点亮）
module key_debounce(
    input        clk,
    input        rst_n,
	input        key1,
    output [5:0] seg_sel,
    output [7:0] seg_data
);
//调用模块，开始进行消抖工作，只需要消抖后的下降沿
wire button_negedge; 
ax_debounce ax_debounce_m0
(
    .clk             (clk),
    .rst             (~rst_n),
    .button_in       (key1),
    .button_posedge  (),
    .button_negedge  (button_negedge),
    .button_out      ()
);
//按键按一下（以上面模块消抖后的下降沿输出为准），计数1次（十进制的两位数）
wire[3:0] count;
wire t0;
count_m10 count10_m0(
    .clk    (clk),
    .rst_n  (rst_n),
    .en     (button_negedge),
    .clr    (1'b0),
    .data   (count),
    .t      (t0)
);
wire[3:0] count1;
wire t1;
count_m10 count10_m1(
    .clk    (clk),
    .rst_n  (rst_n),
    .en     (t0),
    .clr    (1'b0),
    .data   (count1),
    .t      (t1)
);
//输出数据至数码管（1.需点亮的数码管；2.显示的数字）
wire[6:0] seg_data_0;
seg_decoder seg_decoder_m0(
    .bin_data  (count),
    .seg_data  (seg_data_0)
);

wire[6:0] seg_data_1;
seg_decoder seg_decoder_m1(
    .bin_data  (count1),
    .seg_data  (seg_data_1)
);
seg_scan seg_scan_m0(
    .clk        (clk),
    .rst_n      (rst_n),
    .seg_sel    (seg_sel),
    .seg_data   (seg_data),
    .seg_data_0 ({1'b1,7'b1111_111}),
    .seg_data_1 ({1'b1,7'b1111_111}),
    .seg_data_2 ({1'b1,7'b1111_111}),
    .seg_data_3 ({1'b1,7'b1111_111}),
    .seg_data_4 ({1'b1,seg_data_1}),
    .seg_data_5 ({1'b1,seg_data_0})
);
endmodule 