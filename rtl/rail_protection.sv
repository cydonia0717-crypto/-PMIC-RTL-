`timescale 1ns/1ps
module rail_protection #(parameter DEBOUNCE=3,parameter STALE_CYCLES=100000)(
 input wire clk,rst,enable,qualified,sample_valid,clear,external_trip,
 input wire [11:0] voltage,current,uv_limit,ov_limit,oc_limit,
 output reg [5:0] causes,output wire fault
);
 reg [15:0] uv_count,ov_count,oc_count;
 reg [31:0] stale_count;
 assign fault=|causes;
 always @(posedge clk) begin
  if(rst) begin causes<=0;uv_count<=0;ov_count<=0;oc_count<=0;stale_count<=0;end
  else if(clear && !enable) begin causes<=0;uv_count<=0;ov_count<=0;oc_count<=0;stale_count<=0;end
  else if(enable) begin
   if(external_trip) causes[5]<=1;
   if(sample_valid) begin
    stale_count<=0;
    if(voltage>ov_limit) begin
     if(ov_count<DEBOUNCE) ov_count<=ov_count+1'b1;
     if(ov_count>=DEBOUNCE-1) causes[0]<=1;
    end else ov_count<=0;
    if(qualified && voltage<uv_limit) begin
     if(uv_count<DEBOUNCE) uv_count<=uv_count+1'b1;
     if(uv_count>=DEBOUNCE-1) causes[1]<=1;
    end else uv_count<=0;
    if(current>oc_limit) begin
     if(oc_count<DEBOUNCE) oc_count<=oc_count+1'b1;
     if(oc_count>=DEBOUNCE-1) causes[2]<=1;
    end else oc_count<=0;
   end else begin
    if(stale_count<STALE_CYCLES) stale_count<=stale_count+1'b1;
    if(stale_count>=STALE_CYCLES-1) causes[4]<=1;
   end
  end else begin uv_count<=0;ov_count<=0;oc_count<=0;stale_count<=0;end
 end
endmodule
