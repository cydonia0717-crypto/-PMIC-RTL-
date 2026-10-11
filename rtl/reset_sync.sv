`timescale 1ns/1ps
// Common asynchronous assertion, independent two-clock synchronous release.
module reset_sync(input wire clk,arst_n,output wire rst);
 (* ASYNC_REG="TRUE" *) reg [1:0] release_pipe;
 always @(posedge clk or negedge arst_n)
  if(!arst_n) release_pipe<=0; else release_pipe<={release_pipe[0],1'b1};
 assign rst=!release_pipe[1];
endmodule
