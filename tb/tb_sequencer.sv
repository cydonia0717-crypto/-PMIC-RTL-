`timescale 1ns/1ps
module tb_sequencer;
 reg clk=0,rst=1,tick=0,run=0;
 always #5 clk=~clk;
 reg [3:0] clear=0,mask=15,good=15,faults=0;
 reg [31:0] delays=32'h03020100;
 reg [63:0] timeouts={4{16'd20}};
 wire [3:0] enabled,qualified,timeout_faults;
 wire [2:0] state;wire ready;
 rail_sequencer dut(clk,rst,tick,run,clear,mask,good,faults,delays,timeouts,enabled,qualified,timeout_faults,state,ready);
 integer r,j,cases=0;
 task step;
  begin tick=1;@(negedge clk);tick=0;@(negedge clk);end
 endtask
 task reset_case;
  begin rst=1;run=0;clear=0;faults=0;repeat(2)@(negedge clk);rst=0;end
 endtask
 initial begin
  reset_case();run=1;step();
  for(r=0;r<4;r=r+1) begin
   if(state!=1 || dut.elapsed!=0)$fatal(1,"next rail must enter DELAY with zero count rail=%0d",r);
   for(j=0;j<=r;j=j+1) begin
    step();
    if(j<r && enabled[r])$fatal(1,"rail %0d delay shortened",r);
   end
   if(!enabled[r] || state!=2)$fatal(1,"rail %0d enable timing",r);
   step();step();if(qualified[r])$fatal(1,"early qualification");
   step();if(!qualified[r])$fatal(1,"qualification missing");
  end
  if(!ready || enabled!=15)$fatal(1,"all rails not ready");cases++;
  run=0;@(negedge clk);
  for(r=3;r>=0;r=r-1) begin step();if(enabled!=((1<<r)-1))$fatal(1,"shutdown order");end
  if(state!=0)$fatal(1,"shutdown not OFF");cases++;

  reset_case();mask=5;delays=0;run=1;step();step();
  good=0;step();good=15;step();step();if(qualified[0])$fatal(1,"PG counter retained bad tick");
  step();if(!qualified[0])$fatal(1,"PG qualification");
  step();if(enabled!=1)$fatal(1,"masked rail enabled");
  step();step();step();step();step();
  if(enabled!=5 || !ready)$fatal(1,"mask startup");cases++;
  faults=4;@(negedge clk);if(enabled!=0 || state!=5)$fatal(1,"fault did not shut down");cases++;

  reset_case();mask=1;good=0;timeouts={4{16'd3}};run=1;step();step();
  // One bad tick then three good ticks: deadline coincides with qualification.
  step();good=15;step();step();step();
  if(timeout_faults!=1 || enabled!=0 || qualified!=0 || state!=5)$fatal(1,"timeout deadline priority");
  run=0;clear=2;@(negedge clk);clear=0;repeat(2)@(negedge clk);
  if(timeout_faults!=1 || state!=5)$fatal(1,"wrong W1C mask cleared timeout");
  clear=1;@(negedge clk);clear=0;@(negedge clk);
  if(timeout_faults!=0 || state!=0)$fatal(1,"timeout clear/recovery");cases++;
  $display("PASS sequencer cases=%0d exact delays/PG reset/mask/reverse/fault/deadline/W1C",cases);$finish;
 end
 initial begin #100000;$fatal(1,"sequencer test timeout");end
endmodule
