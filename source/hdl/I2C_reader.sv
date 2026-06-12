/* 
Name: Gordon Zhao
File: I2C_reader.v
Description: an I2C master for performing burst reads
*/

import config_pkg::*; 
`include "config_def.svh"

module I2C_reader #(
    parameter logic [6:0] SENSOR_ADDR = 7'h68, // I2C sensors have a 7 bit address 
    parameter logic [7:0] REG_ADDR = 8'd18, // the register to start reading data from
    parameter logic [7:0] DATA_BYTES = 8'd18 // the number of data bytes to read
)(
    input                   clk,
    input                   rst,
    input                   start,
    input logic [63:0]      timestamp,    
    output raw_packet_t     packet_out,
    output                  busy,
    output logic            done,
    output logic            ack_error,

    // `ifdef DEBUG         
    output [3:0] stateOut,
    // `endif 
    
    I2C_bus.master i2c
);	


logic [3:0] state = 0; // IDLE
logic [7:0] counter = 7;

logic [7:0] temp_data; // for storing things to send to sensor
logic [7:0] num_data_bytes = DATA_BYTES - 1; // -1 because 0 indexed
logic [7:0] data_index = 0;

logic sda_drive_low = 0; // 0 means release and 1 means drive low
logic sda_update = 0;
logic scl_follow = 0; // 0 means release and 1 means follow the 400kHz clk 

logic updateState = 0;
logic [3:0] nextState = 0;

// packet
logic [63:0]    init_read_ts; // timestamp that read was initiated
logic [63:0]    done_read_ts; // timestamp that read finished
logic [143:0]   sensor_data;  //

// timing
logic [7:0] tickCounter = 63;
logic tick_en = 0;
logic i2c_tick = 0; // basically an 800kHz clock
logic i2c_tick_parity = 1;

assign i2c.sda_o = 1'b0;
assign i2c.sda_t = sda_drive_low ? 1'b0 : 1'b1;

assign i2c.scl_o = 1'b0;
assign i2c.scl_t = scl_follow ? i2c_tick_parity : 1'b1;

assign stateOut = state; // temp

assign busy = (state == 0) ? 1'b0 : 1'b1;

always_comb begin
    packet_out.init_read_ts = init_read_ts;
    packet_out.done_read_ts = done_read_ts;
    packet_out.flags        = 32'b0;
    packet_out.flags[0]     = !ack_error;
    packet_out.flags[1]     = ack_error;
    packet_out.reserved     = 16'b0;
    packet_out.sensor_data  = sensor_data;
end

always @(posedge clk) begin
    
    // i2c timing stuff
    i2c_tick <= 1'b0;

    if (rst) begin
        state <= 0;
        tickCounter <= 0;
        i2c_tick_parity <= 1'b0;
        done <= 0;
        ack_error <= 0;
        tick_en <= 0;
        sda_drive_low <= 0;
        scl_follow <= 0;
        updateState <= 0;
        nextState <= 0;
        counter <= 7;
        num_data_bytes <= DATA_BYTES - 1;
        sensor_data <= 144'b0;
    end else if (tick_en) begin
        if (tickCounter == 63) begin
            tickCounter <= 0;
            i2c_tick <= 1'b1;
        end 
        else begin
            if (tickCounter == 31) 
                i2c_tick_parity <= ~i2c_tick_parity; 
            tickCounter <= tickCounter + 1;
        end
    end
        
    else begin
        done <= 0;
        if (start && state == 0) begin
            state <= 1;
            done <= 0;
            ack_error <= 0;
            tick_en <= 1;   // start i2c timing
            init_read_ts <= timestamp;
        end
    end

    if (i2c_tick) begin

        case (state)
            
            1: begin
                // send start condition
                if (i2c_tick_parity) begin
                    // when SCL is high pull SDA low and start clock
                    sda_drive_low <= 1;
                    scl_follow <= 1;
                    temp_data <= {SENSOR_ADDR,1'b0}; // 0 for Write
                    updateState <= 1;
                end

                // go
                else if (updateState) begin
                    updateState <= 0;
                    state <= 2;
                    sda_drive_low <= !temp_data[7]; // send the MSB
                    counter <= 6;
                end 
            end

            2: begin
                // send address and read write bit
                // data transmission only happens while SCL is low
                if (i2c_tick_parity == 0) begin

                    if (updateState == 1) begin
                        state <= 3;
                        updateState <= 0;
                        counter <= 7;
                        sda_drive_low <= 0; // release SDA after transmission
                    end

                    else begin 

                        sda_drive_low <= !temp_data[counter]; // invert because 0 means SDA is HIGH and vice versa

                        if (counter == 0) begin
                            updateState <= 1;
                        end

                        else
                            counter <= counter - 1;
                    end
                end
            end

            3: begin
                // check for ACK
                // sensor must actively pull SDA low
                if (i2c_tick_parity) begin
                    if (i2c.sda_i == 0) begin       // check for ACK
                        nextState <= 4;
                        temp_data <= REG_ADDR;
                        updateState <= 1;
                    end else begin
                        // if NACK then return to idle state and show error
                        state <= 0;
                        ack_error <= 1; 
                        done <= 1;
                        done_read_ts <= timestamp;
                        sda_drive_low <= 0;
                        scl_follow <= 0;
                        tick_en <= 0;
                        tickCounter <= 0;
                        num_data_bytes <= DATA_BYTES - 1;
                        updateState <= 0;
                    end
                end

                else if (updateState) begin
                    updateState <= 0;
                    state <= nextState;
                    sda_drive_low <= !temp_data[7]; // send the MSB
                    counter <= 6;
                end
            end

            4: begin
                // send register address
                // data transmission only happens while SCL is low
                if (i2c_tick_parity == 0) begin

                    if (updateState == 1) begin
                        state <= 5;
                        updateState <= 0;
                        counter <= 7;
                        sda_drive_low <= 0; // release SDA after transmission
                    end

                    else begin 

                        sda_drive_low <= !temp_data[counter]; // invert because 0 means SDA is HIGH and vice versa

                        if (counter == 0) begin
                            updateState <= 1;
                        end

                        else
                            counter <= counter - 1;
                    end
                end
            end

            5: begin
                // check for ACK; same as state 3
                if (i2c_tick_parity) begin
                    if (i2c.sda_i == 0) begin       // check for ACK
                        nextState <= 6;
                        temp_data <= REG_ADDR;
                        updateState <= 1;
                    end else begin
                        // if NACK then return to idle state and show error
                        state <= 0;
                        ack_error <= 1; 
                        done <= 1;
                        done_read_ts <= timestamp;
                        sda_drive_low <= 0;
                        scl_follow <= 0;
                        tick_en <= 0;
                        tickCounter <= 0;
                        num_data_bytes <= DATA_BYTES - 1;
                        updateState <= 0;
                    end
                end

                else if (updateState) begin
                    updateState <= 0;
                    state <= nextState;
                    sda_drive_low <= 0; // release SDA to prepare to send repeated Start
                    counter <= 6;
                end

            end

            6: begin
                // send repeated start
                if (i2c_tick_parity) begin
                    sda_drive_low <= 1; // HIGH -> LOW transition during a HIGH SCL to indicate Start
                    temp_data <= {SENSOR_ADDR,1'b1}; // 1 for Read
                    updateState <= 1;
                end

                else if (updateState) begin
                    updateState <= 0;
                    state <= 7;
                    sda_drive_low <= !temp_data[7]; // send the MSB
                    counter <= 6;
                end 
            end

            7: begin
                // send sensor address + Read(0)
                // SDA changes only happen while SCL is low
                if (i2c_tick_parity == 0) begin

                    if (updateState == 1) begin
                        state <= 8;
                        updateState <= 0;
                        counter <= 7;
                        sda_drive_low <= 0; // release SDA after transmission
                    end

                    else begin 

                        sda_drive_low <= !temp_data[counter]; // invert because 0 means SDA is HIGH and vice versa

                        if (counter == 0) begin
                            updateState <= 1;
                        end

                        else
                            counter <= counter - 1;
                    end
                end
            end

            8: begin
                // check for ACK
                // sensor must actively pull SDA low
                if (i2c_tick_parity) begin
                    if (i2c.sda_i == 0) begin       // check for ACK
                        nextState <= 9;
                        updateState <= 1;
                    end else begin
                        // if NACK then return to idle state and show error
                        state <= 0;
                        ack_error <= 1; 
                        done <= 1;
                        done_read_ts <= timestamp;
                        sda_drive_low <= 0;
                        scl_follow <= 0;
                        tick_en <= 0;
                        tickCounter <= 0;
                        num_data_bytes <= DATA_BYTES - 1;
                        updateState <= 0;
                    end
                end

                else if (updateState) begin
                    updateState <= 0;
                    state <= nextState;
                    counter <= 7;
                end
            end

            9: begin
                
                if (updateState == 1 && i2c_tick_parity == 0) begin
                    state <= nextState;
                    counter <= 7;
                    updateState <= 0;
                    if (nextState == 10)
                        sda_drive_low <= 1; // ACK
                    else begin
                        sda_drive_low <= 0; // NACK
                    end
                end

                else if (i2c_tick_parity) begin 
                    // read and store data
                    sensor_data[num_data_bytes*8+counter] <= i2c.sda_i;
                    if (counter == 0) begin
                        counter <= 7; // reset counter
                        updateState <= 1;
                        if (num_data_bytes == 0) begin 
                            // all data received -> send NACK then STOP
                            nextState <= 11;
                        end
                        else begin
                            // more data to receive -> send ACK then come back to this state
                            nextState <= 10;
                            num_data_bytes <= num_data_bytes-1;
                            
                        end
                    end else 
                        counter <= counter - 1;
                end
                
            end

            10: begin
                // wait out ACK then go back to 9
                if (!i2c_tick_parity) begin 
                    sda_drive_low <= 0; // release SDA to prep for reading
                    state <= 9;
                end
            end

            11: begin
                // wait out the NACK and then send STOP

                // first low phase: pull SDA low while SCL is low to prepare STOP
                if (!updateState && !i2c_tick_parity) begin
                    sda_drive_low <= 1;
                    updateState <= 1;
                end

                // high phase: release SDA while SCL is high -> STOP condition
                else if (updateState && i2c_tick_parity) begin
                    sda_drive_low <= 0;
                    updateState <= 0;
                    done <= 1;
                    state <= 0;
                    scl_follow <= 0;
                    tick_en <= 0;
                    tickCounter <= 156;
                    num_data_bytes <= DATA_BYTES - 1;
                    done_read_ts <= timestamp;
                end
            end

        endcase
    end

end


endmodule
