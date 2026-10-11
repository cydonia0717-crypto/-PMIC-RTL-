`timescale 1ns/1ps
module tb_mailbox;
 reg sc=0,dc=0,srst=1,drst=1;
 always #7 sc=~sc;always #5 dc=~dc;
 reg sv=0;wire sr;reg [95:0] sd;
 reg dr=0;wire dv;wire [95:0] dd;
 adc_mailbox dut(sc,srst,sv,sr,sd,dc,drst,dr,dv,dd);
 integer sent=0,received=0,epoch=0,cycles=0;
 reg [31:0] rng=32'h2345;
 function automatic [95:0] pattern(input integer n,input integer e);
  pattern={32'(n^e),32'(~n),32'(n*73+e)};
 endfunction
 always @(negedge sc)begin
  if(srst)sv=0;else begin sv=sr && sent<1000;sd=pattern(sent,epoch);end
 end
 always @(posedge sc)if(!srst && sv && sr)sent<=sent+1;
 always @(negedge dc)begin
  rng={rng[30:0],rng[31]^rng[21]^rng[1]^rng[0]};
  dr=!drst && rng[0] && cycles%128>=40;
 end
 always @(posedge dc)if(!drst)begin
  cycles<=cycles+1;
  if(dv)begin
   if(dd!==pattern(received,epoch))$fatal(1,"CDC data torn/duplicate/lost at %0d got=%h",received,dd);
   received<=received+1;
  end
 end
 initial begin
  repeat(5)@(negedge dc);srst=0;drst=0;
  wait(received==1000);repeat(10)@(negedge dc);
  // Common reset discards an outstanding frame. Producers restart after release.
  srst=1;drst=1;sent=0;received=0;epoch=1;
  repeat(5)@(negedge dc);srst=0;drst=0;
  wait(sent>100 && sent>received);srst=1;drst=1;sent=0;received=0;epoch=2;
  repeat(5)@(negedge dc);srst=0;drst=0;
  wait(received==1000);repeat(10)@(negedge dc);
  $display("PASS mailbox frames=2000 plus interrupted epoch, async clocks and backpressure");$finish;
 end
 initial begin #1000000;$fatal(1,"CDC timeout");end
endmodule
