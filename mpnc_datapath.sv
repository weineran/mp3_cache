//multiport nonblocking cache with max 256 bits data input output
import lc3b_types::*;

module mpnc_datapath(input clk,
							//D-cache to cpu
							output lc3b_word[1:0] d_mem_rdata,
							//cpu to D-cache    //  L1 to L2
							input lc3b_word[1:0] d_mem_address,
							input lc3b_word[1:0] d_mem_wdata,
							input lc3b_mem_wmask[1:0] d_mem_byte_enable,
							//D-cache to L2    //  L2 to MEM
							output lc3b_word pmem_address,
							output lc3b_32bytes pmem_wdata,
							//L2 to D-cache    //  MEM to L2
							input lc3b_32bytes pmem_rdata,
							//control to datapath
							input logic update_lru,load_wdata_tmp,rw_sel,lru_in,port_index,load_dirty_sel,
							input logic mshr_load_addr,mshr_load_word,mshr_load_line,inc_mshr_ptr,
							input logic rpb_load_line,rpb_load_word,inc_rpb_ptr,
							input logic [1:0] datain_sourcemux_sel,load_data,load_valid,load_dirty,dirty_in,//for future change to 4-way assoc.
							input logic [1:0][1:0] d_mem_rdata_sourcemux_sel,
							input logic wdata_portmux_sel,wdata_queuemux_sel,
							input logic [1:0] rdata_word_sourcemux_sel,load_index_sourcemux_sel,
							//datapath to control
							output logic [1:0] dirty0_out,dirty1_out,data0_hit,data1_hit,rpb_hit,mshr_hit,mshr_reading_tag,mshr_addr_hit,
							output logic mshr_dirty,mshr_full,rpb_full,mshr_wait,rpb_wait,port_tag_compare,lru_out
							);

lc3b_32bytes d_mem_rdata_sourcemux0_out,d_mem_rdata_sourcemux1_out,datain_sourcemux_out,mshr_line_data_out;
lc3b_32bytes rpb_line_data_out,rpb_line_data_in;
lc3b_mpnc_tag mshr_tag_out,rpb_tag_out,tagin_sourcemux_out,rpb_data_addr_in;
lc3b_word wdata_portmux_out,wdata_queuemux_out,wdata_tmp;
lc3b_word [1:0] mshr_rdata_out;
lc3b_32bytes[1:0] wdata_combined_line,data0_out,data1_out,rpb_rdata_out,wdata_combined_line_sig;
logic [1:0] compare_tag_way0,compare_tag_way1,valid_compare_port0,valid_compare_port1;
lc3b_mpnc_tag[1:0] tag_out_way0,tag_out_way1;
logic [3:0] load_index_sourcemux_out;

logic [1:0] valid0_out,valid1_out;
logic blank;

//just getting rid of warnings
//assign pmem_address[4:0]={{3{d_mem_address[0][0]}},{2{d_mem_address[1][0]}}};
//getting rid of warnings

//assign valid_compare_port0 = {(compare_tag_way1[0] & )};
//assign data0_hit[0] = valid0_out[0] & compare_tag_way0[0];
//assign data0_hit[1] = valid0_out[1] & compare_tag_way0[1];

assign wdata_combined_line_sig[0] = (data1_hit[0]) ? data1_out[0] : data0_out[0];
assign wdata_combined_line_sig[1] = (data1_hit[1]) ? data1_out[1] : data0_out[1];
assign d_mem_rdata[0] = (rdata_word_sourcemux_sel[0]) ? mshr_rdata_out [0] : d_mem_rdata_sourcemux0_out[(d_mem_address[0][4:1])*16 +: 16];
assign d_mem_rdata[1] = (rdata_word_sourcemux_sel[1]) ? mshr_rdata_out [1] : d_mem_rdata_sourcemux1_out[(d_mem_address[1][4:1])*16 +: 16];
assign wdata_portmux_out=(wdata_portmux_sel) ? d_mem_wdata[1] : d_mem_wdata[0];
assign wdata_queuemux_out=(wdata_queuemux_sel) ? wdata_tmp : wdata_portmux_out;
assign pmem_wdata = rpb_line_data_out;
assign pmem_address = (rw_sel) ? {mshr_tag_out,5'd0} : {rpb_tag_out,5'd0};//1=read,0=write
assign rpb_line_data_in = (lru_out) ? data1_out[0] : data0_out[0];
assign rpb_data_addr_in = (lru_out) ? tag_out_way1[0] : tag_out_way0[0];
assign port_tag_compare = (d_mem_address[0][15:5] == d_mem_address[1][15:5]);
assign mshr_reading_tag[0] = (d_mem_address[0][15:5] == pmem_address[15:5]);
assign mshr_reading_tag[1] = (d_mem_address[1][15:5] == pmem_address[15:5]);


always_ff @ (posedge clk)
begin
	if(load_wdata_tmp)begin
		wdata_tmp = d_mem_wdata[1];
	end
	else begin
		wdata_tmp = wdata_tmp;
	end
end

always_comb
begin
	for(int i=0;i<2;i=i+1)begin
		compare_tag_way0[i] = (tag_out_way0[i][10:4]==d_mem_address[i][15:9]);
		compare_tag_way1[i] = (tag_out_way1[i][10:4]==d_mem_address[i][15:9]);
	end
end

always_comb
begin
	for(int i=0;i<2;i=i+1)begin
		data0_hit[i] = valid0_out[i] & compare_tag_way0[i];
		data1_hit[i] = valid1_out[i] & compare_tag_way1[i];
	end
end

always_comb
begin
	for(int i=0;i<16;i=i+1)begin//this is wrong, wdata_combined_line at the back should be data in the cache, FIXED
		wdata_combined_line[0][i*16 +: 8]=((d_mem_address[0][4:1]==i) & d_mem_byte_enable[0][0]) ? d_mem_wdata[0][7:0] : wdata_combined_line_sig[0][i*16 +: 8];
		wdata_combined_line[0][(i*16)+8 +: 8]=((d_mem_address[0][4:1]==i) & d_mem_byte_enable[0][1]) ? d_mem_wdata[0][15:8] : wdata_combined_line_sig[0][(i*16)+8 +: 8];
		wdata_combined_line[1][i*16 +: 8]=((d_mem_address[1][4:1]==i) & d_mem_byte_enable[1][0]) ? d_mem_wdata[1][7:0] : wdata_combined_line_sig[1][i*16 +: 8];
		wdata_combined_line[1][(i*16)+8 +: 8]=((d_mem_address[1][4:1]==i) & d_mem_byte_enable[1][1]) ? d_mem_wdata[1][15:8] : wdata_combined_line_sig[1][(i*16)+8 +: 8];
	end
end

mux4 #( .width(256) )d_mem_rdata_sourcemux0
(	.sel(d_mem_rdata_sourcemux_sel[0]),
	.a(data0_out[0]),//data cache 0
	.b(data1_out[0]),//data cache 1
	.c(rpb_rdata_out[0]),//replacement_buffer
	.d(),//nothing for now
	.f(d_mem_rdata_sourcemux0_out)
);

mux4 #( .width(256) )d_mem_rdata_sourcemux1
(	.sel(d_mem_rdata_sourcemux_sel[1]),
	.a(data0_out[1]),//data cache 0
	.b(data1_out[1]),//data cache 1
	.c(rpb_rdata_out[1]),//replacement_buffer
	.d(),//nothing for now
	.f(d_mem_rdata_sourcemux1_out)
);

mux4 #( .width(4) )load_index_sourcemux
(	.sel(load_index_sourcemux_sel),
	.a(d_mem_address[0][8:5]),//port 0
	.b(d_mem_address[1][8:5]),//port 1
	.c(mshr_tag_out[3:0]),//mshr
	.d(rpb_tag_out[3:0]),//rpb
	.f(load_index_sourcemux_out)
);

mux4 #( .width(256) )datain_sourcemux
(	.sel(datain_sourcemux_sel),
	.a(wdata_combined_line[0]),//wdata port 0
	.b(wdata_combined_line[1]),//wdata port 1
	.c(mshr_line_data_out),//mshr
	.d(rpb_line_data_out),//replacement_buffer
	.f(datain_sourcemux_out)
);

mux4 #( .width(11) )tagin_sourcemux
(	.sel(datain_sourcemux_sel),//(tagin_sourcemux_sel),
	.a(d_mem_address[0][15:5]),//wdata port 0
	.b(d_mem_address[1][15:5]),//wdata port 1
	.c(mshr_tag_out),//mshr
	.d(rpb_tag_out),//replacement_buffer
	.f(tagin_sourcemux_out)
);

mshr mshr_queue
(
	.clk(clk), .load_addr(mshr_load_addr), .load_word(mshr_load_word), .load_line(mshr_load_line),
	.port_index(port_index),
	.inc_cur_ptr(inc_mshr_ptr),
	.wdata(wdata_queuemux_out),
	.addr_in(d_mem_address),
	.byte_en(d_mem_byte_enable),
	.line_data_in(pmem_rdata),
	.dirty_out(mshr_dirty), .full(mshr_full), .waiting_out(mshr_wait),
	.hit(mshr_hit), .addr_hit(mshr_addr_hit),
	.rdata_out(mshr_rdata_out),
	.line_data_out(mshr_line_data_out),
	.tag_out(mshr_tag_out)
);

replacement_buffer RPB
(
	.clk(clk), .load_word(rpb_load_word), .load_line(rpb_load_line),
	.port_index(port_index),
	.inc_cur_ptr(inc_rpb_ptr),
	.line_data_in(rpb_line_data_in),
	.addr_in(d_mem_address),
	.data_addr_in(rpb_data_addr_in),
	.wdata(wdata_queuemux_out),
	.byte_en(d_mem_byte_enable),
	.full(rpb_full), .waiting_out(rpb_wait),
	.hit(rpb_hit),
	.rdata_out(rpb_rdata_out),
	.line_data_out(rpb_line_data_out),
	.tag_out(rpb_tag_out)
);

mpnc_array #( .width(256) ) data0
(
	.clk(clk), .load(load_data[0]), .load_index(load_index_sourcemux_out),
	.read_index({d_mem_address[1][8:5],d_mem_address[0][8:5]}), .datain(datain_sourcemux_out), .dataout(data0_out)
);

mpnc_array #( .width(256) ) data1
(
	.clk(clk), .load(load_data[1]), .load_index(load_index_sourcemux_out),
	.read_index({d_mem_address[1][8:5],d_mem_address[0][8:5]}), .datain(datain_sourcemux_out), .dataout(data1_out)
);

mpnc_array #( .width(11) ) tag0
(
	.clk(clk), .load(load_data[0]), .load_index(load_index_sourcemux_out),
	.read_index({d_mem_address[1][8:5],d_mem_address[0][8:5]}), .datain(tagin_sourcemux_out), .dataout(tag_out_way0)
);

mpnc_array #( .width(11) ) tag1
(
	.clk(clk), .load(load_data[1]), .load_index(load_index_sourcemux_out),
	.read_index({d_mem_address[1][8:5],d_mem_address[0][8:5]}), .datain(tagin_sourcemux_out), .dataout(tag_out_way1)
);

mpnc_array #( .width(1) ) valid0
(
	.clk(clk), .load(load_valid[0]), .load_index(load_index_sourcemux_out),
	.read_index({d_mem_address[1][8:5],d_mem_address[0][8:5]}), .datain(1'b1), .dataout(valid0_out)
);

mpnc_array #( .width(1) ) valid1
(
	.clk(clk), .load(load_valid[1]), .load_index(load_index_sourcemux_out),
	.read_index({d_mem_address[1][8:5],d_mem_address[0][8:5]}), .datain(1'b1), .dataout(valid1_out)
);

mpnc_array #( .width(1) ) dirty0
(
	.clk(clk), .load(load_dirty[0]), .load_index(load_index_sourcemux_out),
	.read_index({d_mem_address[1][8:5],((load_dirty_sel) ? load_index_sourcemux_out : d_mem_address[0][8:5])}), .datain(dirty_in[0]), .dataout(dirty0_out)
);

mpnc_array #( .width(1) ) dirty1
(
	.clk(clk), .load(load_dirty[1]), .load_index(load_index_sourcemux_out),
	.read_index({d_mem_address[1][8:5],((load_dirty_sel) ? load_index_sourcemux_out : d_mem_address[0][8:5])}), .datain(dirty_in[1]), .dataout(dirty1_out)
);

mpnc_array #( .width(1) ) LRU
(
	.clk(clk), .load(update_lru), .load_index(load_index_sourcemux_out),
	.read_index({2{load_index_sourcemux_out}}), .datain(lru_in), .dataout({lru_out,blank})
);


endmodule

