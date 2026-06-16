import config_pkg::*;
`include "config_def.svh"

module ctrlsys_core #(
    parameter integer NUM_SENSORS = 3,
    parameter integer BUFFER_SIZE = 5,
    parameter integer SENS0_PROTOCOL = 0,
    parameter integer SENS0_ADDR = 0,
    parameter integer SENS0_REG_ADDR = 5,
    parameter integer SENS0_NUM_BYTES = 18,
    parameter integer SENS1_PROTOCOL = 0,
    parameter integer SENS1_ADDR = 127,
    parameter integer SENS1_REG_ADDR = 41,
    parameter integer SENS1_NUM_BYTES = 18,
    parameter integer SENS2_PROTOCOL = 0,
    parameter integer SENS2_ADDR = 127,
    parameter integer SENS2_REG_ADDR = 41,
    parameter integer SENS2_NUM_BYTES = 18,
    parameter integer SENS3_PROTOCOL = 0,
    parameter integer SENS3_ADDR = 0,
    parameter integer SENS3_REG_ADDR = 0,
    parameter integer SENS3_NUM_BYTES = 0,
    parameter integer SENS4_PROTOCOL = 0,
    parameter integer SENS4_ADDR = 0,
    parameter integer SENS4_REG_ADDR = 0,
    parameter integer SENS4_NUM_BYTES = 0,
    parameter integer SENS5_PROTOCOL = 0,
    parameter integer SENS5_ADDR = 0,
    parameter integer SENS5_REG_ADDR = 0,
    parameter integer SENS5_NUM_BYTES = 0
)(
    input logic clk,
    input logic rst,

    inout wire [NUM_SENSORS-1:0] sda,
    inout wire [NUM_SENSORS-1:0] scl,

    output logic        m_axis_tvalid,
    input logic         m_axis_tready,
    output logic [31:0] m_axis_tdata,
    output logic [3:0]  m_axis_tkeep,
    output logic        m_axis_tlast,

    input  logic        s00_axi_aclk,
    input  logic        s00_axi_aresetn,
    input  logic [5:0]  s00_axi_awaddr,
    input  logic [2:0]  s00_axi_awprot,
    input  logic        s00_axi_awvalid,
    output logic        s00_axi_awready,
    input  logic [31:0] s00_axi_wdata,
    input  logic [3:0]  s00_axi_wstrb,
    input  logic        s00_axi_wvalid,
    output logic        s00_axi_wready,
    output logic [1:0]  s00_axi_bresp,
    output logic        s00_axi_bvalid,
    input  logic        s00_axi_bready,
    input  logic [5:0]  s00_axi_araddr,
    input  logic [2:0]  s00_axi_arprot,
    input  logic        s00_axi_arvalid,
    output logic        s00_axi_arready,
    output logic [31:0] s00_axi_rdata,
    output logic [1:0]  s00_axi_rresp,
    output logic        s00_axi_rvalid,
    input  logic        s00_axi_rready,

    output logic        axi_iic_sda_i,
    input  logic        axi_iic_sda_o,
    input  logic        axi_iic_sda_t,
    output logic        axi_iic_scl_i,
    input  logic        axi_iic_scl_o,
    input  logic        axi_iic_scl_t
);

localparam int MAX_SENSORS = 6;
localparam int PROTOCOL_WIDTH = 2;
localparam int SENSOR_SEL_WIDTH = (NUM_SENSORS > 1) ? $clog2(NUM_SENSORS) : 1;
localparam logic [PROTOCOL_WIDTH*MAX_SENSORS-1:0] ALL_SENSOR_PROTOCOLS = {
    SENS5_PROTOCOL[PROTOCOL_WIDTH-1:0],
    SENS4_PROTOCOL[PROTOCOL_WIDTH-1:0],
    SENS3_PROTOCOL[PROTOCOL_WIDTH-1:0],
    SENS2_PROTOCOL[PROTOCOL_WIDTH-1:0],
    SENS1_PROTOCOL[PROTOCOL_WIDTH-1:0],
    SENS0_PROTOCOL[PROTOCOL_WIDTH-1:0]
};
localparam logic [7*MAX_SENSORS-1:0] ALL_SENSOR_ADDRS = {
    SENS5_ADDR[6:0],
    SENS4_ADDR[6:0],
    SENS3_ADDR[6:0],
    SENS2_ADDR[6:0],
    SENS1_ADDR[6:0],
    SENS0_ADDR[6:0]
};
localparam logic [8*MAX_SENSORS-1:0] ALL_SENSOR_REG_ADDRS = {
    SENS5_REG_ADDR[7:0],
    SENS4_REG_ADDR[7:0],
    SENS3_REG_ADDR[7:0],
    SENS2_REG_ADDR[7:0],
    SENS1_REG_ADDR[7:0],
    SENS0_REG_ADDR[7:0]
};
localparam logic [8*MAX_SENSORS-1:0] ALL_SENSOR_NUM_BYTES = {
    SENS5_NUM_BYTES[7:0],
    SENS4_NUM_BYTES[7:0],
    SENS3_NUM_BYTES[7:0],
    SENS2_NUM_BYTES[7:0],
    SENS1_NUM_BYTES[7:0],
    SENS0_NUM_BYTES[7:0]
};
localparam logic [PROTOCOL_WIDTH*NUM_SENSORS-1:0] SENSOR_PROTOCOLS = ALL_SENSOR_PROTOCOLS[PROTOCOL_WIDTH*NUM_SENSORS-1:0];
localparam logic [7*NUM_SENSORS-1:0] SENSOR_ADDRS = ALL_SENSOR_ADDRS[7*NUM_SENSORS-1:0];
localparam logic [8*NUM_SENSORS-1:0] SENSOR_REG_ADDRS = ALL_SENSOR_REG_ADDRS[8*NUM_SENSORS-1:0];
localparam logic [8*NUM_SENSORS-1:0] SENSOR_NUM_BYTES = ALL_SENSOR_NUM_BYTES[8*NUM_SENSORS-1:0];

logic [63:0] timestamp;
logic startRead;
logic sensor_start;
logic core_rst;
raw_packet_t sensor_frame [NUM_SENSORS];
raw_packet_t fifo_frame [NUM_SENSORS];
logic [NUM_SENSORS-1:0] sensor_busy;
logic [NUM_SENSORS-1:0] sensor_done;
logic [NUM_SENSORS-1:0] sensor_error;
logic [NUM_SENSORS-1:0] sensor_complete;
logic [3:0] sensor_states [NUM_SENSORS-1:0];
logic frame_wr_en;
logic frame_rd_en;
logic frame_empty;
logic frame_full;
logic all_sensors_complete;
logic axil_enable;
logic axil_soft_reset;
logic [31:0] axil_sample_period;
logic [31:0] axil_sensor_enable_mask;
logic [NUM_SENSORS-1:0] active_sensor_mask;
logic axil_useAXI;
logic axil_clear_error;
logic axil_reset_sample_counter;
logic axil_cpu_clear_irq;
logic packet_done_irq;
logic error_latched;
logic [31:0] sample_count;
logic [31:0] error_code;
logic [31:0] data_word0;
logic [31:0] data_word1;
logic [31:0] data_word2;
logic [31:0] data_word3;
logic [31:0] data_word4;
logic [31:0] data_word5;
logic [31:0] data_word6;
logic [31:0] data_word7;
logic [SENSOR_SEL_WIDTH-1:0] axi_iic_sensor_sel;
logic [NUM_SENSORS-1:0] reader_sda_i;
logic [NUM_SENSORS-1:0] reader_sda_o;
logic [NUM_SENSORS-1:0] reader_sda_t;
logic [NUM_SENSORS-1:0] reader_scl_i;
logic [NUM_SENSORS-1:0] reader_scl_o;
logic [NUM_SENSORS-1:0] reader_scl_t;
logic [NUM_SENSORS-1:0] muxed_sda_i;
logic [NUM_SENSORS-1:0] muxed_sda_o;
logic [NUM_SENSORS-1:0] muxed_sda_t;
logic [NUM_SENSORS-1:0] muxed_scl_i;
logic [NUM_SENSORS-1:0] muxed_scl_o;
logic [NUM_SENSORS-1:0] muxed_scl_t;
integer sensor_sel_index;

// Double-flop the external reset before it touches the acquisition logic.
logic rst_meta;
logic rst_sync;
always_ff @(posedge clk) begin
    rst_meta <= rst;
    rst_sync <= rst_meta;
end

assign core_rst = rst_sync || axil_soft_reset;
assign active_sensor_mask = (axil_sensor_enable_mask[NUM_SENSORS-1:0] == '0)
                          ? {NUM_SENSORS{1'b1}}
                          : axil_sensor_enable_mask[NUM_SENSORS-1:0];

always_comb begin
    axi_iic_sensor_sel = '0;

    for (sensor_sel_index = NUM_SENSORS - 1; sensor_sel_index >= 0; sensor_sel_index = sensor_sel_index - 1) begin
        if (active_sensor_mask[sensor_sel_index])
            axi_iic_sensor_sel = sensor_sel_index;
    end
end

axil_regs u_axil_regs (
    .enable(axil_enable),
    .soft_reset(axil_soft_reset),
    .sample_period(axil_sample_period),
    .sensor_enable_mask(axil_sensor_enable_mask),
    .useAXI(axil_useAXI),
    .clear_error(axil_clear_error),
    .reset_sample_counter(axil_reset_sample_counter),
    .cpu_clear_irq(axil_cpu_clear_irq),
    .busy(|(sensor_busy & active_sensor_mask) || frame_full),
    .error(error_latched),
    .read_in_progress(|(sensor_busy & active_sensor_mask)),
    .packet_done(packet_done_irq),
    .sample_count(sample_count),
    .error_code(error_code),
    .state(sensor_states[0]),
    .data_word0(data_word0),
    .data_word1(data_word1),
    .data_word2(data_word2),
    .data_word3(data_word3),
    .data_word4(data_word4),
    .data_word5(data_word5),
    .data_word6(data_word6),
    .data_word7(data_word7),
    .s00_axi_aclk(s00_axi_aclk),
    .s00_axi_aresetn(s00_axi_aresetn),
    .s00_axi_awaddr(s00_axi_awaddr),
    .s00_axi_awprot(s00_axi_awprot),
    .s00_axi_awvalid(s00_axi_awvalid),
    .s00_axi_awready(s00_axi_awready),
    .s00_axi_wdata(s00_axi_wdata),
    .s00_axi_wstrb(s00_axi_wstrb),
    .s00_axi_wvalid(s00_axi_wvalid),
    .s00_axi_wready(s00_axi_wready),
    .s00_axi_bresp(s00_axi_bresp),
    .s00_axi_bvalid(s00_axi_bvalid),
    .s00_axi_bready(s00_axi_bready),
    .s00_axi_araddr(s00_axi_araddr),
    .s00_axi_arprot(s00_axi_arprot),
    .s00_axi_arvalid(s00_axi_arvalid),
    .s00_axi_arready(s00_axi_arready),
    .s00_axi_rdata(s00_axi_rdata),
    .s00_axi_rresp(s00_axi_rresp),
    .s00_axi_rvalid(s00_axi_rvalid),
    .s00_axi_rready(s00_axi_rready)
);

stopwatch_64 u_stopwatch_64 (
    .clk(clk),
    .rst(core_rst),
    .timestamp_counter(timestamp)
);

acquisition_controller u_acquisition_controller (
    .clk(clk),
    .rst(core_rst),
    .enable(axil_enable),
    .timestamp(timestamp),
    .sample_period({32'b0, axil_sample_period}),
    .startRead(startRead)
);

sensors_reader #(
    .NUM_SENSORS(NUM_SENSORS),
    .PROTOCOL_WIDTH(PROTOCOL_WIDTH),
    .SENSOR_PROTOCOLS(SENSOR_PROTOCOLS),
    .SENSOR_ADDRS(SENSOR_ADDRS),
    .SENSOR_REG_ADDRS(SENSOR_REG_ADDRS),
    .SENSOR_NUM_BYTES(SENSOR_NUM_BYTES)
) u_sensors_reader (
    .clk(clk),
    .rst(core_rst),
    .start(sensor_start),
    .sensor_enable_mask(active_sensor_mask),
    .timestamp(timestamp),
    .frame_out(sensor_frame),
    .busy(sensor_busy),
    .done(sensor_done),
    .error(sensor_error),
    .states(sensor_states),
    .i2c_sda_i(reader_sda_i),
    .i2c_sda_o(reader_sda_o),
    .i2c_sda_t(reader_sda_t),
    .i2c_scl_i(reader_scl_i),
    .i2c_scl_o(reader_scl_o),
    .i2c_scl_t(reader_scl_t)
);

sensors_mux #(
    .NUM_SENSORS(NUM_SENSORS)
) u_sensors_mux (
    .axi_enable(axil_useAXI),
    .axi_sensor_sel(axi_iic_sensor_sel),
    .i2c_reader_sda_i(reader_sda_i),
    .i2c_reader_sda_o(reader_sda_o),
    .i2c_reader_sda_t(reader_sda_t),
    .i2c_reader_scl_i(reader_scl_i),
    .i2c_reader_scl_o(reader_scl_o),
    .i2c_reader_scl_t(reader_scl_t),
    .axi_iic_sda_i(axi_iic_sda_i),
    .axi_iic_sda_o(axi_iic_sda_o),
    .axi_iic_sda_t(axi_iic_sda_t),
    .axi_iic_scl_i(axi_iic_scl_i),
    .axi_iic_scl_o(axi_iic_scl_o),
    .axi_iic_scl_t(axi_iic_scl_t),
    .i2c_out_sda_i(muxed_sda_i),
    .i2c_out_sda_o(muxed_sda_o),
    .i2c_out_sda_t(muxed_sda_t),
    .i2c_out_scl_i(muxed_scl_i),
    .i2c_out_scl_o(muxed_scl_o),
    .i2c_out_scl_t(muxed_scl_t)
);

assign all_sensors_complete = &((sensor_complete | sensor_done | sensor_error) | ~active_sensor_mask);
assign sensor_start = startRead && !all_sensors_complete && !frame_full && !(|(sensor_busy & active_sensor_mask));

always_ff @(posedge clk) begin
    if (core_rst) begin
        sensor_complete <= '0;
        frame_wr_en     <= 1'b0;
    end else begin
        frame_wr_en <= 1'b0;

        if (all_sensors_complete) begin
            sensor_complete <= sensor_complete | sensor_done | sensor_error;

            if (!frame_full) begin
                frame_wr_en     <= 1'b1;
                sensor_complete <= '0;
            end
        end else if (sensor_start) begin
            sensor_complete <= '0;
        end else begin
            sensor_complete <= sensor_complete | sensor_done | sensor_error;
        end
    end
end

always_ff @(posedge clk) begin
    if (core_rst) begin
        sample_count    <= 32'b0;
        error_latched   <= 1'b0;
        error_code      <= 32'b0;
        packet_done_irq <= 1'b0;
        data_word0      <= 32'b0;
        data_word1      <= 32'b0;
        data_word2      <= 32'b0;
        data_word3      <= 32'b0;
        data_word4      <= 32'b0;
        data_word5      <= 32'b0;
        data_word6      <= 32'b0;
        data_word7      <= 32'b0;
    end else begin
        if (axil_clear_error) begin
            error_latched <= 1'b0;
            error_code    <= 32'b0;
        end else if (|(sensor_error & active_sensor_mask)) begin
            error_latched <= 1'b1;
            error_code    <= {{(32-NUM_SENSORS){1'b0}}, (sensor_error & active_sensor_mask)};
        end

        if (axil_cpu_clear_irq)
            packet_done_irq <= 1'b0;
        else if (frame_wr_en)
            packet_done_irq <= 1'b1;

        if (axil_reset_sample_counter) begin
            sample_count <= 32'b0;
        end else if (frame_wr_en) begin
            sample_count <= sample_count + 1'b1;
        end

        if (frame_wr_en) begin
            data_word0 <= sensor_frame[0].init_read_ts[31:0];
            data_word1 <= sensor_frame[0].init_read_ts[63:32];
            data_word2 <= {16'd0, sensor_frame[0].flags[15:0]};
            data_word3 <= sensor_frame[0].sensor_data[143:112];
            data_word4 <= sensor_frame[0].sensor_data[111:80];
            data_word5 <= sensor_frame[0].sensor_data[79:48];
            data_word6 <= sensor_frame[0].sensor_data[47:16];
            data_word7 <= {sensor_frame[0].sensor_data[15:0], sample_count[15:0] + 16'd1};
        end
    end
end

data_buff #(
    .NUM_SENSORS(NUM_SENSORS),
    .BUFFER_SIZE(BUFFER_SIZE)
) u_data_buff (
    .clk(clk),
    .rst(core_rst),
    .wr_en(frame_wr_en),
    .rd_en(frame_rd_en),
    .in_frame(sensor_frame),
    .out_frame(fifo_frame),
    .empty(frame_empty),
    .full(frame_full)
);

frame_to_axis #(
    .NUM_SENSORS(NUM_SENSORS),
    .data_width(32)
) u_frame_to_axis (
    .clk(clk),
    .rst(core_rst),
    .rd_en(frame_rd_en),
    .empty(frame_empty),
    .frame(fifo_frame),
    .m_axis_tvalid(m_axis_tvalid),
    .m_axis_tready(m_axis_tready),
    .m_axis_tdata(m_axis_tdata),
    .m_axis_tkeep(m_axis_tkeep),
    .m_axis_tlast(m_axis_tlast)
);

genvar i;
generate
    for (i = 0; i < NUM_SENSORS; i++) begin : gen_iobuf
        IOBUF IOBUF_scl_inst (
            .O(muxed_scl_i[i]),
            .IO(scl[i]),
            .I(muxed_scl_o[i]),
            .T(muxed_scl_t[i])
        );

        IOBUF IOBUF_sda_inst (
            .O(muxed_sda_i[i]),
            .IO(sda[i]),
            .I(muxed_sda_o[i]),
            .T(muxed_sda_t[i])
        );
    end
endgenerate

endmodule
