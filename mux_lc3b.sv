module mux_lc3b #(width = 16, size = 16, sel_width = 4)(
	input logic [sel_width-1:0] sel,
	input logic [width-1:0] in [size-1:0],
	output logic [width-1:0] out
);
always_comb
begin
	out = 0;
	for(int i =0; i< size; i++)
	begin
		if (sel == i)
		begin
			out = in[i];
		end
	end
end

endmodule : mux_lc3b