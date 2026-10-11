`timescale 1ns/1ps
// Edge-aligned complementary outputs. Commands update only at period boundary.
module pwm_deadtime #(parameter PERIOD=1024)(
 input wire clk,rst,enable,kill,input wire [15:0] duty,input wire [7:0] deadtime,
 output wire high_gate,low_gate,output wire frame_start,output reg [15:0] phase,
 output reg [15:0] active_duty,output reg [7:0] active_deadtime
);
 reg armed;
 wire [16:0] low_start={1'b0,active_duty}+{9'd0,active_deadtime};
 assign frame_start=armed && phase==0;
 assign high_gate=enable && armed && !kill && phase>={8'd0,active_deadtime} && phase<active_duty;
 assign low_gate=enable && armed && !kill && {1'b0,phase}>=low_start && phase<PERIOD;
 always @(posedge clk) begin
  if(rst || !enable || kill) begin phase<=0;active_duty<=0;active_deadtime<=0;armed<=0;end
  else begin
   if(!armed || phase==PERIOD-1) begin
    armed<=1;phase<=0;
    if(duty>PERIOD) active_duty<=16'(PERIOD);else active_duty<=duty;
    active_deadtime<=deadtime;
   end else phase<=phase+1'b1;
  end
 end
endmodule
