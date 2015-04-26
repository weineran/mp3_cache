/* FILENAME: regfile.sv
 * CREATED: 3/14/15 by Andrew
 * MODIFIED: 3/14/15 by Andrew
 * DESCRIPTION: Similar to the regfile from mp1 and mp2 with the following differences:
 *              -We can read from all 8 registers at the same time (128-bit data out)
 *              -We can write to to registers at once (in case two operations finish on the same
 *               clock cycle) (6-bit regfile addr; 32 -bit regfile_wdata)
 */


import lc3b_types::*;

module regfile
(
    input clk,
    input [1:0] load,                       // 00 => don't load data; 01 => load on in0; 10 => load on in1; 11 => load on both in0 and in1
    input lc3b_reg addr_in0, addr_in1,      // two addresses for incoming data
    input lc3b_word in0, in1,               // two lines for incoming data
    output lc3b_word out [7:0]              // all 8 registers are available as outgoing data
);

lc3b_word data [7:0];
lc3b_word new_data [7:0];
/* Altera device registers are 0 at power on. Specify this
 * so that Modelsim works as expected.
 */
initial
begin
    for (int i = 0; i < $size(data); i++)
    begin
        data[i] = 16'b0;
    end
end

assign out[7:0] = data[7:0];
always_ff @(posedge clk)
begin
	data <= new_data;
end

always_comb
begin
	new_data = data;
    // 4 cases: load nothing; load in0; load in1; load both in0 and in1
    case(load)
        2'b00: begin
            ;   // do nothing
        end
        2'b01: begin
            new_data[addr_in0] = in0;   // load in0
        end
        2'b10: begin
            new_data[addr_in1] = in1;   // load in1
        end
        2'b11: begin
            // if both are writing to same address, later instruction trumps
            // so later instruction should always be writing to in1
            if(addr_in0 == addr_in1)
            begin
                new_data[addr_in1] = in1;   // load in1
            end
            // otherwise do both
            else
            begin
                new_data[addr_in0] = in0;   // load both in0...
                new_data[addr_in1] = in1;   // ...and in1
            end
            
        end
    endcase
end

endmodule : regfile
