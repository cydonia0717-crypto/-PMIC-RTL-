`timescale 1ns/1ps
// Byte-wide I2C register bank. Four 32-byte rail records, shadow -> atomic active.
module pmic_registers #(parameter PWM_PERIOD=1024)(
 input wire clk,rst,wr_valid,input wire [7:0] wr_addr,wr_data,rd_addr,
 output reg [7:0] rd_data,input wire read_start,
 input wire [2:0] seq_state,input wire seq_ready,input wire [3:0] enabled,faults,
 input wire [23:0] causes,input wire [95:0] telemetry,
 output reg run,output reg [3:0] rail_mask,irq_mask,clear_fault,
 output reg [1023:0] active_cfg,output reg config_error
);
 reg [7:0] shadow[0:127];
 reg [95:0] snapshot_adc;
 reg [23:0] snapshot_causes;
 reg [3:0] snapshot_enabled,snapshot_faults;
 reg [2:0] snapshot_state;
 reg snapshot_ready;
 reg valid_config;
 integer r;
 function automatic [7:0] default_byte(input integer index);
  integer offset;
  reg [15:0] word_value;
  begin
   offset=index%32;word_value=0;
   case(offset/2)
    0: word_value=2048; // target
    1: word_value=64;   // KP Q8.8
    2: word_value=2;    // KI Q8.8
    3: word_value=0;    // KD
    4: word_value=0;    // minimum duty
    5: word_value=16'(PWM_PERIOD-8);
    6: word_value=16'h0204; // deadtime=4, startup delay=2
    7: word_value=1600; // UV
    8: word_value=2500; // OV
    9: word_value=3000; // OC
    10: word_value=256; // startup timeout in sequencer ticks
    11: word_value=16'h4000; // mode=PI, soft-start step=64 ADC counts/sample
    12: word_value=128; // power-good tolerance
    default: word_value=0;
   endcase
   default_byte=offset%2==0 ? word_value[7:0] : word_value[15:8];
  end
 endfunction
 function automatic [15:0] sh_word(input integer rail,input integer offset);
  sh_word={shadow[rail*32+offset+1],shadow[rail*32+offset]};
 endfunction
 wire commit=wr_valid && wr_addr==8'h0c && wr_data[0];
 always @* begin
  valid_config=1;
  for(r=0;r<4;r=r+1) begin
   if(sh_word(r,0)>4095 || sh_word(r,14)>=sh_word(r,0) || sh_word(r,16)<=sh_word(r,0) ||
      sh_word(r,16)>4095 || sh_word(r,18)>4095 ||
      sh_word(r,8)>sh_word(r,10) || sh_word(r,10)>PWM_PERIOD ||
      {8'd0,shadow[r*32+12]}>=sh_word(r,10) ||
      sh_word(r,20)<3 || sh_word(r,24)==0 || sh_word(r,24)>4095 ||
      shadow[r*32+3][7] || shadow[r*32+5][7] || shadow[r*32+7][7] ||
      |shadow[r*32+22][7:1]) valid_config=0;
  end
 end
 genvar b;
 generate for(b=0;b<128;b=b+1) begin: g_cfg
  always @(posedge clk) begin
   if(rst) shadow[b]<=default_byte(b);
   else if(wr_valid && wr_addr==8'(64+b)) shadow[b]<=wr_data;
   if(rst) active_cfg[b*8+:8]<=default_byte(b);
   else if(commit && !run && seq_state==0 && valid_config) active_cfg[b*8+:8]<=shadow[b];
  end
 end endgenerate
 always @(posedge clk) begin
  if(rst) begin run<=0;rail_mask<=15;irq_mask<=15;clear_fault<=0;config_error<=0;
   snapshot_adc<=0;snapshot_causes<=0;snapshot_enabled<=0;snapshot_faults<=0;snapshot_state<=0;snapshot_ready<=0;
  end else begin
   clear_fault<=0;
   if(wr_valid) case(wr_addr)
    8'h00: run<=wr_data[0];
    8'h01: if(!run && seq_state==0) rail_mask<=wr_data[3:0];else config_error<=1;
    8'h04: if(!run) clear_fault<=wr_data[3:0];
    8'h05: irq_mask<=wr_data[3:0];
    8'h0c: if(wr_data[0]) config_error<=run || seq_state!=0 || !valid_config;
    default: begin end
   endcase
   if(read_start) begin
    snapshot_adc<=telemetry;snapshot_causes<=causes;snapshot_enabled<=enabled;
    snapshot_faults<=faults;snapshot_state<=seq_state;snapshot_ready<=seq_ready;
   end
  end
 end
 integer idx,channel,byte_lane;
 always @* begin
  rd_data=0;idx=0;channel=0;byte_lane=0;
  case(rd_addr)
   8'h00: rd_data={7'd0,run};
   8'h01: rd_data={4'd0,rail_mask};
   8'h02: rd_data={config_error,2'd0,snapshot_ready,1'd0,snapshot_state};
   8'h03: rd_data={4'd0,snapshot_faults};
   8'h05: rd_data={4'd0,irq_mask};
   8'h06: rd_data=8'h50;
   8'h07: rd_data=8'h01;
   8'h14: rd_data={4'd0,snapshot_enabled};
   default: begin
    if(rd_addr>=8'h10 && rd_addr<=8'h13) rd_data={2'd0,snapshot_causes[(rd_addr-8'h10)*6+:6]};
    else if(rd_addr>=8'h18 && rd_addr<=8'h27) begin
     idx={24'd0,rd_addr}-32'd24;channel=idx/4;byte_lane=idx%4;
     case(byte_lane)
      0: rd_data=snapshot_adc[channel*24+:8];
      1: rd_data={4'd0,snapshot_adc[channel*24+8+:4]};
      2: rd_data=snapshot_adc[channel*24+12+:8];
      3: rd_data={4'd0,snapshot_adc[channel*24+20+:4]};
     endcase
    end else if(rd_addr>=8'h40 && rd_addr<8'hc0) rd_data=shadow[7'(rd_addr-8'h40)];
   end
  endcase
 end
endmodule
