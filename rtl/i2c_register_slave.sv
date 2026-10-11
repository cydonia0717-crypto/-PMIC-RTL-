`timescale 1ns/1ps
// Oversampled 7-bit slave: address pointer, auto-increment, repeated START reads.
// Open-drain SDA output; no clock stretching (register data has zero wait states).
module i2c_register_slave #(parameter [6:0] ADDRESS=7'h2d)(
 input wire clk,rst,scl_in,sda_in,output reg sda_low,
 output reg wr_valid,output reg [7:0] wr_addr,wr_data,
 output wire [7:0] rd_addr,input wire [7:0] rd_data,output reg read_start,
 output wire busy
);
 (* ASYNC_REG="TRUE" *) reg [1:0] scl_sync,sda_sync;
 reg [2:0] scl_filter,sda_filter;
 reg scl,sda,scl_prev,sda_prev;
 wire rise=scl && !scl_prev,fall=!scl && scl_prev;
 wire start_event=scl && sda_prev && !sda;
 wire stop_event=scl && !sda_prev && sda;
 localparam IDLE=0,ADDRESS_RX=1,POINTER_RX=2,DATA_RX=3,ACK_FALL=4,ACK_RISE=5,
            ACK_END=6,TRANSMIT=7,TX_RELEASE=8,MASTER_ACK=9,MASTER_ACK_END=10,IGNORE=11;
 reg [3:0] state,after_ack;
 reg [2:0] bit_index;
 reg [6:0] shift;
 reg [7:0] tx_byte,pointer;
 reg ack_value,continue_read;
 wire [7:0] received={shift[6:0],sda};
 assign rd_addr=pointer;
 assign busy=state!=IDLE;
 always @(posedge clk) begin
  if(rst) begin
   scl_sync<=3;sda_sync<=3;scl_filter<=7;sda_filter<=7;
   scl<=1;sda<=1;scl_prev<=1;sda_prev<=1;
  end else begin
   scl_sync<={scl_sync[0],scl_in};sda_sync<={sda_sync[0],sda_in};
   scl_filter<={scl_filter[1:0],scl_sync[1]};sda_filter<={sda_filter[1:0],sda_sync[1]};
   if(&scl_filter) scl<=1;else if(~|scl_filter) scl<=0;
   if(&sda_filter) sda<=1;else if(~|sda_filter) sda<=0;
   scl_prev<=scl;sda_prev<=sda;
  end
 end
 always @(posedge clk) begin
  if(rst) begin
   state<=IDLE;after_ack<=IDLE;bit_index<=7;shift<=0;tx_byte<=0;pointer<=0;
   ack_value<=0;continue_read<=0;sda_low<=0;wr_valid<=0;wr_addr<=0;wr_data<=0;read_start<=0;
  end else begin
   wr_valid<=0;read_start<=0;
   if(start_event) begin state<=ADDRESS_RX;bit_index<=7;shift<=0;sda_low<=0;end
   else if(stop_event) begin state<=IDLE;sda_low<=0;end
   else case(state)
    ADDRESS_RX,POINTER_RX,DATA_RX: if(rise) begin
     shift<=received[6:0];
     if(bit_index!=0) bit_index<=bit_index-1'b1;
     else begin
      state<=ACK_FALL;ack_value<=1;bit_index<=7;
      if(state==ADDRESS_RX) begin
       if(received[7:1]==ADDRESS) begin
        after_ack<=received[0] ? TRANSMIT : POINTER_RX;
        if(received[0]) read_start<=1;
       end else begin after_ack<=IGNORE;ack_value<=0;end
      end else if(state==POINTER_RX) begin pointer<=received;after_ack<=DATA_RX;end
      else begin wr_valid<=1;wr_addr<=pointer;wr_data<=received;pointer<=pointer+1'b1;after_ack<=DATA_RX;end
     end
    end
    ACK_FALL: if(fall) begin sda_low<=ack_value;state<=ACK_RISE;end
    ACK_RISE: if(rise) state<=ACK_END;
    ACK_END: if(fall) begin
     state<=after_ack;sda_low<=0;shift<=0;bit_index<=7;
     if(after_ack==TRANSMIT) begin tx_byte<=rd_data;sda_low<=!rd_data[7];end
    end
    TRANSMIT: begin
     if(rise) begin
      if(bit_index==0) state<=TX_RELEASE;else bit_index<=bit_index-1'b1;
     end
     if(fall) sda_low<=!tx_byte[bit_index];
    end
    TX_RELEASE: if(fall) begin sda_low<=0;state<=MASTER_ACK;end
    MASTER_ACK: if(rise) begin
     continue_read<=!sda;state<=MASTER_ACK_END;
     if(!sda) pointer<=pointer+1'b1;
    end
    MASTER_ACK_END: if(fall) begin
     if(continue_read) begin state<=TRANSMIT;bit_index<=7;tx_byte<=rd_data;sda_low<=!rd_data[7];end
     else begin state<=IGNORE;sda_low<=0;end
    end
    default: begin end
   endcase
  end
 end
endmodule
