`timescale 1ns/1ps
module tb_pmic;
 reg clk=0,adc_clk=0,arst_n=0;
 always #10 clk=~clk;
 always #13 adc_clk=~adc_clk;
 reg scl=1,master_low=0;
 tri1 sda;
 wire slave_low;
 assign sda=master_low || slave_low ? 1'b0 : 1'bz;
 reg adc_valid=0;
 reg [95:0] adc_data=0;
 wire adc_ready;
 reg [3:0] external_trip=0;
 wire [3:0] enabled,hi,lo,faults;
 wire irq,ready;wire [2:0] state;
 wire [63:0] duties;wire [95:0] samples;
 pmic_top #(.PWM_PERIOD(64),.SEQ_DIV(16),.STALE_CYCLES(512)) dut(
  clk,adc_clk,arst_n,scl,sda,slave_low,adc_valid,adc_data,adc_ready,external_trip,
  enabled,hi,lo,faults,irq,ready,state,duties,samples);
 reg send_adc=1;
 reg [95:0] requested_adc;
 reg [31:0] rng;
 integer seed,scenario,bit_ticks=80,cycle=0,operation=0,start_events=0,stop_events=0,fd;
 reg [3:0] previous_enabled=0;
 reg [7:0] byte_value,second_value;
 reg [1023:0] trace_path;
 reg [5:0] expected_cause;
 integer rail,n,bitn;
 `include "i2c_master.vh"
 always @(posedge clk) begin
  if(arst_n)begin
   cycle<=cycle+1;rng<={rng[30:0],rng[31]^rng[21]^rng[1]^rng[0]};
   if(|(hi&lo))$fatal(1,"PWM overlap");
   if(|faults && (|hi || |lo))$fatal(1,"fault did not gate outputs");
   if(enabled!=previous_enabled)begin
    if(operation==1 && (enabled & previous_enabled)!=previous_enabled)$fatal(1,"startup disabled rail");
    if(operation==2 && (enabled | previous_enabled)!=previous_enabled)$fatal(1,"shutdown enabled rail");
    if(operation==1)begin
     if(enabled==1 || enabled==3 || enabled==7 || enabled==15)start_events<=start_events+1;
     else if(dut.rail_mask==11 && enabled==11)start_events<=start_events+1;
     else $fatal(1,"out of order startup %b",enabled);
    end
    if(operation==2)begin
     if(enabled==7 || enabled==3 || enabled==1 || enabled==0)stop_events<=stop_events+1;
     else $fatal(1,"out of order shutdown %b",enabled);
    end
    $fwrite(fd,"%0d %0d %x %x %x\n",cycle,state,enabled,faults,duties);
    previous_enabled<=enabled;
   end
   if(cycle>2500000)$fatal(1,"system timeout");
  end
 end
 // ADC producer obeys backpressure and keeps a frame stable while valid is pending.
 always @(negedge adc_clk)begin
  if(!arst_n)adc_valid=0;
  else if(adc_valid && adc_ready)begin adc_valid=0;end
  else if(!adc_valid && send_adc)begin adc_data=requested_adc;adc_valid=1;end
 end
 task wait_on;
  integer limit;
  begin limit=0;while(!ready)begin @(negedge clk);limit=limit+1;if(limit>20000)$fatal(1,"startup timeout state=%d faults=%b",state,faults);end end
 endtask
 task wait_off;
  integer limit;
  begin limit=0;while(state!=0)begin @(negedge clk);limit=limit+1;if(limit>20000)$fatal(1,"shutdown timeout");end end
 endtask
 initial begin
  seed=1;scenario=0;
  if($value$plusargs("seed=%d",seed))begin end
  if($value$plusargs("scenario=%d",scenario))begin end
  if(!$value$plusargs("trace=%s",trace_path))trace_path="build/system.trace";
  fd=$fopen(trace_path,"w");if(!fd)$fatal(1,"trace open");rng=32'(seed);
  for(n=0;n<4;n=n+1)requested_adc[n*24+:24]={12'd20,12'd2048};
  if($test$plusargs("vcd"))begin $dumpfile("build/pmic.vcd");$dumpvars(0,tb_pmic);end
  repeat(5)@(negedge clk);arst_n=1;repeat(20)@(negedge clk);
  // One-clock spike must not be recognized as a bus START.
  master_low=1;@(negedge clk);master_low=0;repeat(20)@(negedge clk);
  if(dut.u_i2c.busy)$fatal(1,"SDA glitch became START");
  i2c_start();write_byte(8'h5c,0);i2c_stop();
  set_read_pointer(8'h06);read_byte(byte_value,1);read_byte(second_value,0);i2c_stop();
  if(byte_value!=8'h50 || second_value!=1)$fatal(1,"ID/repeated START read %x %x",byte_value,second_value);
  // STOP aborts an incomplete data byte without changing a register.
  i2c_start();write_byte(8'h5a,1);write_byte(8'h42,1);
  for(bitn=3;bitn>=0;bitn=bitn-1)begin
   master_low=1;bus_wait();scl=1;bus_wait();scl=0;bus_wait();
  end
  i2c_stop();if(dut.u_registers.shadow[2]!=64)$fatal(1,"aborted byte changed register");
  // Incomplete writes affect shadow only. Invalid commit preserves all active records.
  write_word(8'h4e,4095);write_reg(8'h0c,1);
  if(!dut.config_error || dut.cfg[112+:12]!=1600)$fatal(1,"invalid commit accepted");
  write_word(8'h4e,1600);write_reg(8'h0c,1);
  if(dut.config_error)$fatal(1,"valid commit rejected");
  operation=1;write_reg(0,1);wait_on();
  if(enabled!=15 || start_events!=4)$fatal(1,"startup event count %d enabled=%b",start_events,enabled);
  // A shadow edit and illegal running commit must leave the active configuration and enable mask intact.
  write_reg(8'h42,200);if(dut.cfg[16+:16]!=64)$fatal(1,"shadow escaped before commit");
  write_reg(8'h0c,1);
  if(!dut.config_error || !ready || enabled!=15 || dut.cfg[16+:16]!=64)$fatal(1,"running commit disrupted active config");
  read_reg(8'h14,byte_value);if(byte_value!=15)$fatal(1,"enable snapshot read");
  // Read four bytes of a frame while the producer changes; frozen snapshot must remain coherent.
  set_read_pointer(8'h18);
  requested_adc[0+:24]={12'd77,12'd2345};
  read_byte(byte_value,1);if(byte_value!=0)$fatal(1,"snapshot low voltage");
  read_byte(byte_value,1);if(byte_value!=8)$fatal(1,"snapshot high voltage");
  read_byte(byte_value,1);if(byte_value!=20)$fatal(1,"snapshot current");
  read_byte(byte_value,0);if(byte_value!=0)$fatal(1,"snapshot current high");i2c_stop();
  requested_adc[0+:24]={12'd20,12'd2048};
  operation=2;write_reg(0,0);wait_off();
  if(stop_events!=4 || enabled!=0)$fatal(1,"reverse shutdown failed");
  write_reg(8'h0c,1);if(dut.config_error || dut.cfg[16+:16]!=200)$fatal(1,"staged commit failed");
  start_events=0;stop_events=0;
  if(scenario==0)begin
   write_reg(1,11);operation=1;write_reg(0,1);wait_on();
   if(enabled!=11 || start_events!=3)$fatal(1,"masked startup failed");
   operation=2;write_reg(0,0);wait_off();
  end else begin
   if(scenario==6)requested_adc[0+:12]=0;
   operation=scenario==6 ? 3 : 1;write_reg(0,1);
   if(scenario!=6)wait_on();operation=3;
   expected_cause=0;rail=0;
   case(scenario)
    1:begin requested_adc[48+:12]=1000;expected_cause=2;rail=2;end
    2:begin requested_adc[24+:12]=3000;expected_cause=1;rail=1;end
    3:begin requested_adc[84+:12]=3500;expected_cause=4;rail=3;end
    4:begin external_trip=1;expected_cause=32;rail=0;end
    5:begin send_adc=0;expected_cause=16;rail=0;end
    6:begin expected_cause=8;rail=0;end
    default:$fatal(1,"bad scenario");
   endcase
   n=0;while(faults==0)begin @(negedge clk);n=n+1;if(n>12000)$fatal(1,"fault injection missed scenario=%d",scenario);end
   repeat(8)@(negedge clk);
   if(enabled!=0 || !irq || !(dut.causes[rail*6+:6]&expected_cause))$fatal(1,"wrong protection result scenario=%d causes=%h",scenario,dut.causes);
   read_reg(8'(16+rail),byte_value);if(!(byte_value & {2'd0,expected_cause}))$fatal(1,"fault readback");
   // Clearing while RUN remains set is forbidden.
   write_reg(4,15);if(faults==0)$fatal(1,"live fault clear allowed");
   requested_adc={4{{12'd20,12'd2048}}};external_trip=0;send_adc=1;
   write_reg(0,0);write_reg(4,15);repeat(30)@(negedge clk);
   if(faults!=0 || state!=0)$fatal(1,"fault clear failed %b state=%d",faults,state);
   start_events=0;operation=1;write_reg(0,1);wait_on();if(enabled!=15)$fatal(1,"restart failed");
   operation=2;write_reg(0,0);wait_off();
  end
  // Common reset may interrupt the mailbox and bus transaction; both domains recover.
  operation=0;
  i2c_start();write_byte(8'h5a,1);master_low=1;bus_wait();scl=1;bus_wait();scl=0;bus_wait();
  arst_n=0;scl=1;master_low=0;repeat(5)@(negedge clk);arst_n=1;repeat(30)@(negedge clk);
  read_reg(6,byte_value);if(byte_value!=8'h50 || enabled!=0 || faults!=0)$fatal(1,"reset recovery");
  $display("PASS pmic scenario=%0d seed=%0d cycles=%0d I2C/config/sequence/CDC/snapshot/protection/reset",scenario,seed,cycle);
  $fclose(fd);$finish;
 end
endmodule
