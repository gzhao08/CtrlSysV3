/* 
Name: Gordon Zhao
File: sensor_mux.sv
Description: switches control of the sensors between custom readers and AXI blocks
*/

import config_pkg::*;
`include "config_def.svh"

module sensors_mux (
    input logic axi_enable,
    input logic [$clog2(NUM_SENSORS)-1:0] axi_sensor_sel,

    I2C_bus i2c_reader [NUM_SENSORS],
    I2C_bus axi_iic,

    I2C_bus i2c_out [NUM_SENSORS]
);

    always_comb begin
    
        for (int i = 0; i < NUM_SENSORS; i++) begin
            // Default: custom reader controls this sensor bus
            i2c_out[i].sda_o = i2c_reader[i].sda_o;
            i2c_out[i].sda_t = i2c_reader[i].sda_t;
            i2c_out[i].scl_o = i2c_reader[i].scl_o;
            i2c_out[i].scl_t = i2c_reader[i].scl_t;

            // Custom reader always sees its bus
            i2c_reader[i].sda_i = i2c_out[i].sda_i;
            i2c_reader[i].scl_i = i2c_out[i].scl_i;

            if (axi_enable && (axi_sensor_sel == i[$clog2(NUM_SENSORS)-1:0])) begin
                // AXI controls selected sensor bus
                i2c_out[i].sda_o = axi_iic.sda_o;
                i2c_out[i].sda_t = axi_iic.sda_t;
                i2c_out[i].scl_o = axi_iic.scl_o;
                i2c_out[i].scl_t = axi_iic.scl_t;

                // AXI reads back selected physical bus
                axi_iic.sda_i = i2c_out[i].sda_i;
                axi_iic.scl_i = i2c_out[i].scl_i;
            end
        end
        
    end

endmodule