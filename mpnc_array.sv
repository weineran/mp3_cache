import lc3b_types::*;

module mpnc_array #(parameter width = 256)
(
	input clk,load,
	input lc3b_dc_index load_index,
	input lc3b_dc_index[1:0] read_index,
	input [width-1:0] datain,
	output logic [1:0][width-1:0] dataout
);
logic [15:0][width-1:0] data;
assign dataout[0] = data[read_index[0]];//(load) ? data[load_index] : data[read_index[0]];
assign dataout[1] = data[read_index[1]];//(load) ? data[load_index] : data[read_index[1]];

always_ff @(posedge clk)
begin
    if (load == 1)
    begin
        data[load_index] = datain;
    end
end


initial
begin
    for (int i = 0; i < $size(data); i++)
    begin
        data[i] = 1'b0;
    end
end

endmodule





