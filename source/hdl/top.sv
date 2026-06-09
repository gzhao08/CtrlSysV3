import config_pkg::*;
`include "config_def.svh"

module top(
    input logic clk,
    input logic rst,
    I2C_bus.master i2c_bus [NUM_SENSORS]
);

// 
logic [63:0] timestamp;
logic startRead;
raw_frame_t frame;

stopwatch_64 u_stopwatch_64 (
    .clk(clk),
    .rst(rst),
    .timestamp_counter(timestamp)
);

acquisition_controller u_acquisition_controller (
    .clk(clk),
	.rst(rst),
	.enable(~rst),        
	.timestamp(timestamp),
	.sample_period(500000),  
	.startRead(startRead) 
);

sensors_reader u_sensors_reader (
    .clk(clk),
    .rst(rst),
    .start(startRead),
    .timestamp(timestamp),    
    .frame_out(frame),
    // .busy(),
    // .done(),
    // .error(),

    // `ifdef DEBUG         
    // .states(),
    // `endif 
    
    .i2c_bus(i2c_bus)
);

endmodule;