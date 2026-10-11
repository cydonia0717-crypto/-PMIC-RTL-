`timescale 1ns/1ps
module tb_protection;
 reg clk=0,rst=1,en=0,qualified=0,valid=0,clear=0,trip=0;
 always #5 clk=~clk;
 reg [11:0] v=2000,i=10;
 wire [5:0] causes;wire fault;
 rail_protection #(.DEBOUNCE(3),.STALE_CYCLES(32)) dut(clk,rst,en,qualified,valid,clear,trip,v,i,12'd1000,12'd3000,12'd100,causes,fault);
 integer cases=0,n;
 task reset_case;
  begin en=0;clear=1;@(negedge clk);clear=0;v=2000;i=10;trip=0;qualified=1;valid=0;en=1;end
 endtask
 task sample;
  begin valid=1;@(negedge clk);valid=0;@(negedge clk);end
 endtask
 initial begin
  repeat(3)@(negedge clk);rst=0;
  reset_case();v=3500;sample();sample();if(fault)$fatal(1,"debounce too early");
  v=2000;sample();v=3500;sample();sample();if(fault)$fatal(1,"counter didn't reset");sample();if(causes!=1)$fatal(1,"OV miss");cases++;
  clear=1;@(negedge clk);clear=0;if(!fault)$fatal(1,"clear while enabled");
  reset_case();v=500;qualified=0;repeat(4)sample();if(fault)$fatal(1,"startup UV trip");
  qualified=1;repeat(3)sample();if(causes!=2)$fatal(1,"UV miss");cases++;
  reset_case();i=101;repeat(3)sample();if(causes!=4)$fatal(1,"OC miss");cases++;
  reset_case();trip=1;@(negedge clk);if(causes!=32)$fatal(1,"external trip miss");cases++;
  reset_case();repeat(32)@(negedge clk);if(causes!=16)$fatal(1,"stale miss %b",causes);cases++;
  reset_case();v=1000;i=100;repeat(4)sample();if(fault)$fatal(1,"equal threshold trip");v=3000;repeat(4)sample();if(fault)$fatal(1,"OV equality trip");cases++;
  en=0;clear=1;@(negedge clk);if(fault)$fatal(1,"clear didn't work");
  $display("PASS protection cases=%0d debounce/reset/qualified/equality/stale/clear",cases);$finish;
 end
endmodule
