/* 
Name: Gordon Zhao
File: SPI_reader.sv
Description: an SPI master for performing burst reads
*/

module SPI_reader #(
    parameter reg [6:0] REG_ADDR = 7'd45, // ICM accel_xout_h starts at address 45
    parameter reg [7:0] DATA_BYTES = 8'd18 // the number of data bytes to read
)(
    input                clk,
    input                rst,
    input                start,
    output logic [143:0] data_out, // 3 data, 3 directions, 2 bytes each = 18 bytes = 144 bits
    output               busy,
    output logic         done,
    // SPI lines
    output logic         sclk,
    output logic         mosi,
    input  logic         miso,
    output logic         cs_n 
);

localparam IDLE  = 2'b00;
localparam SEND_ADDR  = 2'b01;
localparam READ_DATA = 2'b10; 

// sequential copies of spi lines
logic cs_drive;
logic mosi_drive;


// SPI timing
logic spi_tick;
logic tick_en;
logic [1:0] tickCounter;
logic spi_clk_rising;
logic spi_clk_falling;

// State machine
logic [1:0] state;

// data
logic [7:0] data_temp;
logic [2:0] counter;
logic [7:0] num_data_bytes;

assign cs_n = cs_drive;
assign mosi = mosi_drive;
assign sclk = spi_tick;

assign busy = (state != IDLE);



// spi timing (sclk)

always @(posedge clk) begin
    spi_clk_rising <= 1'b0;
    spi_clk_falling <= 1'b0;
    if (tick_en) begin
        if (tickCounter == 3) begin
            tickCounter <= 0;
            spi_tick <= ~spi_tick;
            if (spi_tick == 1) begin
                spi_clk_falling <= 1'b1;
            end
            else begin
                spi_clk_rising <= 1'b1;
            end
        end
        else
            tickCounter <= tickCounter + 2'b1;
    end
    else begin
        spi_tick <= 1'b0;
    end
end 


always @(posedge clk) begin

    // reset behavior
    if (rst) begin
        state <= IDLE;
        cs_drive <= 1'b1; // cs is active low
        tick_en <= 1'b0;
    end

    case (state)
        IDLE: begin
            done <= 1'b0;
            if (start) begin
                state <= SEND_ADDR;
                tickCounter <= 1;
                tick_en <= 1'b1;
                data_temp <= {1'b1,REG_ADDR};
                counter <= 3'd7;
                cs_drive <= 0; // pull cs low to get sensor ready for data
            end
        end

        SEND_ADDR: begin
            // data transition on falling edge (i.e. drive data on falling edge)
            if (spi_clk_falling) begin
                mosi_drive <= data_temp[counter];
                if (counter == 0) begin
                    state <= READ_DATA;
                    num_data_bytes <= DATA_BYTES - 1;
                end
                counter <= counter - 3'b1; // should reset counter to 7 after 0
            end
        end

        READ_DATA: begin
            if (spi_clk_rising) begin
                // read and store data
                data_out[num_data_bytes*8+counter] <= miso;
                if (counter == 0) begin
                    counter <= 7; // reset counter
                    if (num_data_bytes == 0) begin 
                        state <= IDLE;
                        done <= 1'b1;
                        tick_en <= 1'b0;
                        cs_drive <= 1'b1;
                    end
                    else
                        num_data_bytes <= num_data_bytes - 1;
                end else 
                    counter <= counter - 1;
            end
        end

    endcase
end

endmodule