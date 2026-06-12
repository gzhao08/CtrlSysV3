import config_pkg::*;

module tb;

logic 	        clk;
raw_frame_t     in_frame;
raw_frame_t 	out_frame;
raw_frame_t 	rdata;
logic 			empty;
logic 			rd_en;
logic 			wr_en;
logic 			full;
logic 			rst;
logic 			stop;

data_buff u_data_buff ( .rst(rst),
                        .wr_en(wr_en),
                        .rd_en(rd_en),
                        .clk(clk),
                        .in_frame(in_frame),
                        .out_frame(out_frame),
                        .empty(empty),
                        .full(full)
                    );

always #20 clk = ~clk; // 50MHz

initial begin
    clk 	<= 0;
    rst 	<= 1;
    wr_en 	<= 0;
    rd_en 	<= 0;
    stop  	<= 0;

    #100 rst <= 0;
end

initial begin
    @(posedge clk);

    for (int i = 0; i < 20; i = i+1) begin

        // Wait until there is space in fifo
        while (full) begin
            @(posedge clk);
            $display("[%0t] FIFO is full, wait for reads to happen", $time);
        end;

        // Drive new values into FIFO
        wr_en <= $random;
        for (int s = 0; s < NUM_SENSORS; s++) begin
            in_frame[s].init_read_ts <= {$random, $random};
            in_frame[s].done_read_ts <= {$random, $random};
            in_frame[s].flags        <= $random;
            in_frame[s].reserved     <= 16'b0;
            in_frame[s].sensor_data  <= {$random, $random, $random, $random, $random};
        end
        $display("[%0t] clk i=%0d wr_en=%0d in_frame=0x%0h ", $time, i, wr_en, in_frame);

        // Wait for next clock edge
        @(posedge clk);
    end

    stop = 1;
end

initial begin
    @(posedge clk);

    while (!stop) begin
        // Wait until there is data in fifo
        while (empty) begin
            rd_en <= 0;
            $display("[%0t] FIFO is empty, wait for writes to happen", $time);
            @(posedge clk);
        end;

        // Sample new values from FIFO at random pace
        rd_en <= $random;
        @(posedge clk);
        rdata <= out_frame;
        $display("[%0t] clk rd_en=%0d rdata=0x%0h ", $time, rd_en, rdata);
    end

    #1000 $finish;
end

endmodule
