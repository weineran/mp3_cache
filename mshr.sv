import lc3b_types::*;

module mshr
(
	input clk,load_addr,load_word,load_line,port_index,inc_cur_ptr,
	input lc3b_word wdata,
	input lc3b_word[1:0] addr_in,
	input lc3b_mem_wmask[1:0] byte_en,
	input lc3b_32bytes line_data_in,
	output logic dirty_out,full,waiting_out,
	output logic [1:0] hit,addr_hit,
	output lc3b_word[1:0] rdata_out,
	output lc3b_32bytes line_data_out,
	output lc3b_mpnc_tag tag_out
);
//register start
logic [3:0] empty_ptr,cur_ptr;
lc3b_32bytes[15:0] data;
lc3b_mpnc_tag[15:0] tag;
logic [15:0] valid,dirty,waiting;
lc3b_32bits[15:0] occupied;
//register end
logic [3:0] target_ptr,hit_ptr;
logic hit_sig;
logic [1:0][15:0] tag_hit;
logic [1:0][3:0] hit_index;

assign full = (empty_ptr+4'd1==cur_ptr);
assign dirty_out = dirty[cur_ptr];
assign hit_sig = addr_hit[port_index];
assign hit_ptr = (port_index) ? hit_index[1] : hit_index[0];
assign target_ptr = (hit_sig) ? hit_ptr : empty_ptr;
assign addr_hit[0]=valid[hit_index[0]] & (tag_hit[0]!=16'd0);
assign addr_hit[1]=valid[hit_index[1]] & (tag_hit[1]!=16'd0);
assign hit[0]=addr_hit[0] & (occupied[hit_index[0]][ addr_in[0][4:1]*2 +: 2 ]==2'b11);
assign hit[1]=addr_hit[1] & (occupied[hit_index[1]][ addr_in[1][4:1]*2 +: 2 ]==2'b11);
//assign hit[0]=valid[hit_index[0]] && (tag_hit[0]!=16'd0) && (occupied[hit_index[0]][ hit_index[0]*2 +: 2 ]==2'b11);
//assign hit[1]=valid[hit_index[1]] && (tag_hit[1]!=16'd0) && (occupied[hit_index[1]][ hit_index[1]*2 +: 2 ]==2'b11);
assign rdata_out[0]=data[hit_index[0]][ addr_in[0][4:1]*16 +: 16 ];
assign rdata_out[1]=data[hit_index[1]][ addr_in[1][4:1]*16 +: 16 ];
assign line_data_out=data[cur_ptr];
assign tag_out=tag[cur_ptr];
assign waiting_out = waiting[cur_ptr];

always_comb
begin
	for(int i=0;i<16;i=i+1)
	begin
		tag_hit[0][i]=(tag[i]==addr_in[0][15:5]) & valid[i];
		tag_hit[1][i]=(tag[i]==addr_in[1][15:5]) & valid[i];
	end
end

always_ff @ (posedge clk)
begin
	if(load_line)begin
		for(int i=0;i<32;i=i+1)
		begin
			data[cur_ptr][i*8 +: 8] = (occupied[cur_ptr][i]==1'b1) ? data[cur_ptr][i*8 +: 8] : line_data_in[i*8 +: 8];
		end
		occupied[cur_ptr]<=32'hFFFFFFFF;
		waiting[cur_ptr]<=1'b0;
	end
	else if(load_addr)begin
		valid[empty_ptr]<=1'b1;
		tag[empty_ptr]<=addr_in[port_index][15:5];
		occupied[empty_ptr]<=32'd0;
		data[empty_ptr]<=256'd15;//testing purpose
		dirty[empty_ptr]<=1'b0;
		waiting[empty_ptr]<=1'b1;
		empty_ptr <= empty_ptr + 4'b1;
	end
	else if(load_word)begin
		valid[target_ptr]<=1'b1;
		tag[target_ptr]<=addr_in[port_index][15:5];
		dirty[target_ptr]<=1'b1;
		waiting[target_ptr]<=1'b1;
		occupied[target_ptr][(addr_in[port_index][4:1])*2 +: 2] <= occupied[target_ptr][(addr_in[port_index][4:1])*2 +: 2] | byte_en[port_index];
		data[target_ptr][(addr_in[port_index][4:1])*16 +: 8] <= (byte_en[port_index][0]) ? wdata[7:0] : data[target_ptr][(addr_in[port_index][4:1])*16 +: 8];
		data[target_ptr][((addr_in[port_index][4:1])*16)+8 +: 8] <= (byte_en[port_index][1]) ? wdata[15:8] : data[target_ptr][((addr_in[port_index][4:1])*16)+8 +: 8];
/*		for(int i=0;i<16;i=i+1)
		begin
//			occupied[target_ptr][i*2 +: 2]<= (addr_in[port_index][4:1]==i) ? occupied[target_ptr][i*2 +: 2] | byte_en[port_index] : occupied[target_ptr][i*2 +: 2];
			data[target_ptr][i*16 +: 8] <= (occupied[target_ptr][i*2] & addr_in[port_index][4:1]==i) ? wdata[7:0] : wdata[7:0]|data[target_ptr][i*16 +: 8];
			data[target_ptr][(i*16)+8 +: 8] <= (occupied[target_ptr][(i*2)+1] & addr_in[port_index][4:1]==i) ? wdata[15:8] : wdata[15:8]|data[target_ptr][(i*16)+8 +: 8];
		end*/
		empty_ptr <= (hit_sig) ? empty_ptr : empty_ptr+4'b1;
	end
	else if(inc_cur_ptr)begin
		valid[cur_ptr] <= 1'b0;
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
	for (int i = 0; i < $size(valid); i++)
	begin
		valid[i] = 1'b0;
	end
	for (int i = 0; i < $size(dirty); i++)
	begin
		dirty[i] = 1'b0;
	end
	for (int i = 0; i < $size(waiting); i++)
	begin
		waiting[i] = 1'b0;
	end
	for (int i = 0; i < $size(occupied); i++)
	begin
		occupied[i] = 1'b0;
	end
	cur_ptr = 4'd0;
	empty_ptr = 4'd0;
end

endmodule

