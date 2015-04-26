import lc3b_types::*;

module mpnc(input clk,
				//D-cache to cpu
				output logic[1:0] d_mem_resp,
				output lc3b_word[1:0] d_mem_rdata,
				//cpu to D-cache
				input[1:0] d_mem_read,
				input[1:0] d_mem_write,
				input lc3b_word[1:0] d_mem_address,
				input lc3b_word[1:0] d_mem_wdata,
				input lc3b_mem_wmask[1:0] d_mem_byte_enable,
				//D-cache to L2    //  L2 to MEM
				output logic pmem_read,pmem_write,
				output lc3b_word pmem_address,
				output lc3b_32bytes pmem_wdata,
				//L2 to D-cache    //  MEM to L2
				input logic pmem_resp,
				input lc3b_32bytes pmem_rdata
				);

logic update_lru,load_wdata_tmp,rw_sel,lru_in,port_index,port_tag_compare,lru_out,load_dirty_sel;
logic mshr_load_addr,mshr_load_word,mshr_load_line,inc_mshr_ptr;
logic rpb_load_line,rpb_load_word,inc_rpb_ptr;
logic [1:0] datain_sourcemux_sel,load_data,load_valid,load_dirty,dirty_in;
logic [1:0][1:0] d_mem_rdata_sourcemux_sel;
logic wdata_portmux_sel,wdata_queuemux_sel;
logic [1:0] rdata_word_sourcemux_sel,load_index_sourcemux_sel;
logic [1:0] dirty0_out,dirty1_out,data0_hit,data1_hit,rpb_hit,mshr_hit,mshr_reading_tag,mshr_addr_hit;
logic mshr_dirty,mshr_full,rpb_full,mshr_wait,rpb_wait;

mpnc_datapath datapath
(.clk(clk),
//D-cache to cpu
	.d_mem_rdata(d_mem_rdata),
//cpu to D-cache    //  L1 to L2
	.d_mem_address(d_mem_address),
	.d_mem_wdata(d_mem_wdata),
	.d_mem_byte_enable(d_mem_byte_enable),
	//D-cache to L2    //  L2 to MEM
	.pmem_address(pmem_address),
	.pmem_wdata(pmem_wdata),
	//L2 to D-cache    //  MEM to L2
	.pmem_rdata(pmem_rdata),
	//control to datapath
	.update_lru, .load_wdata_tmp, .rw_sel, .lru_in, .port_index, .load_dirty_sel,
	.mshr_load_addr, .mshr_load_word, .mshr_load_line, .inc_mshr_ptr,
	.rpb_load_line, .rpb_load_word, .inc_rpb_ptr,
	.datain_sourcemux_sel, .load_data, .load_valid, .load_dirty, .dirty_in,
	.d_mem_rdata_sourcemux_sel, .wdata_portmux_sel, .wdata_queuemux_sel, .rdata_word_sourcemux_sel,
	.load_index_sourcemux_sel,
	//datapath to control
	.dirty0_out, .dirty1_out, .data0_hit, .data1_hit, .rpb_hit, .mshr_hit, .mshr_reading_tag, .mshr_addr_hit,
	.mshr_dirty, .mshr_full, .rpb_full, .mshr_wait, .rpb_wait, .port_tag_compare, .lru_out
);

mpnc_control control
(
	.clk,
//D-cache to cpu
	.d_mem_resp,
//cpu to D-cache
	.d_mem_read,
	.d_mem_write,
//D-cache to L2    //  L2 to MEM
	.pmem_read, .pmem_write,
//L2 to D-cache    //  MEM to L2
	.pmem_resp,
//control to datapath
	.update_lru, .load_wdata_tmp, .rw_sel, .lru_in, .port_index, .load_dirty_sel,
	.mshr_load_addr, .mshr_load_word, .mshr_load_line, .inc_mshr_ptr,
	.rpb_load_line, .rpb_load_word, .inc_rpb_ptr,
	.datain_sourcemux_sel, .load_data, .load_valid, .load_dirty, .dirty_in,
	.d_mem_rdata_sourcemux_sel, .wdata_portmux_sel, .wdata_queuemux_sel, .rdata_word_sourcemux_sel,
	.load_index_sourcemux_sel,
//datapath to control
	.dirty0_out, .dirty1_out, .data0_hit(data0_hit), .data1_hit(data1_hit), .rpb_hit(rpb_hit), .mshr_hit(mshr_hit), .mshr_reading_tag, .mshr_addr_hit,
	.mshr_dirty, .mshr_full, .rpb_full, .mshr_wait, .rpb_wait, .port_tag_compare, .lru_out
);

endmodule


