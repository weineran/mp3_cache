module mux32 #(parameter width = 16)
(	input [4:0] sel,
	input [width-1:0] a0,a1,a2,a3,a4,a5,a6,a7,b0,b1,b2,b3,b4,b5,b6,b7,c0,c1,c2,c3,c4,c5,c6,c7,d0,d1,d2,d3,d4,d5,d6,d7,
	output logic [width-1:0] f
);
always_comb
begin
	case(sel)
		5'b00000: f = a0;
		5'b00001: f = a1;
		5'b00010: f = a2;
		5'b00011: f = a3;
		5'b00100: f = a4;
		5'b00101: f = a5;
		5'b00110: f = a6;
		5'b00111: f = a7;
		5'b01000: f = b0;
		5'b01001: f = b1;
		5'b01010: f = b2;
		5'b01011: f = b3;
		5'b01100: f = b4;
		5'b01101: f = b5;
		5'b01110: f = b6;
		5'b01111: f = b7;
		5'b10000: f = c0;
		5'b10001: f = c1;
		5'b10010: f = c2;
		5'b10011: f = c3;
		5'b10100: f = c4;
		5'b10101: f = c5;
		5'b10110: f = c6;
		5'b10111: f = c7;
		5'b11000: f = d0;
		5'b11001: f = d1;
		5'b11010: f = d2;
		5'b11011: f = d3;
		5'b11100: f = d4;
		5'b11101: f = d5;
		5'b11110: f = d6;
		5'b11111: f = d7;
		default: ;
	endcase
end
endmodule
