`timescale 1ns/1ps

import config_pkg::*;

module top_tb;

    logic clk;
    logic rst;

    // tri1 means weak pull-up by default
    tri1 [NUM_SENSORS-1:0] sda;
    tri1 [NUM_SENSORS-1:0] scl;

    // Instantiate DUT
    top dut (
        .clk(clk),
        .rst(rst),
        .sda(sda),
        .scl(scl)
    );

    // 50 MHz clock: 20 ns period
    initial clk = 1'b0;
    always #10 clk = ~clk;

    // Reset sequence
    initial begin
        rst = 1'b1;
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
        $dumpvars(0, top_tb.dut.startRead);
        $dumpvars(0, top_tb.dut.rst_sync);
        $dumpvars(0, top_tb.dut.timestamp);
    end

endmodule