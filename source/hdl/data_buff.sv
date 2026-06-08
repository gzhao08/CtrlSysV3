/* 
Name: Gordon Zhao
File: data_buff.sv
Description: synchronous FIFO for storing sensor data frames (multiple sensor packets)
*/

import config_pkg::*;

module data_buff (
    input logic         clk,
    input logic         rst,
    input logic         wr_en,
    input logic         rd_en,
    input data_frame_t  in_frame,
    output data_frame_t out_frame,
    output logic        empty,
    output logic        full
);

logic [$clog2(BUFFER_SIZE)-1:0] wptr;
logic [$clog2(BUFFER_SIZE)-1:0] rptr;
data_frame_t fifo [BUFFER_SIZE-1:0];

always @(posedge clk) begin

    // reset
    if (rst) begin
        wptr <= 0;
        rptr <= 0;
    end

    else begin
        // only write if not full and enabled
        if (wr_en & !full) begin
            fifo[wptr] <= in_frame;
            wptr <= wptr + 1;
        end

        // only read if not empty and enabled
        if (rd_en & !empty) begin
            out_frame <= fifo[rptr];
            rptr <= rptr + 1;
        end
    end
end

assign full  = (wptr + 1) == rptr;
assign empty = wptr == rptr;

endmodule