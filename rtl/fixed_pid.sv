`timescale 1ns/1ps
// Position PID. Coefficients are signed Q8.8; state/integral is Q8.8 duty counts.
// Multiplication and accumulation occupy separate cycles; conditional anti-windup.
module fixed_pid(
 input wire clk,rst,enable,sample_valid,
 input wire [11:0] target,measured,
 input wire signed [15:0] kp,ki,kd,input wire derivative_enable,
 input wire [15:0] duty_min,duty_max,
 output wire ready,output reg done,output reg [15:0] duty,
 output reg signed [31:0] integral_q,output reg signed [12:0] error_debug
);
 localparam IDLE=0,MULT=1,ACC=2,OUTPUT=3;
 reg [1:0] state;
 reg signed [12:0] error,previous_error;
 reg signed [13:0] difference;
 reg signed [15:0] kp_hold,ki_hold,kd_hold;
 reg signed [31:0] p_term,i_delta,d_term,candidate_i;
 reg signed [63:0] sum_q;
 reg [15:0] min_hold,max_hold;
 wire signed [63:0] i_unclamped={{32{integral_q[31]}},integral_q}+{{32{i_delta[31]}},i_delta};
 wire signed [63:0] integer_duty=sum_q >>> 8;
 wire signed [63:0] min_extended=$signed({48'd0,min_hold});
 wire signed [63:0] max_extended=$signed({48'd0,max_hold});
 wire saturating_high=integer_duty>max_extended && error>0;
 wire saturating_low=integer_duty<min_extended && error<0;
 assign ready=state==IDLE;
 function automatic signed [31:0] clamp_integral(input signed [63:0] x);
  begin
   if(x>64'sd8388352) clamp_integral=32'sd8388352;
   else if(x< -64'sd8388352) clamp_integral= -32'sd8388352;
   else clamp_integral=x[31:0];
  end
 endfunction
 wire signed [31:0] clamped_i=clamp_integral(i_unclamped);
 wire signed [12:0] new_error=$signed({1'b0,target})-$signed({1'b0,measured});
 always @(posedge clk) begin
  if(rst || !enable) begin
   state<=IDLE;done<=0;duty<=0;integral_q<=0;error<=0;previous_error<=0;
   difference<=0;kp_hold<=0;ki_hold<=0;kd_hold<=0;p_term<=0;i_delta<=0;d_term<=0;
   candidate_i<=0;sum_q<=0;min_hold<=0;max_hold<=0;error_debug<=0;
  end else begin
   done<=0;
   case(state)
    IDLE: if(sample_valid) begin
     error<=new_error;
     difference<=$signed({new_error[12],new_error})-$signed({previous_error[12],previous_error});
     kp_hold<=kp;ki_hold<=ki;kd_hold<=derivative_enable ? kd : 16'sd0;
     min_hold<=duty_min;max_hold<=duty_max;state<=MULT;
    end
    MULT: begin
     p_term<=kp_hold*error;i_delta<=ki_hold*error;d_term<=kd_hold*difference;state<=ACC;
    end
    ACC: begin
     candidate_i<=clamp_integral(i_unclamped);
     sum_q<={{32{p_term[31]}},p_term}+{{32{d_term[31]}},d_term}+
            {{32{clamped_i[31]}},clamped_i};
     state<=OUTPUT;
    end
    OUTPUT: begin
     if(integer_duty>max_extended) duty<=max_hold;
     else if(integer_duty<min_extended) duty<=min_hold;
     else duty<=integer_duty[15:0];
     if(!saturating_high && !saturating_low) integral_q<=candidate_i;
     previous_error<=error;error_debug<=error;done<=1;state<=IDLE;
    end
    default: state<=IDLE;
   endcase
  end
 end
endmodule
