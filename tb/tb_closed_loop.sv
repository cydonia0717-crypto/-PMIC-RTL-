`timescale 1ns/1ps
module tb_closed_loop;
 reg clk=0,rst=1,enable=0,valid=0;
 always #5 clk=~clk;
 reg [11:0] target=2048,measured=0;
 wire ready,done;wire [15:0] duty;wire signed [31:0] integral;wire signed [12:0] error;
 fixed_pid pid(clk,rst,enable,valid,target,measured,16'sd2,16'sd1,16'sd0,1'b0,16'd0,16'd60,ready,done,duty,integral,error);
 wire hi,lo,frame;wire [15:0] phase,active;wire [7:0] ad;
 pwm_deadtime #(.PERIOD(64)) pwm(clk,rst,enable,1'b0,duty,8'd2,hi,lo,frame,phase,active,ad);
 integer step,v=0,load_offset,drive,difference,high_count=0,previous_count,fd,cycles;
 always @(posedge clk) if(enable)begin
  if(hi)high_count=high_count+1;
  if(hi&&lo)$fatal(1,"closed loop overlap");
 end
 initial begin
  fd=$fopen("build/closed_loop.csv","w");
  repeat(3)@(negedge clk);rst=0;enable=1;
  for(step=0;step<1200;step=step+1)begin
   @(negedge clk);while(!frame)@(negedge clk);
   previous_count=high_count;high_count=0;
   target=step<400 ? 2048 : 2600;
   load_offset=step<800 ? 0 : 400;
   drive=previous_count*4095/64-load_offset;
   difference=drive-v;
   if(difference>=0)v=v+difference/8;else v=v-(-difference)/8;
   if(v<0)v=0;if(v>4095)v=4095;
   measured=12'(v);valid=1;@(negedge clk);valid=0;cycles=0;
   while(!done)begin @(negedge clk);cycles++;if(cycles>6)$fatal(1,"loop PID timeout");end
   $fwrite(fd,"%0d %0d %0d %0d %0d %0d %0d\n",step,target,v,duty,integral,previous_count,load_offset);
  end
  if(v<2550 || v>2650)$fatal(1,"loop didn't settle voltage=%0d",v);
  $fclose(fd);$display("PASS closed_loop samples=1200 final_voltage=%0d target=%0d",v,target);$finish;
 end
endmodule
