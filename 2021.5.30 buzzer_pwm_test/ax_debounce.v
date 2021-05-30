//计时消抖单元（通过对外部时钟信号的计数来实现计时的功能，进而达到消抖的目的）
`timescale 1 ns / 100 ps
module  ax_debounce 
(
    input       clk,
    input       rst,//高电平rest
    input       button_in,
    output reg  button_posedge,
    output reg  button_negedge,
    output reg  button_out
);

//内部参数
parameter N = 32 ;//消抖时间位宽
parameter FREQ = 50;//外部时钟频率（单位MHz） 50MHz对应周期为20ns
parameter MAX_TIME = 20;//设定最大消抖时间（ms）
localparam TIMER_MAX_VAL =   MAX_TIME * 1000 * FREQ;//根据外部时钟频率计算得出达到MAX_TIME(本例设定为20ms）所需累计的次数

//内部信号
reg  [N-1 : 0]  q_reg;//时间寄存器（根据其中计的次数*外部时钟对应的周期，即可得到计时长度）
reg  [N-1 : 0]  q_next;//寄存着时间寄存器下一个周期所需写入的值（1.维持当前值；2.当前值+1；3.清零重置）
reg DFF1, DFF2;//触发器
wire q_add;
wire q_reset;
reg button_out_d0;//记录当前输出状态的寄存器

//计数器的控制部分
assign q_reset = (DFF1  ^ DFF2);          //若两个寄存器的输出不一致，则表示输入还在抖动，则整个计时（数）器重新计时（数）
assign q_add = ~(q_reg == TIMER_MAX_VAL);//若时间寄存器内的值达到“预设消抖时间对应需要计的次数”，则q_add置零，表示q_reg（时间寄存器）不需要再累加计数了
    
//通过控制部分及计数器的信号跳变，确认下一周期时间寄存器所需写入的值是多少
always @ ( q_reset, q_add, q_reg)
begin
    case( {q_reset , q_add})
        2'b00 :
                q_next <= q_reg;
        2'b01 :
                q_next <= q_reg + 1;
        default :
                q_next <= { N {1'b0} };
    endcase     
end

//1.检测当前周期外部输入的情况，并将其存入触发器，以便控制部分做出响应；2.给时间寄存器赋新值（具体赋值内容由上一个always确定）
always @ ( posedge clk or posedge rst)
begin
    if(rst == 1'b1)
    begin
        DFF1 <= 1'b0;
        DFF2 <= 1'b0;
        q_reg <= { N {1'b0} };
    end
    else
    begin
        DFF1 <= button_in;
        DFF2 <= DFF1;
        q_reg <= q_next;
    end
end

//消抖模块输出内容的判定
always @ ( posedge clk or posedge rst)
begin
//重置
	if(rst == 1'b1)
		button_out <= 1'b1;
//消抖时间达到设定时间，out即可跟随DFF2
	else if(q_reg == TIMER_MAX_VAL)
        button_out <= DFF2;
	else
        button_out <= button_out;
end

//
always @ ( posedge clk or posedge rst)
begin
//重置
	if(rst == 1'b1)
	begin
		button_out_d0 <= 1'b1;
		button_posedge <= 1'b0;
		button_negedge <= 1'b0;
	end
//利用非阻塞赋值达到一下目的：1.用button_out_d0来记录此刻输出内容；2.结合消抖前（out_d0）和消抖后（out）的输出来判定：当前输出的信号是按下按钮还是抬起按钮
//如果使用的是阻塞复制，pos和neg都没变化（保持为0）
	else
	begin
		button_out_d0 <= button_out;
		button_posedge <= ~button_out_d0 & button_out;
		button_negedge <= button_out_d0 & ~button_out;
	end	
end
endmodule


