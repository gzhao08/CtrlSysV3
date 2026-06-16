/* 
Name: Gordon Zhao
File: sensor_reader.sv
Description: instantiates NUM_SENSORS readers
*/

import config_pkg::*;
`include "config_def.svh"

module sensors_reader #(
    parameter integer NUM_SENSORS = 3,
    parameter integer PROTOCOL_WIDTH = 2,
    parameter logic [PROTOCOL_WIDTH*NUM_SENSORS-1:0] SENSOR_PROTOCOLS = 6'b000000,
    parameter logic [7*NUM_SENSORS-1:0] SENSOR_ADDRS = {7'd127, 7'd127, 7'd0},
    parameter logic [8*NUM_SENSORS-1:0] SENSOR_REG_ADDRS = {8'd41, 8'd41, 8'd5},
    parameter logic [8*NUM_SENSORS-1:0] SENSOR_NUM_BYTES = {8'd18, 8'd18, 8'd18}
)(
    input                               clk,
    input                               rst,
    input                               start,
    input logic [NUM_SENSORS-1:0]       sensor_enable_mask,
    input logic [63:0]                  timestamp,    
    output raw_packet_t                 frame_out [NUM_SENSORS],
    output [NUM_SENSORS-1:0]            busy,
    output logic [NUM_SENSORS-1:0]      done,
    output logic [NUM_SENSORS-1:0]      error,

    // `ifdef DEBUG         
    output logic [3:0] states [NUM_SENSORS-1:0],
    // `endif 

    input  logic [NUM_SENSORS-1:0] i2c_sda_i,
    output logic [NUM_SENSORS-1:0] i2c_sda_o,
    output logic [NUM_SENSORS-1:0] i2c_sda_t,
    input  logic [NUM_SENSORS-1:0] i2c_scl_i,
    output logic [NUM_SENSORS-1:0] i2c_scl_o,
    output logic [NUM_SENSORS-1:0] i2c_scl_t
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
                .start      (start && sensor_enable_mask[i]),
                .timestamp  (timestamp),
                .packet_out (frame_out[i]),
                .busy       (busy[i]),
                .done       (done[i]),
                .ack_error  (error[i]),

                // `ifdef DEBUG         
                .stateOut   (states[i]),
                // `endif

                .i2c_sda_i  (i2c_sda_i[i]),
                .i2c_sda_o  (i2c_sda_o[i]),
                .i2c_sda_t  (i2c_sda_t[i]),
                .i2c_scl_i  (i2c_scl_i[i]),
                .i2c_scl_o  (i2c_scl_o[i]),
                .i2c_scl_t  (i2c_scl_t[i])
            );
        end
    end
endgenerate

endmodule
