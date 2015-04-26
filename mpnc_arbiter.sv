module mpnc_arbiter
(	input mem_resp,rpb_wait,
	output logic rw_sel,prev_rw
);
logic[1:0] count;

always_comb
begin
	case(count)
		2'b10: prev_rw=~rpb_wait;
		default: prev_rw=1'b1;
	endcase
end

always_comb
begin
	case(count)
		2'b01: rw_sel=~rpb_wait;
		default: rw_sel=1'b1;
	endcase
end

always_ff @ (posedge mem_resp)
begin
	count = count + 2'd1;
	/*
	if(write_waiting)
		count = 2'd1;
	else
		count = count + 2'd1;*/
end

initial
begin
	count=2'd0;
end

endmodule

