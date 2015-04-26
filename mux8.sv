module mux8	#(parameter width = 16)
(
	input [2:0]	sel,
	input [width-1:0] a, b, c, d, e, g, h, i,
	output logic [width-1:0] f
);

always_comb
begin
if(sel==0)
	f=a;
else if(sel ==1)
	f=b;
else if(sel ==2)
	f=c;
else if(sel ==3)
	f=d;
else if(sel ==4)
	f=e;
else if(sel ==5)
	f=g;
else if(sel ==6)
	f=h;
else
	f=i;
end

endmodule : mux8
