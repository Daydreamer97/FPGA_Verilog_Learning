`timescale 1ns / 1ps
module ax_pwm
#(
	parameter N = 16//pwm的位宽
)
(
    input         clk,
    input         rst,
    input[N - 1:0]period,
    input[N - 1:0]duty,
    output        pwm_out 
);
 
reg[N - 1:0] period_r;
reg[N - 1:0] duty_r;
reg[N - 1:0] period_cnt;
reg pwm_r;

assign pwm_out = pwm_r;//pwm输出

always@(posedge clk or posedge rst)
begin
//重置
    if(rst==1)
    begin
        period_r <= { N {1'b0} };
        duty_r <= { N {1'b0} };
    end
//
    else
    begin
        period_r <= period;
        duty_r   <= duty;
    end
end

always@(posedge clk or posedge rst)
begin
//重置
    if(rst==1)
        period_cnt <= { N {1'b0} };
//
    else
        period_cnt <= period_cnt + period_r;
end

always@(posedge clk or posedge rst)
begin
//重置
    if(rst==1)
    begin
        pwm_r <= 1'b0;
    end
//比对period计数值和设定的duty的值，确认输出的pwm信号是高还是低
    else
    begin
        if(period_cnt >= duty_r)
            pwm_r <= 1'b1;
        else
            pwm_r <= 1'b0;
    end
end

endmodule
