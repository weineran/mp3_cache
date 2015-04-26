module test_cpu(
input logic clk,rw,send,//rw: 1=read, 0=write
input logic[15:0] wdata_in,addr_in,
output logic read,write,
output logic[15:0] wdata_out,addr_out,
input logic resp
);

enum int unsigned {standby,transmit} state, next_state;

always_comb
begin
	read = 1'b0;
	write = 1'b0;
	wdata_out = 16'd0;
	addr_out = 16'd0;
	case(state)
		transmit:begin
			read = rw;
			write = ~rw;
			wdata_out = wdata_in;
			addr_out = addr_in;
		end
		default: ;
	endcase
end

always_comb
begin
	next_state = state;
	case(state)
		standby:begin
			if(send)
				next_state = transmit;
			else
				next_state = standby;
		end
		transmit:begin
			if(resp)
				next_state = standby;
			else
				next_state = transmit;
		end
		default: ;
	endcase
end

always_ff @(posedge clk)
begin
	state <= next_state;
end

initial begin
	state <= standby;
end

endmodule

module test_mem(
input logic clk,read,write,
input logic[15:0] addr_in,
input logic[255:0] line_in,
output logic resp,
output logic[255:0] line_out
);

enum int unsigned {standby,waiting,send_back} state, next_state;
logic reset,inc;
logic [9:0] count;

always_ff @ (posedge clk)
begin
	if(reset)
		count <= 10'd0;
	else if(inc)
		count <= count + 10'd1;
	else
		count <= count;
end

always_comb
begin
	resp = 1'b0;
	reset = 1'b0;
	inc = 1'b0;
	line_out = 256'd0;
	case(state)
		standby:begin
			reset = 1'b1;
		end
		waiting:begin
			inc = 1'b1;
		end
		send_back:begin
			resp = 1'b1;
			case(addr_in)
				16'h2340: line_out = 256'd1;
				16'h6000: line_out = 256'h110030;
				16'h0000: line_out = 256'h0bad0bad0bad;
				default: ;
			endcase
		end
		default: ;
	endcase
end

always_comb
begin
	next_state = state;
	case(state)
		standby:begin
			if(read | write)
				next_state = waiting;
			else
				next_state = standby;
		end
		waiting:begin
			if(count == 10'd6)
				next_state = send_back;
			else
				next_state = waiting;
		end
		send_back:begin
			next_state = standby;
		end
		default: ;
	endcase
end

always_ff @(posedge clk)
begin
	state <= next_state;
end

initial begin
	state <= standby;
	count <= 10'd0;
end

endmodule
