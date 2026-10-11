`timescale 1ns/1ps
module pmic_top #(parameter PWM_PERIOD=1024,SEQ_DIV=50000,STALE_CYCLES=100000)(
 input wire clk,adc_clk,arst_n,
 input wire i2c_scl,i2c_sda,output wire i2c_sda_low,
 input wire adc_valid,input wire [95:0] adc_data,output wire adc_ready,
 input wire [3:0] external_trip,
 output wire [3:0] power_enable,pwm_high,pwm_low,faults,
 output wire irq,ready,output wire [2:0] sequence_state,
 output wire [63:0] duties,output wire [95:0] sampled_adc
);
 wire rst,adc_rst;
 reset_sync u_reset(clk,arst_n,rst);
 reset_sync u_adc_reset(adc_clk,arst_n,adc_rst);
 wire wr_valid,read_start,unused_i2c_busy;
 wire [7:0] wr_addr,wr_data,rd_addr,rd_data;
 i2c_register_slave u_i2c(clk,rst,i2c_scl,i2c_sda,i2c_sda_low,wr_valid,wr_addr,wr_data,rd_addr,rd_data,read_start,unused_i2c_busy);
 wire run,config_error;
 wire [3:0] rail_mask,irq_mask,clear_fault,qualified,timeout_faults,protection_faults;
 wire [1023:0] cfg;
 wire [23:0] causes;
 pmic_registers #(.PWM_PERIOD(PWM_PERIOD)) u_registers(
  clk,rst,wr_valid,wr_addr,wr_data,rd_addr,rd_data,read_start,sequence_state,ready,power_enable,faults,
  causes,sampled_adc,run,rail_mask,irq_mask,clear_fault,cfg,config_error);
 wire [3:0] pid_ready;
 wire sample_valid;
 adc_mailbox u_adc(adc_clk,adc_rst,adc_valid,adc_ready,adc_data,clk,rst,&pid_ready,sample_valid,sampled_adc);
 reg [31:0] divider;
 wire tick=divider==SEQ_DIV-1;
 always @(posedge clk) if(rst) divider<=0;else if(tick) divider<=0;else divider<=divider+1'b1;
 (* ASYNC_REG="TRUE" *) reg [3:0] trip_meta,trip_sync;
 always @(posedge clk) if(rst) begin trip_meta<=0;trip_sync<=0;end else begin trip_meta<=external_trip;trip_sync<=trip_meta;end
 wire [3:0] good;
 wire [31:0] delays;
 wire [63:0] timeouts;
 assign faults=protection_faults | timeout_faults;
 assign irq=|(faults & irq_mask) || config_error;
 rail_sequencer u_sequence(clk,rst,tick,run,clear_fault,rail_mask,good,protection_faults,delays,timeouts,
                           power_enable,qualified,timeout_faults,sequence_state,ready);
 genvar r;
 generate for(r=0;r<4;r=r+1) begin: g_rail
  wire [255:0] unused_c=cfg[r*256+:256];
  wire [11:0] target=unused_c[0+:12],uv=unused_c[112+:12],ov=unused_c[128+:12],oc=unused_c[144+:12];
  wire [11:0] tolerance=unused_c[192+:12];
  wire [11:0] voltage=sampled_adc[r*24+:12],current=sampled_adc[r*24+12+:12];
  reg [11:0] soft_target;
  wire [12:0] ramp_sum={1'b0,soft_target}+{5'd0,unused_c[184+:8]};
  always @(posedge clk) begin
   if(rst || !power_enable[r]) soft_target<=0;
   else if(sample_valid) begin
    if(unused_c[184+:8]==0 || ramp_sum>={1'b0,target}) soft_target<=target;else soft_target<=ramp_sum[11:0];
   end
  end
  wire [11:0] target_for_sample=unused_c[184+:8]==0 ? target : soft_target;
  wire [12:0] upper={1'b0,target}+{1'b0,tolerance};
  wire [12:0] lower={1'b0,target}>{1'b0,tolerance} ? {1'b0,target}-{1'b0,tolerance} : 13'd0;
  assign good[r]={1'b0,voltage}>=lower && {1'b0,voltage}<=upper;
  assign delays[r*8+:8]=unused_c[104+:8];assign timeouts[r*16+:16]=unused_c[160+:16];
  wire unused_pid_done,unused_frame;
  wire signed [31:0] unused_integral;
  wire signed [12:0] unused_error;
  wire [15:0] unused_phase,unused_active_duty;
  wire [7:0] unused_active_deadtime;
  fixed_pid u_pid(clk,rst,power_enable[r] && !faults[r],sample_valid,target_for_sample,voltage,
   $signed(unused_c[16+:16]),$signed(unused_c[32+:16]),$signed(unused_c[48+:16]),unused_c[176],unused_c[64+:16],unused_c[80+:16],
   pid_ready[r],unused_pid_done,duties[r*16+:16],unused_integral,unused_error);
  pwm_deadtime #(.PERIOD(PWM_PERIOD)) u_pwm(clk,rst,power_enable[r],(|faults || |(trip_sync & power_enable)),
   duties[r*16+:16],unused_c[96+:8],pwm_high[r],pwm_low[r],unused_frame,unused_phase,unused_active_duty,unused_active_deadtime);
  wire [5:0] rail_causes;
  rail_protection #(.STALE_CYCLES(STALE_CYCLES)) u_protection(clk,rst,power_enable[r],qualified[r],
   sample_valid,clear_fault[r],trip_sync[r],voltage,current,uv,ov,oc,rail_causes,protection_faults[r]);
  assign causes[r*6+:6]=rail_causes | (timeout_faults[r] ? 6'b001000 : 6'd0);
 end endgenerate
endmodule
