/* 
Name: Gordon Zhao
File: sensor_reader.v
Description: instantiates NUM_SENSORS readers
*/

import config_pkg::*; 

module sensors_reader (
    input                           clk,
    input                           rst,
    input                           start,
    input logic [63:0]              timestamp,    
    output raw_frame_t              frame_out,
    output [NUM_SENSORS-1:0]        busy,
    output reg [NUM_SENSORS-1:0]    done,
    output reg [NUM_SENSORS-1:0]    error,

    `ifdef DEBUG         
    output states [NUM_SENSORS-1:0],
    `endif 
    
    I2C_bus.master i2c_bus [NUM_SENSORS]
);

// instantiate individual readers
genvar i;
generate
    for (i = 0; i < NUM_SENSORS; i++) begin : gen_sensor_reader

        I2C_reader I2C_reader_inst (
            .clk        (clk),
            .rst        (rst),
            .start      (start),
            .timestamp  (timestamp),
            .packet_out (frame_out[i]),
            .busy       (busy[i]),
            .done       (done[i]),
            .ack_error  (error[i]),

            `ifdef DEBUG         
            .stateOut,  (states[i]),
            `endif

            .i2c (i2c_bus[i])
        );
    end
endgenerate

endmodule