/* 
Name: Gordon Zhao
File: sensor_mux.sv
Description: switches control of the sensors between custom readers and AXI blocks
*/

import config_pkg::*;
`include "config_def.svh"

module sensors_mux #(
    parameter integer NUM_SENSORS = 3
)(
    input logic axi_enable,
    input logic [(NUM_SENSORS > 1 ? $clog2(NUM_SENSORS) : 1)-1:0] axi_sensor_sel,

    output logic [NUM_SENSORS-1:0] i2c_reader_sda_i,
    input  logic [NUM_SENSORS-1:0] i2c_reader_sda_o,
    input  logic [NUM_SENSORS-1:0] i2c_reader_sda_t,
    output logic [NUM_SENSORS-1:0] i2c_reader_scl_i,
    input  logic [NUM_SENSORS-1:0] i2c_reader_scl_o,
    input  logic [NUM_SENSORS-1:0] i2c_reader_scl_t,

    output logic                   axi_iic_sda_i,
    input  logic                   axi_iic_sda_o,
    input  logic                   axi_iic_sda_t,
    output logic                   axi_iic_scl_i,
    input  logic                   axi_iic_scl_o,
    input  logic                   axi_iic_scl_t,

    input  logic [NUM_SENSORS-1:0] i2c_out_sda_i,
    output logic [NUM_SENSORS-1:0] i2c_out_sda_o,
    output logic [NUM_SENSORS-1:0] i2c_out_sda_t,
    input  logic [NUM_SENSORS-1:0] i2c_out_scl_i,
    output logic [NUM_SENSORS-1:0] i2c_out_scl_o,
    output logic [NUM_SENSORS-1:0] i2c_out_scl_t
);

    logic [NUM_SENSORS-1:0] sensor_sda_i;
    logic [NUM_SENSORS-1:0] sensor_scl_i;
    genvar i;
    integer sensor_index;

    generate
        for (i = 0; i < NUM_SENSORS; i++) begin : gen_sensor_mux
            wire sensor_selected;

            assign sensor_selected = axi_enable && (axi_sensor_sel == i);

            assign sensor_sda_i[i] = i2c_out_sda_i[i];
            assign sensor_scl_i[i] = i2c_out_scl_i[i];

            assign i2c_reader_sda_i[i] = i2c_out_sda_i[i];
            assign i2c_reader_scl_i[i] = i2c_out_scl_i[i];

            assign i2c_out_sda_o[i] = sensor_selected ? axi_iic_sda_o : i2c_reader_sda_o[i];
            assign i2c_out_sda_t[i] = sensor_selected ? axi_iic_sda_t : i2c_reader_sda_t[i];
            assign i2c_out_scl_o[i] = sensor_selected ? axi_iic_scl_o : i2c_reader_scl_o[i];
            assign i2c_out_scl_t[i] = sensor_selected ? axi_iic_scl_t : i2c_reader_scl_t[i];
        end
    endgenerate

    always_comb begin
        axi_iic_sda_i = 1'b1;
        axi_iic_scl_i = 1'b1;

        for (sensor_index = 0; sensor_index < NUM_SENSORS; sensor_index = sensor_index + 1) begin
            if (axi_enable && (axi_sensor_sel == sensor_index)) begin
                axi_iic_sda_i = sensor_sda_i[sensor_index];
                axi_iic_scl_i = sensor_scl_i[sensor_index];
            end
        end
    end

endmodule
