`timescale 1ns/1ps
// Bundled-data toggle handshake: payload is held until acknowledgement returns.
module adc_mailbox #(parameter WIDTH=96)(
 input wire src_clk,src_rst,src_valid,output wire src_ready,input wire [WIDTH-1:0] src_data,
 input wire dst_clk,dst_rst,dst_ready,output reg dst_valid,output reg [WIDTH-1:0] dst_data
);
 reg request,ack;
 reg [WIDTH-1:0] held;
 (* ASYNC_REG="TRUE" *) reg [1:0] ack_sync,req_sync;
 assign src_ready=request==ack_sync[1];
 always @(posedge src_clk) begin
  if(src_rst) begin request<=0;held<=0;ack_sync<=0;end
  else begin
   ack_sync<={ack_sync[0],ack};
   if(src_valid && src_ready) begin held<=src_data;request<=!request;end
  end
 end
 always @(posedge dst_clk) begin
  if(dst_rst) begin req_sync<=0;ack<=0;dst_valid<=0;dst_data<=0;end
  else begin
   req_sync<={req_sync[0],request};dst_valid<=0;
   if(req_sync[1]!=ack && dst_ready && !dst_valid) begin dst_data<=held;dst_valid<=1;ack<=req_sync[1];end
  end
 end
endmodule
