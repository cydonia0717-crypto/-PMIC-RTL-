// Open-drain master. Timings exceed the oversampling filter's settling time.
 task bus_wait;
  integer extra;
  begin extra=int'(rng[2:0]);repeat(bit_ticks+extra)@(negedge clk);end
 endtask
 task i2c_start;
  begin scl=0;master_low=0;bus_wait();scl=1;bus_wait();master_low=1;bus_wait();scl=0;bus_wait();end
 endtask
 task i2c_stop;
  begin scl=0;master_low=1;bus_wait();scl=1;bus_wait();master_low=0;bus_wait();end
 endtask
 task write_byte;
  input [7:0] value;input expected_ack;
  integer bitn;reg ack;
  begin
   for(bitn=7;bitn>=0;bitn=bitn-1)begin
    master_low=!value[bitn];bus_wait();scl=1;bus_wait();scl=0;bus_wait();
   end
   master_low=0;bus_wait();scl=1;bus_wait();ack=!sda;
   if(ack!==expected_ack)$fatal(1,"I2C ACK byte=%x got=%b expected=%b state=%d",value,ack,expected_ack,dut.u_i2c.state);
   scl=0;bus_wait();
  end
 endtask
 task read_byte;
  output [7:0] value;input ack;
  integer bitn;
  begin
   master_low=0;
   for(bitn=7;bitn>=0;bitn=bitn-1)begin
    bus_wait();scl=1;bus_wait();value[bitn]=sda;scl=0;bus_wait();
   end
   master_low=ack;bus_wait();scl=1;bus_wait();scl=0;bus_wait();master_low=0;
  end
 endtask
 task write_reg;
  input [7:0] address,value;
  begin i2c_start();write_byte(8'h5a,1);write_byte(address,1);write_byte(value,1);i2c_stop();end
 endtask
 task write_word;
  input [7:0] address;input [15:0] value;
  begin i2c_start();write_byte(8'h5a,1);write_byte(address,1);write_byte(value[7:0],1);write_byte(value[15:8],1);i2c_stop();end
 endtask
 task set_read_pointer;
  input [7:0] address;
  begin i2c_start();write_byte(8'h5a,1);write_byte(address,1);i2c_start();write_byte(8'h5b,1);end
 endtask
 task read_reg;
  input [7:0] address;output [7:0] value;
  begin set_read_pointer(address);read_byte(value,0);i2c_stop();end
 endtask
