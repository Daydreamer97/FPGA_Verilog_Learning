module buzzer_pwm_test
(
	input clk,
	input rst_n,
	input key1,
	output buzzer
);
parameter IDLE    = 0;
parameter BUZZER  = 1;
wire button_negedge;
wire pwm_out;
reg[31:0] period;
reg[31:0] duty;

reg[3:0] state;
reg[31:0] timer;

assign buzzer = ~(pwm_out & (state == BUZZER));//pwm有输出且处于BUZZER状态，buzzer才被驱动（低有效）

always@(posedge clk or negedge rst_n)
begin
	if(rst_n == 1'b0)
	begin
		period <= 32'd0;
		timer <= 32'd0;
		duty <= 32'd429496729;
		state <= IDLE;
	end
	else
		case(state)
			IDLE:
				begin
					if(button_negedge)
					begin
						period <= 32'd8590;   //The pwm step value
						state <= BUZZER;
						duty <= duty + 32'd429496729;	
					end
				end
//蜂鸣器持续蜂鸣时间不大于250ms
			BUZZER:
				begin
					if(timer >= 32'd12_499_999)
					begin
						state <= IDLE;
						timer <= 32'd0;
					end
					else
					begin
						timer <= timer + 32'd1;
					end
				end
			default:
				begin
					state <= IDLE;		
				end			
		endcase
end
//调用按键消抖模块
ax_debounce m0
(
    .clk             (clk),
    .rst             (~rst_n),
    .button_in       (key1),
    .button_posedge  (),
    .button_negedge  (button_negedge),
    .button_out      ()
);
//调用pwm模块
ax_pwm#
(
    .N(32)
) 
ax_pwm_m0(
    .clk      (clk),
    .rst      (~rst_n),
    .period   (period),
    .duty     (duty),
    .pwm_out  (pwm_out)
    );
	
endmodule 