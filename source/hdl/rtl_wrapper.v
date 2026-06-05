/*
Name: Gordon Zhao
File: rtl_wrapper.v
Description:
    Top-level RTL wrapper for the acquisition system.

    This wrapper instantiates:
      - axi_lite_regs
      - timekeep
      - acquisition_controller
      - I2C_controller
      - I2C_mux
      - packetizer

    Notes:
      1. The top-level pins are normal flattened Verilog-style pins, so this
         wrapper is convenient to connect from a Vivado block design.
      2. The design still uses SystemVerilog interfaces internally because
         I2C_controller and I2C_mux use I2C_bus ports.
      3. Compile this file as SystemVerilog if your tool does not allow
         interface instantiation from a .v file.
*/

`timescale 1ns/1ps

module rtl_wrapper (
    // ------------------------------------------------------------
    // Clock / reset
    // ------------------------------------------------------------
    input  wire        S_AXI_ACLK,
    input  wire        S_AXI_ARESETN,

    // ------------------------------------------------------------
    // AXI-Lite slave interface
    // ------------------------------------------------------------
    input  wire [31:0] S_AXI_AWADDR,
    input  wire        S_AXI_AWVALID,
    output wire        S_AXI_AWREADY,

    input  wire [31:0] S_AXI_WDATA,
    input  wire [3:0]  S_AXI_WSTRB,
    input  wire        S_AXI_WVALID,
    output wire        S_AXI_WREADY,

    output wire [1:0]  S_AXI_BRESP,
    output wire        S_AXI_BVALID,
    input  wire        S_AXI_BREADY,

    input  wire [31:0] S_AXI_ARADDR,
    input  wire        S_AXI_ARVALID,
    output wire        S_AXI_ARREADY,

    output wire [31:0] S_AXI_RDATA,
    output wire [1:0]  S_AXI_RRESP,
    output wire        S_AXI_RVALID,
    input  wire        S_AXI_RREADY,

    // ------------------------------------------------------------
    // AXI IIC side pins
    //
    // Connect these to the Xilinx AXI IIC IP.
    // ------------------------------------------------------------
    output wire        sda_i,
    input wire         sda_o,
    input wire         sda_t,

    output wire        scl_i,
    input wire         scl_o,
    input wire         scl_t,

    // ------------------------------------------------------------
    // Physical I2C bus side pins
    //
    // Connect these to IOBUFs / top-level board pins.
    // ------------------------------------------------------------
    inout              i2c_sda,
    inout              i2c_scl,

    // Interrupt
    output wire packet_done_irq,

    // ------------------------------------------------------------
    // Mux control
    //
    // 1'b1: AXI IIC drives physical I2C bus
    // 1'b0: custom I2C_controller drives physical I2C bus
    // ------------------------------------------------------------

    // ------------------------------------------------------------
    // Optional debug/status pins
    // ------------------------------------------------------------
    output wire        enable_debug,
    output wire        soft_reset_debug,
    output wire        start_read_debug,
    output wire        i2c_busy_debug,
    output wire        i2c_done_debug,
    output wire        packet_done_debug,
    output wire        ack_error_debug,
    output wire [63:0] timestamp_debug
);

    // ------------------------------------------------------------
    // Internal reset
    // ------------------------------------------------------------
    wire rst;
    wire soft_reset;

    assign rst = (~S_AXI_ARESETN) | soft_reset;

    // ------------------------------------------------------------
    // AXI register wires
    // ------------------------------------------------------------
    wire        enable;
    wire        useAXI;
    wire [31:0] sample_period_32;
    wire [31:0] sensor_enable_mask;

    wire        clear_error;
    wire        reset_sample_counter;
    wire        cpu_clear_irq;

    wire        busy;
    wire        error;
    wire        read_in_progress;

    wire [31:0] error_code;

    // ------------------------------------------------------------
    // Time / acquisition wires
    // ------------------------------------------------------------
    wire [63:0] timestamp;
    wire        start_read;

    // ------------------------------------------------------------
    // I2C reader wires
    // ------------------------------------------------------------
    wire [143:0] i2c_data;
    wire         i2c_busy;
    wire         i2c_done;
    wire         ack_error;
    wire [3:0]   i2c_state;

    // ------------------------------------------------------------
    // Packetizer wires
    // ------------------------------------------------------------
    wire [255:0] packet;
    wire         packet_done;



    // ------------------------------------------------------------
    // Status signals
    // ------------------------------------------------------------
    assign busy             = i2c_busy;
    assign error            = ack_error;
    assign read_in_progress = i2c_busy;
    assign error_code       = {31'd0, ack_error};

    // ------------------------------------------------------------
    // I2C interfaces
    // ------------------------------------------------------------
    // ------------------------------------------------------------
    // Flattened I2C reader bus wires
    // ------------------------------------------------------------
    wire read_sda_i;
    wire read_sda_o;
    wire read_sda_t;

    wire read_scl_i;
    wire read_scl_o;
    wire read_scl_t;

    // ------------------------------------------------------------
    // Flattened physical I2C bus wires
    // ------------------------------------------------------------
    wire physical_sda_i;
    wire physical_sda_o;
    wire physical_sda_t;

    wire physical_scl_i;
    wire physical_scl_o;
    wire physical_scl_t;

    


    // ------------------------------------------------------------
    // AXI-Lite register block
    // ------------------------------------------------------------
    axil_regs u_axi_lite_regs (
        .s00_axi_aclk          (S_AXI_ACLK),
        .s00_axi_aresetn       (S_AXI_ARESETN),

        .s00_axi_awaddr        (S_AXI_AWADDR),
        .s00_axi_awvalid       (S_AXI_AWVALID),
        .s00_axi_awready       (S_AXI_AWREADY),

        .s00_axi_wdata         (S_AXI_WDATA),
        .s00_axi_wstrb         (S_AXI_WSTRB),
        .s00_axi_wvalid        (S_AXI_WVALID),
        .s00_axi_wready        (S_AXI_WREADY),

        .s00_axi_bresp         (S_AXI_BRESP),
        .s00_axi_bvalid        (S_AXI_BVALID),
        .s00_axi_bready        (S_AXI_BREADY),

        .s00_axi_araddr        (S_AXI_ARADDR),
        .s00_axi_arvalid       (S_AXI_ARVALID),
        .s00_axi_arready       (S_AXI_ARREADY),

        .s00_axi_rdata         (S_AXI_RDATA),
        .s00_axi_rresp         (S_AXI_RRESP),
        .s00_axi_rvalid        (S_AXI_RVALID),
        .s00_axi_rready        (S_AXI_RREADY),

        .enable              (enable),
        .soft_reset          (soft_reset),
        .useAXI              (useAXI),
        .sample_period       (sample_period_32),
        .sensor_enable_mask  (sensor_enable_mask),

        .clear_error         (clear_error),
        .reset_sample_counter(reset_sample_counter),
        .cpu_clear_irq       (cpu_clear_irq),

        .busy                (busy),
        .error               (error),
        .read_in_progress    (read_in_progress),
        .packet_done         (packet_done),
        .sample_count        (32'd0),
        .error_code          (error_code),
        .state               (i2c_state),
        
        .data_word0          (packet[31:0]),
        .data_word1          (packet[63:32]),
        .data_word2          (packet[95:64]),
        .data_word3          (packet[127:96]),
        .data_word4          (packet[159:128]),
        .data_word5          (packet[191:160]),
        .data_word6          (packet[223:192]),
        .data_word7          (packet[255:224])
    );

    // ------------------------------------------------------------
    // Timestamp counter
    // ------------------------------------------------------------
    timekeep u_timekeep (
        .clk               (S_AXI_ACLK),
        .rst               (rst),
        .enable            (enable),
        .timestamp_counter (timestamp)
    );

    // ------------------------------------------------------------
    // Acquisition controller
    // ------------------------------------------------------------
    acquisition_controller u_acquisition_controller (
        .clk           (S_AXI_ACLK),
        .rst           (rst),
        .enable        (enable),
        .timestamp     (timestamp),
        .sample_period ({32'd0, sample_period_32}),
        .startRead     (start_read)
    );

    // ------------------------------------------------------------
    // Custom deterministic I2C reader
    // ------------------------------------------------------------
    I2C_reader u_i2c_reader (
        .clk       (S_AXI_ACLK),
        .rst       (rst),
        .start     (start_read),
        .data_out  (i2c_data),
        .busy      (i2c_busy),
        .done      (i2c_done),
        .ack_error (ack_error),

        .sda_i (read_sda_i),
        .sda_o (read_sda_o),
        .sda_t (read_sda_t),

        .scl_i (read_scl_i),
        .scl_o (read_scl_o),
        .scl_t (read_scl_t),
        
        .stateOut (i2c_state)
    );

    // ------------------------------------------------------------
    // I2C mux
    // ------------------------------------------------------------
    I2C_mux u_i2c_mux (
        .useAXI    (useAXI),

        .sda_i_AXI (sda_i),
        .sda_o_AXI (sda_o),
        .sda_t_AXI (sda_t),

        .scl_i_AXI (scl_i),
        .scl_o_AXI (scl_o),
        .scl_t_AXI (scl_t),

        .read_sda_i (read_sda_i),
        .read_sda_o (read_sda_o),
        .read_sda_t (read_sda_t),

        .read_scl_i (read_scl_i),
        .read_scl_o (read_scl_o),
        .read_scl_t (read_scl_t),

        .out_sda_i  (physical_sda_i),
        .out_sda_o  (physical_sda_o),
        .out_sda_t  (physical_sda_t),

        .out_scl_i  (physical_scl_i),
        .out_scl_o  (physical_scl_o),
        .out_scl_t  (physical_scl_t)
    );

    IOBUF sda_iobuf (
        .I  (physical_sda_o),
        .O  (physical_sda_i),
        .T  (physical_sda_t),
        .IO (i2c_sda)
    );

    IOBUF scl_iobuf (
        .I  (physical_scl_o),
        .O  (physical_scl_i),
        .T  (physical_scl_t),
        .IO (i2c_scl)
    );

    // ------------------------------------------------------------
    // Packetizer
    // ------------------------------------------------------------
    packetizer u_packetizer (
        .clk            (S_AXI_ACLK),
        .rst            (rst),
        .start          (i2c_done),

        .data           (i2c_data),
        .timestamp      (timestamp),

        .sensor_id      (sensor_enable_mask[15:0]),
        .flags          ({15'd0, ack_error}),
        .sample_counter (16'd0),

        .packet_out     (packet),
        .done           (packet_done)
    );

    reg irq_pending;

    always @(posedge S_AXI_ACLK) begin
        if (rst) begin
            irq_pending <= 1'b0;
        end else begin
            if (packet_done)
                irq_pending <= 1'b1;
    
            if (cpu_clear_irq)
                irq_pending <= 1'b0;
        end
    end

    //assign packet_done_irq = irq_pending;
    assign packet_done_irq = 1'b0; // disable interrupt for now

    // ------------------------------------------------------------
    // Debug outputs
    // ------------------------------------------------------------
    assign enable_debug       = enable;
    assign soft_reset_debug   = soft_reset;
    assign start_read_debug   = start_read;
    assign i2c_busy_debug     = i2c_busy;
    assign i2c_done_debug     = i2c_done;
    assign packet_done_debug  = packet_done;
    assign ack_error_debug    = ack_error;
    assign timestamp_debug    = timestamp;

endmodule
