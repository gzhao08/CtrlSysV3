import config_pkg::*;
`include "config_def.svh"

module top(
    input logic clk,
    input logic rst,

    inout wire [NUM_SENSORS-1:0] sda,
    inout wire [NUM_SENSORS-1:0] scl
);

// 
logic [63:0] timestamp;
logic startRead;
raw_frame_t frame;
I2C_bus i2c_bus [NUM_SENSORS] ();

// double flop external rst
logic rst_meta;
logic rst_sync;
always_ff @(posedge clk) begin
    rst_meta <= rst;
    rst_sync <= rst_meta;
end

stopwatch_64 u_stopwatch_64 (
    .clk(clk),
    .rst(rst_sync),
    .timestamp_counter(timestamp)
);

acquisition_controller u_acquisition_controller (
    .clk(clk),
	.rst(rst_sync),
	.enable(~rst_sync),        
	.timestamp(timestamp),
	.sample_period(5000),  
	.startRead(startRead) 
);

sensors_reader u_sensors_reader (
    .clk(clk),
    .rst(rst_sync),
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

// instantiate iobuffers
genvar i;
generate
    for (i = 0; i < NUM_SENSORS; i++) begin : gen_iobuf

        IOBUF IOBUF_scl_inst (
            .O(i2c_bus[i].scl_i),      // Buffer output (internal read path)
            .IO(scl[i]),   // Buffer inout port (connect to top-level port)
            .I(1'b0),      // Buffer input (internal write path)
            .T(i2c_bus[i].scl_t)     // 3-state enable: High=input, Low=output
        );

        IOBUF IOBUF_sda_inst (
            .O(i2c_bus[i].sda_i),      // Buffer output (internal read path)
            .IO(sda[i]),   // Buffer inout port (connect to top-level port)
            .I(1'b0),      // Buffer input (internal write path)
            .T(i2c_bus[i].sda_t)     // 3-state enable: High=input, Low=output
        );

        // assign scl[i] = i2c_bus[i].scl_t ? 1'bz : 1'b0;
        // assign sda[i] = i2c_bus[i].sda_t ? 1'bz : 1'b0;

        // assign i2c_bus[i].scl_i = scl[i];
        // assign i2c_bus[i].sda_i = sda[i];
    end
endgenerate

endmodule;