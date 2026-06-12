`timescale 1ns/1ps

module ctrlsys_core_wrapper #(
    parameter integer NUM_SENSORS = 3
)(
    input  wire        clk,
    input  wire        rst,

    inout  wire [NUM_SENSORS-1:0] sda,
    inout  wire [NUM_SENSORS-1:0] scl,

    output wire        m_axis_tvalid,
    input  wire        m_axis_tready,
    output wire [31:0] m_axis_tdata,
    output wire [3:0]  m_axis_tkeep,
    output wire        m_axis_tlast
);

ctrlsys_core u_ctrlsys_core (
    .clk(clk),
    .rst(rst),
    .sda(sda),
    .scl(scl),
    .m_axis_tvalid(m_axis_tvalid),
    .m_axis_tready(m_axis_tready),
    .m_axis_tdata(m_axis_tdata),
    .m_axis_tkeep(m_axis_tkeep),
    .m_axis_tlast(m_axis_tlast)
);

endmodule
