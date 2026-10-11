`timescale 1ns/1ps
// Ordered 0->3 startup, qualified power-good; ordered 3->0 normal shutdown.
module rail_sequencer #(parameter QUALIFY=3)(
 input wire clk,rst,tick,run,input wire [3:0] clear_fault,mask,good,faults,
 input wire [31:0] startup_delays,input wire [63:0] startup_timeouts,
 output reg [3:0] enabled,qualified,timeout_faults,output reg [2:0] state,
 output wire ready
);
 localparam OFF=0,DELAY=1,WAIT_GOOD=2,ON=3,SHUTDOWN=4,FAULT=5;
 reg [1:0] rail;
 reg [15:0] elapsed;
 reg [7:0] good_count;
 assign ready=state==ON;
 wire [7:0] delay_value=startup_delays[rail*8+:8];
 wire [15:0] timeout_value=startup_timeouts[rail*16+:16];
 always @(posedge clk) begin
  if(rst) begin enabled<=0;qualified<=0;timeout_faults<=0;state<=OFF;rail<=0;elapsed<=0;good_count<=0;end
  else if(|faults || |timeout_faults) begin
   enabled<=0;qualified<=0;state<=FAULT;
   if(|clear_fault && !run) begin timeout_faults<=timeout_faults & ~clear_fault;state<=OFF;end
  end else if(state==FAULT) begin
   enabled<=0;qualified<=0;
   if(|clear_fault && !run) begin timeout_faults<=timeout_faults & ~clear_fault;state<=OFF;end
  end else begin
   if(!run && state!=OFF && state!=SHUTDOWN) begin state<=SHUTDOWN;rail<=3;elapsed<=0;end
   else if(tick) case(state)
    OFF: if(run && |mask) begin state<=DELAY;rail<=0;elapsed<=0;good_count<=0;end
    DELAY: begin
     if(!mask[rail]) begin
      if(rail==3) state<=ON;else rail<=rail+1'b1;
      elapsed<=0;
     end else if(elapsed>={8'd0,delay_value}) begin enabled[rail]<=1;state<=WAIT_GOOD;elapsed<=0;good_count<=0;end
     else elapsed<=elapsed+1'b1;
    end
    WAIT_GOOD: begin
     elapsed<=elapsed+1'b1;
     if(good[rail]) begin
      if(good_count>=QUALIFY-1) begin
       qualified[rail]<=1;
       if(rail==3) state<=ON;else begin rail<=rail+1'b1;state<=DELAY;end
       elapsed<=0;good_count<=0;
      end else good_count<=good_count+1'b1;
     end else good_count<=0;
     if(elapsed>=timeout_value) begin timeout_faults[rail]<=1;enabled<=0;qualified<=0;state<=FAULT;end
    end
    ON: begin end
    SHUTDOWN: begin
     enabled[rail]<=0;qualified[rail]<=0;
     if(rail==0) state<=OFF;else rail<=rail-1'b1;
    end
    default: begin state<=OFF;enabled<=0;qualified<=0;end
   endcase
  end
 end
endmodule
