`timescale 1ns/1ps

import config_pkg::*;

module top_tb;

    logic clk;
    logic rst;
    logic s_axi_lite_awvalid;
    logic s_axi_lite_awready;
    logic [9:0] s_axi_lite_awaddr;
    logic s_axi_lite_wvalid;
    logic s_axi_lite_wready;
    logic [31:0] s_axi_lite_wdata;
    logic [1:0] s_axi_lite_bresp;
    logic s_axi_lite_bvalid;
    logic s_axi_lite_bready;
    logic s_axi_lite_arvalid;
    logic s_axi_lite_arready;
    logic [9:0] s_axi_lite_araddr;
    logic s_axi_lite_rvalid;
    logic s_axi_lite_rready;
    logic [31:0] s_axi_lite_rdata;
    logic [1:0] s_axi_lite_rresp;
    logic [31:0] m_axi_s2mm_awaddr;
    logic [7:0] m_axi_s2mm_awlen;
    logic [2:0] m_axi_s2mm_awsize;
    logic [1:0] m_axi_s2mm_awburst;
    logic [2:0] m_axi_s2mm_awprot;
    logic [3:0] m_axi_s2mm_awcache;
    logic m_axi_s2mm_awvalid;
    logic m_axi_s2mm_awready;
    logic [31:0] m_axi_s2mm_wdata;
    logic [3:0] m_axi_s2mm_wstrb;
    logic m_axi_s2mm_wlast;
    logic m_axi_s2mm_wvalid;
    logic m_axi_s2mm_wready;
    logic [1:0] m_axi_s2mm_bresp;
    logic m_axi_s2mm_bvalid;
    logic m_axi_s2mm_bready;
    logic s2mm_prmry_reset_out_n;
    logic s2mm_introut;
    logic [31:0] axi_dma_tstvec;

    // tri1 means weak pull-up by default
    tri1 [NUM_SENSORS-1:0] sda;
    tri1 [NUM_SENSORS-1:0] scl;

    // Instantiate DUT
    top dut (
        .clk(clk),
        .rst(rst),
        .sda(sda),
        .scl(scl),
        .s_axi_lite_awvalid(s_axi_lite_awvalid),
        .s_axi_lite_awready(s_axi_lite_awready),
        .s_axi_lite_awaddr(s_axi_lite_awaddr),
        .s_axi_lite_wvalid(s_axi_lite_wvalid),
        .s_axi_lite_wready(s_axi_lite_wready),
        .s_axi_lite_wdata(s_axi_lite_wdata),
        .s_axi_lite_bresp(s_axi_lite_bresp),
        .s_axi_lite_bvalid(s_axi_lite_bvalid),
        .s_axi_lite_bready(s_axi_lite_bready),
        .s_axi_lite_arvalid(s_axi_lite_arvalid),
        .s_axi_lite_arready(s_axi_lite_arready),
        .s_axi_lite_araddr(s_axi_lite_araddr),
        .s_axi_lite_rvalid(s_axi_lite_rvalid),
        .s_axi_lite_rready(s_axi_lite_rready),
        .s_axi_lite_rdata(s_axi_lite_rdata),
        .s_axi_lite_rresp(s_axi_lite_rresp),
        .m_axi_s2mm_awaddr(m_axi_s2mm_awaddr),
        .m_axi_s2mm_awlen(m_axi_s2mm_awlen),
        .m_axi_s2mm_awsize(m_axi_s2mm_awsize),
        .m_axi_s2mm_awburst(m_axi_s2mm_awburst),
        .m_axi_s2mm_awprot(m_axi_s2mm_awprot),
        .m_axi_s2mm_awcache(m_axi_s2mm_awcache),
        .m_axi_s2mm_awvalid(m_axi_s2mm_awvalid),
        .m_axi_s2mm_awready(m_axi_s2mm_awready),
        .m_axi_s2mm_wdata(m_axi_s2mm_wdata),
        .m_axi_s2mm_wstrb(m_axi_s2mm_wstrb),
        .m_axi_s2mm_wlast(m_axi_s2mm_wlast),
        .m_axi_s2mm_wvalid(m_axi_s2mm_wvalid),
        .m_axi_s2mm_wready(m_axi_s2mm_wready),
        .m_axi_s2mm_bresp(m_axi_s2mm_bresp),
        .m_axi_s2mm_bvalid(m_axi_s2mm_bvalid),
        .m_axi_s2mm_bready(m_axi_s2mm_bready),
        .s2mm_prmry_reset_out_n(s2mm_prmry_reset_out_n),
        .s2mm_introut(s2mm_introut),
        .axi_dma_tstvec(axi_dma_tstvec)
    );

    // 50 MHz clock: 20 ns period
    initial clk = 1'b0;
    always #10 clk = ~clk;

    // Reset sequence
    initial begin
        rst = 1'b1;
        s_axi_lite_awvalid = 1'b0;
        s_axi_lite_awaddr = 10'b0;
        s_axi_lite_wvalid = 1'b0;
        s_axi_lite_wdata = 32'b0;
        s_axi_lite_bready = 1'b1;
        s_axi_lite_arvalid = 1'b0;
        s_axi_lite_araddr = 10'b0;
        s_axi_lite_rready = 1'b1;
        m_axi_s2mm_awready = 1'b1;
        m_axi_s2mm_wready = 1'b1;
        m_axi_s2mm_bresp = 2'b00;
        m_axi_s2mm_bvalid = 1'b0;
        #100;
        rst = 1'b0;

        // Let simulation run
        #2_000_000;

        $finish;
    end

    // Optional waveform dump for Icarus/GTKWave
    initial begin
        $dumpfile("top_tb.vcd");
        $dumpvars(0, top_tb);

         // Helpful internal signals
        $dumpvars(0, top_tb.dut.u_ctrlsys_core.startRead);
        $dumpvars(0, top_tb.dut.u_ctrlsys_core.sensor_start);
        $dumpvars(0, top_tb.dut.u_ctrlsys_core.frame_wr_en);
        $dumpvars(0, top_tb.dut.u_ctrlsys_core.frame_empty);
        $dumpvars(0, top_tb.dut.u_ctrlsys_core.frame_full);
        $dumpvars(0, top_tb.dut.u_ctrlsys_core.rst_sync);
        $dumpvars(0, top_tb.dut.u_ctrlsys_core.timestamp);
        $dumpvars(0, top_tb.dut.axis_tvalid);
        $dumpvars(0, top_tb.dut.axis_tdata);
        $dumpvars(0, top_tb.dut.axis_tlast);
        $dumpvars(0, top_tb.s2mm_introut);
    end

endmodule
