/* 
Name: Gordon Zhao
File: timekeep.sv
Description: a block for storing time
a 64 bit counter incrementing every 20ns (50MHz clock) would take > 10000 years to wrap
*/

module timekeep (
    input               clk,
    input               rst,
    input               enable,
    output logic [63:0] timestamp_counter
);	

always_ff @(posedge clk) begin
    if (rst)
        timestamp_counter <= 64'd0;
    else if (enable)
        timestamp_counter <= timestamp_counter + 1;
end

endmodule