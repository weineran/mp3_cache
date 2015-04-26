import lc3b_types::*;

module replacement_buffer
(
	input clk,load_word,load_line,port_index,inc_cur_ptr,
	input lc3b_32bytes line_data_in,
	input lc3b_word[1:0] addr_in,
	input lc3b_mpnc_tag data_addr_in,
	input lc3b_word wdata,
	input lc3b_mem_wmask[1:0] byte_en,
	output logic full, waiting_out,
	output logic [1:0] hit,
	output lc3b_32bytes[1:0] rdata_out,
	output lc3b_32bytes line_data_out,
	output lc3b_mpnc_tag tag_out
);
//register start
logic [3:0] empty_ptr,cur_ptr;
lc3b_32bytes[15:0] data;
lc3b_mpnc_tag[15:0] tag;
logic [15:0] valid, waiting;
//register end
logic [3:0] hit_ptr;
logic [1:0][15:0] tag_hit,addr_hit;
logic [1:0][3:0] hit_index;

assign full = (empty_ptr+4'd1==cur_ptr);
assign hit_ptr = (port_index) ? hit_index[1] : hit_index[0];
assign hit[0]=valid[hit_index[0]] && (tag_hit[0]!=16'd0);
assign hit[1]=valid[hit_index[1]] && (tag_hit[1]!=16'd0);
assign rdata_out[0]=data[hit_index[0]];
assign rdata_out[1]=data[hit_index[1]];
assign line_data_out=data[cur_ptr];
assign tag_out=tag[cur_ptr];
assign waiting_out = waiting[cur_ptr];

always_comb
begin
	for(int i=0;i<16;i=i+1)
	begin
		tag_hit[0][i]=(tag[i]==addr_in[0][15:5]);
		tag_hit[1][i]=(tag[i]==addr_in[1][15:5]);
	end
end

always_ff @ (posedge clk)
begin
	if(load_line)begin
		valid[empty_ptr]=1'b1;
		empty_ptr = empty_ptr + 4'b1;
		data[empty_ptr]=line_data_in;
		tag[empty_ptr]=data_addr_in;
		waiting[empty_ptr]=1'b1;
	end
	else if(load_word)begin
		for(int i=0;i<16;i=i+1)
		begin
			data[hit_ptr][i*16 +: 8] = (byte_en[port_index][0]==1'b1 && addr_in[port_index][4:1]==i) ? wdata[7:0] : data[hit_ptr][i*16 +: 8];
			data[hit_ptr][(i*16)+8 +: 8] = (byte_en[port_index][1]==1'b1 && addr_in[port_index][4:1]==i) ? wdata[15:8] : data[hit_ptr][(i*16)+8 +: 8];
		end
	end
	else if(inc_cur_ptr)begin//problem here
		waiting[cur_ptr]=1'b0;
	end
end

always_ff @ (posedge clk)
begin
	if(inc_cur_ptr)begin
		cur_ptr = cur_ptr + 4'b1;
	end
end

always_comb
begin
	case(tag_hit[0])
		16'h0001:hit_index[0]=4'd0;
		16'h0002:hit_index[0]=4'd1;
		16'h0004:hit_index[0]=4'd2;
		16'h0008:hit_index[0]=4'd3;
		16'h0010:hit_index[0]=4'd4;
		16'h0020:hit_index[0]=4'd5;
		16'h0040:hit_index[0]=4'd6;
		16'h0080:hit_index[0]=4'd7;
		16'h0100:hit_index[0]=4'd8;
		16'h0200:hit_index[0]=4'd9;
		16'h0400:hit_index[0]=4'd10;
		16'h0800:hit_index[0]=4'd11;
		16'h1000:hit_index[0]=4'd12;
		16'h2000:hit_index[0]=4'd13;
		16'h4000:hit_index[0]=4'd14;
		16'h8000:hit_index[0]=4'd15;
		default: hit_index[0]=4'd0;
	endcase
	case(tag_hit[1])
		16'h0001:hit_index[1]=4'd0;
		16'h0002:hit_index[1]=4'd1;
		16'h0004:hit_index[1]=4'd2;
		16'h0008:hit_index[1]=4'd3;
		16'h0010:hit_index[1]=4'd4;
		16'h0020:hit_index[1]=4'd5;
		16'h0040:hit_index[1]=4'd6;
		16'h0080:hit_index[1]=4'd7;
		16'h0100:hit_index[1]=4'd8;
		16'h0200:hit_index[1]=4'd9;
		16'h0400:hit_index[1]=4'd10;
		16'h0800:hit_index[1]=4'd11;
		16'h1000:hit_index[1]=4'd12;
		16'h2000:hit_index[1]=4'd13;
		16'h4000:hit_index[1]=4'd14;
		16'h8000:hit_index[1]=4'd15;
		default: hit_index[1]=4'd0;
	endcase
end

initial
begin
	for (int i = 0; i < $size(data); i++)
	begin
		data[i] = 1'b0;
	end
	for (int i = 0; i < $size(tag); i++)
	begin
		tag[i] = 1'b0;
	end
	for (int i = 0; i < $size(waiting); i++)
	begin
		waiting[i] = 1'b0;
	end
	for (int i = 0; i < $size(valid); i++)
	begin
		valid[i] = 1'b0;
	end
	cur_ptr = 4'd0;
	empty_ptr = 4'd0;
end

endmodule


