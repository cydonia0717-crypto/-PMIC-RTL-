`timescale 1ns/1ps
module tb_pid;
 reg clk=0,rst=1,enable=1,valid=0;
 always #5 clk=~clk;
 reg [11:0] target,measured;
 reg signed [15:0] kp,ki,kd; reg deriv;
 reg [15:0] dmin,dmax;
 wire ready,done;wire [15:0] duty;wire signed [31:0] integral;wire signed [12:0] error;
 fixed_pid dut(clk,rst,enable,valid,target,measured,kp,ki,kd,deriv,dmin,dmax,ready,done,duty,integral,error);
 integer f,n,got,res,t,m,p,i,d,de,mn,mx,ed,ei,ee,cycles;
 initial begin
  f=$fopen("build/pid_vectors.txt","r");if(!f)$fatal(1,"vectors missing");
  repeat(3)@(negedge clk);rst=0;n=0;
  while(!$feof(f)) begin
   got=$fscanf(f,"%d %d %d %d %d %d %d %d %d %d %d %d\n",res,t,m,p,i,d,de,mn,mx,ed,ei,ee);
   if(got!=12)$fatal(1,"bad vector");
   if(res)begin rst=1;@(negedge clk);rst=0;end
   target=12'(t);measured=12'(m);kp=16'(p);ki=16'(i);kd=16'(d);deriv=1'(de);dmin=16'(mn);dmax=16'(mx);valid=1;
   @(negedge clk);valid=0;cycles=0;
   while(!done)begin @(negedge clk);cycles=cycles+1;if(cycles>6)$fatal(1,"PID timeout");end
   if(duty!==16'(ed) || integral!==ei || error!==13'(ee)) $fatal(1,"PID vector=%0d duty=%d/%d integral=%d/%d error=%d/%d",n,duty,ed,integral,ei,error,ee);
   if(cycles!=3)$fatal(1,"latency %0d",cycles);
   n=n+1;@(negedge clk);
  end
  enable=0;@(negedge clk);if(duty!=0 || integral!=0)$fatal(1,"disabled PID not reset");
  $display("PASS pid vectors=%0d latency=3 after acceptance",n);$finish;
 end
endmodule
