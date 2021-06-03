//设计整个spi_flash测试流程：按一下按键，flash存储的数据+1并显示到数码管上
//具体操作通过调用其他模块来实现
`include "spi_flash_defines.v"
module spi_flash_test
(
	input        clk,
	input        rst_n,
	input        key1,
	output       ncs,
	output       dclk, //clock
	output       mosi, //master output
	input        miso, //maser input
	output [5:0] seg_sel,
	output [7:0] seg_data
);
localparam S_IDLE    = 0;
localparam S_READ_ID = 1;
localparam S_SE      = 2;//页擦除（Sector Erase）
localparam S_PP      = 3;
localparam S_READ    = 4;
localparam S_WAIT    = 5;
reg[3:0] state;

wire button_negedge;
reg [7:0] read_data;//寄存器，用于进行值传递
reg [31:0] timer;

reg        flash_read;
reg        flash_write;
reg        flash_bulk_erase;
reg        flash_sector_erase;
wire       flash_read_ack;
wire       flash_write_ack;
wire       flash_bulk_erase_ack;
wire       flash_sector_erase_ack;
reg [23:0] flash_read_addr;
reg [23:0] flash_write_addr;
reg [23:0] flash_sector_addr;
reg [7:0]  flash_write_data_in;
wire [8:0] flash_read_size;
wire [8:0] flash_write_size;
wire       flash_write_data_req;
wire [7:0] flash_read_data_out;
wire       flash_read_data_valid;

//flash的读写字节大小定义
assign flash_read_size = 9'd1;
assign flash_write_size = 9'd1;
//调用按键消抖模块
ax_debounce ax_debounce_m0
(
	.clk             (clk),
	.rst             (~rst_n),
	.button_in       (key1),
	.button_posedge  (),
	.button_negedge  (button_negedge),
	.button_out      ()
);
//调用数码管模块，确定两个数码显示管m0和m1索要显示的data数据
wire[6:0] seg_data_0;
seg_decoder seg_decoder_m0
(
	.bin_data  (read_data[3:0]),
	.seg_data  (seg_data_0)
);
wire[6:0] seg_data_1;
seg_decoder seg_decoder_m1
(
	.bin_data  (read_data[7:4]),
	.seg_data  (seg_data_1)
);
//调用数码管扫描选通模块
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
//flash_test状态机，状态的跳转在本文件中完成，相关的命令操作（擦除、读、写、等待操作）
always @(posedge clk or negedge rst_n)
begin
	//重置
	if(rst_n == 1'b0)
		begin
			state <= S_IDLE;
			flash_read <= 1'b0;
			flash_write <= 1'b0;
			flash_bulk_erase <= 1'b0;
			flash_sector_erase <= 1'b0;
			flash_read_addr <= 24'd0;
			flash_write_addr <= 24'd0;
			flash_sector_addr <= 24'd0;
			flash_write_data_in <= 8'd0;
			timer <= 32'd0;
		end
	//状态跳转
	else
		case(state)
			//空闲状态，计时器计时250ms（12_500_000*0.02us*10^-3=250ms）之后，跳转至READ状态
			S_IDLE:
				begin
					if(timer >= 32'd12_499_999)
						state <= S_READ;
					else
						timer <= timer + 32'd1;
				end
			//等待状态
			S_WAIT:
				//如果有按键按下，状态将跳转至SE（扇区擦除）状态，且read_data+1（后续将把这个“+1”的数据写入flash，并通过数码管显示出来）
				if(button_negedge == 1'b1)
					begin
						state <= S_SE;
						read_data <= read_data + 8'd1;
					end
			//扇区擦除状态
			S_SE:
				begin
					//若擦除应答=1（表示擦除完成），则擦除请求置0（不请求擦除），状态跳转至页编程状态
					if(flash_sector_erase_ack == 1'b1)
						begin
							flash_sector_erase <= 1'b0;
							state <= S_PP;
						end
					//若擦除应答=0（表示没擦完），则发出扇区擦除请求（1'b1），扇区擦除地址指向首位（24'd0）（由top模块转至ctrl模块，由ctrl模块发出flash擦除指令）
					else
						begin
							flash_sector_erase <= 1'b1;
							flash_sector_addr <= 24'd0;
						end
				end
			//页编程状态
			S_PP:
				begin
					//若写数据拉取=1，则将要写的数据（read_data）存入写过程中所请求的数据寄存器（flash_write_data_in）
					if(flash_write_data_req == 1'b1)
						begin
							flash_write_data_in <= read_data;
						end
					//若写应答=1（表示写操作完成），则写操作请求置0（不请求写），状态跳转至读状态
					if(flash_write_ack == 1'b1)
						begin
							flash_write <= 1'b0;
							state <= S_READ;
						end
					//若写应答=0（表示没写完），则保持发出写请求（1'b1），写地址指向首位（24'd0）（由top模块转至ctrl模块，由ctrl模块发出flash写指令）
					else
						begin
							flash_write <= 1'b1;
							flash_write_addr <= 24'd0;
						end
				end
			//读状态
			S_READ:
				begin
					//如果读信号是有效的，则将读取到的数据（flash_read_data_out）放在read_data寄存器
					if(flash_read_data_valid == 1'b1)
						begin
							read_data <= flash_read_data_out;
						end
					//若读应答=1（表示已经读完了），则读操作请求置0（不请求读），状态跳转至等待状态
					if(flash_read_ack == 1'b1)
						begin
							flash_read <= 1'd0;
							state <= S_WAIT;
						end
					//若读应答=0（表示没读完），则保持发出读请求（1'b1），读地址指向首位（24'd0）（由top模块转至ctrl模块，由ctrl模块发出flash写指令）
					else
						begin
							flash_read <= 1'd1;
							flash_read_addr <= 24'd0;
						end
				end
			default:
				state <= S_IDLE;
		endcase
end
//调用flash_top模块，经由top模块（类似网关转发信号的作用）控制子模块进而实现既定功能（按一下按键，数码管显示数字+1，且断电重启不会将上一回显示的数字清零）
spi_flash_top spi_flash_top_m0(
	.sys_clk                     (clk                      ),
	.rst                         (~rst_n                   ),
	.nCS                         (ncs                      ),
	.DCLK                        (dclk                     ),
	.MOSI                        (mosi                     ),
	.MISO                        (miso                     ),
	.clk_div                     (16'd0                    ), //将50Mhz四分频
	.flash_read                  (flash_read               ),
	.flash_write                 (flash_write              ),
	.flash_bulk_erase            (flash_bulk_erase         ),
	.flash_sector_erase          (flash_sector_erase       ),
	.flash_read_ack              (flash_read_ack           ),
	.flash_write_ack             (flash_write_ack          ),
	.flash_bulk_erase_ack        (flash_bulk_erase_ack     ),
	.flash_sector_erase_ack      (flash_sector_erase_ack   ),
	.flash_read_addr             (flash_read_addr          ),
	.flash_write_addr            (flash_write_addr         ),
	.flash_sector_addr           (flash_sector_addr        ),
	.flash_write_data_in         (flash_write_data_in      ),
	.flash_read_size             (flash_read_size          ),
	.flash_write_size            (flash_write_size         ),
	.flash_write_data_req        (flash_write_data_req     ),
	.flash_read_data_out         (flash_read_data_out      ),
	.flash_read_data_valid       (flash_read_data_valid    )
);
endmodule