/* 
Name: Gordon Zhao
File: sensor_reader.sv
Description: instantiates NUM_SENSORS readers
*/

import config_pkg::*;
`include "config_def.svh"

module sensors_reader (
    input                               clk,
    input                               rst,
    input                               start,
    input logic [63:0]                  timestamp,    
    output raw_frame_t                  frame_out,
    output [NUM_SENSORS-1:0]            busy,
    output logic [NUM_SENSORS-1:0]      done,
    output logic [NUM_SENSORS-1:0]      error,

    // `ifdef DEBUG         
    output logic [3:0] states [NUM_SENSORS-1:0],
    // `endif 
    
    I2C_bus.master i2c_bus [NUM_SENSORS]
);

// instantiate individual readers
genvar i;
generate
    for (i = 0; i < NUM_SENSORS; i++) begin : gen_sensor_reader
        localparam logic [PROTOCOL_WIDTH-1:0] SENSOR_PROTOCOL = SENSOR_PROTOCOLS[i*PROTOCOL_WIDTH +: PROTOCOL_WIDTH];
        localparam logic [6:0] SENSOR_ADDR = SENSOR_ADDRS[i*7 +: 7];
        localparam logic [7:0] SENSOR_REG_ADDR = SENSOR_REG_ADDRS[i*8 +: 8];
        localparam logic [7:0] SENSOR_NUM_BYTE = SENSOR_NUM_BYTES[i*8 +: 8];

        if (SENSOR_PROTOCOL == PROTOCOL_I2C) begin
            I2C_reader #(
                .SENSOR_ADDR(SENSOR_ADDR),
                .REG_ADDR(SENSOR_REG_ADDR),
                .DATA_BYTES(SENSOR_NUM_BYTE)
            ) I2C_reader_inst (
                .clk        (clk),
                .rst        (rst),
                .start      (start),
                .timestamp  (timestamp),
                .packet_out (frame_out[i]),
                .busy       (busy[i]),
                .done       (done[i]),
                .ack_error  (error[i]),

                // `ifdef DEBUG         
                .stateOut   (states[i]),
                // `endif

                .i2c (i2c_bus[i])
            );
        end
    end
endgenerate

endmodule
