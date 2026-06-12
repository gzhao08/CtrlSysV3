import config_pkg::*;
`include "config_def.svh"

module ctrlsys_core (
    input logic clk,
    input logic rst,

    inout wire [NUM_SENSORS-1:0] sda,
    inout wire [NUM_SENSORS-1:0] scl,

    output logic        m_axis_tvalid,
    input logic         m_axis_tready,
    output logic [31:0] m_axis_tdata,
    output logic [3:0]  m_axis_tkeep,
    output logic        m_axis_tlast
);

logic [63:0] timestamp;
logic startRead;
logic sensor_start;
raw_frame_t sensor_frame;
raw_frame_t fifo_frame;
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
I2C_bus i2c_bus [NUM_SENSORS] ();

// Double-flop the external reset before it touches the acquisition logic.
logic rst_meta;
logic rst_sync;
always_ff @(posedge clk) begin
    rst_meta <= rst;
    rst_sync <= rst_meta;
end

stopwatch_64 u_stopwatch_64 (
    .clk(clk),
    .rst(rst_sync),
    .timestamp_counter(timestamp)
);

acquisition_controller u_acquisition_controller (
    .clk(clk),
    .rst(rst_sync),
    .enable(~rst_sync),
    .timestamp(timestamp),
    .sample_period(5000),
    .startRead(startRead)
);

sensors_reader u_sensors_reader (
    .clk(clk),
    .rst(rst_sync),
    .start(sensor_start),
    .timestamp(timestamp),
    .frame_out(sensor_frame),
    .busy(sensor_busy),
    .done(sensor_done),
    .error(sensor_error),
    .states(sensor_states),
    .i2c_bus(i2c_bus)
);

assign all_sensors_complete = &(sensor_complete | sensor_done | sensor_error);
assign sensor_start = startRead && !all_sensors_complete && !frame_full && !(|sensor_busy);

always_ff @(posedge clk) begin
    if (rst_sync) begin
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

data_buff u_data_buff (
    .clk(clk),
    .rst(rst_sync),
    .wr_en(frame_wr_en),
    .rd_en(frame_rd_en),
    .in_frame(sensor_frame),
    .out_frame(fifo_frame),
    .empty(frame_empty),
    .full(frame_full)
);

frame_to_axis #(
    .data_width(32)
) u_frame_to_axis (
    .clk(clk),
    .rst(rst_sync),
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
            .O(i2c_bus[i].scl_i),
            .IO(scl[i]),
            .I(1'b0),
            .T(i2c_bus[i].scl_t)
        );

        IOBUF IOBUF_sda_inst (
            .O(i2c_bus[i].sda_i),
            .IO(sda[i]),
            .I(1'b0),
            .T(i2c_bus[i].sda_t)
        );
    end
endgenerate

endmodule
