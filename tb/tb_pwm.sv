`timescale 1ns/1ps
module tb_pwm;
 reg clk=0,rst=1,enable=0,kill=0;
 always #5 clk=~clk;
 reg [15:0] duty=0;reg [7:0] dead=0;
 wire hi,lo,frame;wire [15:0] phase,active;wire [7:0] ad;
 pwm_deadtime #(.PERIOD(64)) dut(clk,rst,enable,kill,duty,dead,hi,lo,frame,phase,active,ad);
 integer d,dt,n,h,l,cases=0;
 always @(negedge clk) if(hi&&lo)$fatal(1,"shoot through");
 initial begin
  repeat(3)@(negedge clk);rst=0;
  for(dt=0;dt<=8;dt=dt+2)for(d=0;d<=64;d=d+4)begin
   enable=0;@(negedge clk);duty=16'(d);dead=8'(dt);enable=1;
   @(negedge clk);while(!frame)@(negedge clk);
   h=0;l=0;
   for(n=0;n<64;n=n+1)begin
    if(hi)h=h+1;if(lo)l=l+1;@(negedge clk);
   end
   if(h!=(d>dt ? d-dt : 0) || l!=(64-d>dt ? 64-d-dt : 0))$fatal(1,"PWM d=%0d dt=%0d h=%0d l=%0d",d,dt,h,l);
   cases=cases+1;
  end
  // Mid-frame duty/deadtime changes must wait for the boundary.
  enable=0;@(negedge clk);duty=20;dead=3;enable=1;repeat(10)@(negedge clk);
  duty=40;dead=7;repeat(10)@(negedge clk);
  if(active!=20 || ad!=3)$fatal(1,"mid-frame update");
  while(!frame)@(negedge clk);
  if(active!=40 || ad!=7)$fatal(1,"command not latched at boundary");
  kill=1;#1;if(hi||lo)$fatal(1,"kill delayed");
  @(negedge clk);kill=0;enable=0;#1;if(hi||lo)$fatal(1,"disabled outputs");
  $display("PASS pwm cases=%0d deadtime/nooverlap/boundary/kill",cases);$finish;
 end
endmodule
