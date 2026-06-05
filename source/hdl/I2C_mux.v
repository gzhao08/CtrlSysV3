`timescale 1ns/1ps

module I2C_mux (
    input wire useAXI,

    // AXI IIC side
    output reg  sda_i_AXI,
    input  wire sda_o_AXI,
    input  wire sda_t_AXI,

    output reg  scl_i_AXI,
    input  wire scl_o_AXI,
    input  wire scl_t_AXI,

    // Custom reader side
    output reg  read_sda_i,
    input  wire read_sda_o,
    input  wire read_sda_t,

    output reg  read_scl_i,
    input  wire read_scl_o,
    input  wire read_scl_t,

    // Physical bus side
    input  wire out_sda_i,
    output reg  out_sda_o,
    output reg  out_sda_t,

    input  wire out_scl_i,
    output reg  out_scl_o,
    output reg  out_scl_t
);

always @(*) begin
    // Everyone sees the physical bus input
    sda_i_AXI  = out_sda_i;
    scl_i_AXI  = out_scl_i;

    read_sda_i = out_sda_i;
    read_scl_i = out_scl_i;

    if (useAXI) begin
        out_sda_o = sda_o_AXI;
        out_sda_t = sda_t_AXI;

        out_scl_o = scl_o_AXI;
        out_scl_t = scl_t_AXI;
    end else begin
        out_sda_o = read_sda_o;
        out_sda_t = read_sda_t;

        out_scl_o = read_scl_o;
        out_scl_t = read_scl_t;
    end
end

endmodule