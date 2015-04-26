module mux16 #(parameter width = 16)
(	input [3:0] sel,
	input [width-1:0] a0,a1,a2,a3,b0,b1,b2,b3,c0,c1,c2,c3,d0,d1,d2,d3,
	output logic [width-1:0] f
);
always_comb
begin
	case(sel)
		4'b0000: f = a0;
		4'b0001: f = a1;
		4'b0010: f = a2;
		4'b0011: f = a3;
		4'b0100: f = b0;
		4'b0101: f = b1;
		4'b0110: f = b2;
		4'b0111: f = b3;
		4'b1000: f = c0;
		4'b1001: f = c1;
		4'b1010: f = c2;
		4'b1011: f = c3;
		4'b1100: f = d0;
		4'b1101: f = d1;
		4'b1110: f = d2;
		4'b1111: f = d3;
		default: ;
	endcase
end
endmodule
