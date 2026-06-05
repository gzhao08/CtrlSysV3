/* 
Name: Gordon Zhao
File: packetizer.sv
Description: takes the data from I2C_controller and organizes into a packet

A word is 32 bits/4 bytes:

Word 0: packet_out[31:0]    = timestamp[31:0]
Word 1: packet_out[63:32]   = timestamp[63:32]

Word 2: packet_out[95:64]   = sensor_id[15:0], flags[15:0]

Word 3: packet_out[127:96]  = ax[15:0], ay[15:0]
Word 4: packet_out[159:128] = az[15:0], mx[15:0]
Word 5: packet_out[191:160] = my[15:0], mz[15:0]
Word 6: packet_out[223:192] = gx[15:0], gy[15:0]
Word 7: packet_out[255:224] = gz[15:0], sample_counter[15:0]

ffff0001ffffffffffffffffffffffffffffffff0001000100000000 0000 ea3d
*/

module packetizer (
    input  logic         clk,
    input  logic         rst,
    input  logic         start,

    input  logic [143:0] data,
    input  logic [63:0]  timestamp,

    input  logic [15:0]  sensor_id,
    input  logic [15:0]  flags,
    input  logic [15:0]  sample_counter,

    output logic [255:0] packet_out,
    output logic         done
);	



always_ff @(posedge clk) begin
    if (rst) begin
        packet_out <= 256'd0;
        done       <= 1'b0;
    end else begin
        done <= 1'b0;

        if (start) begin
            packet_out <= {
                data[15:0], sample_counter, // Word 7
                data[47:16],                // Word 6
                data[79:48],                // Word 5
                data[111:80],               // Word 4
                data[143:112],              // Word 3
                sensor_id, flags,           // Word 2
                timestamp[63:32],           // Word 1
                timestamp[31:0]             // Word 0
            };

            done <= 1'b1;
        end
    end
end

endmodule