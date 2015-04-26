import lc3b_types::*;

module mpnc_control
(
	input clk,
//D-cache to cpu
	output logic[1:0] d_mem_resp,
//cpu to D-cache
	input[1:0] d_mem_read,
	input[1:0] d_mem_write,
//D-cache to L2    //  L2 to MEM
	output logic pmem_read,pmem_write,
//L2 to D-cache    //  MEM to L2
	input logic pmem_resp,
//control to datapath
	output logic update_lru,load_wdata_tmp,rw_sel,lru_in,port_index,load_dirty_sel,
	output logic mshr_load_addr,mshr_load_word,mshr_load_line,inc_mshr_ptr,
	output logic rpb_load_line,rpb_load_word,inc_rpb_ptr,
	output logic [1:0] datain_sourcemux_sel,load_data,load_valid,load_dirty,dirty_in,//for future change to 4-way assoc.
	output logic [1:0][1:0] d_mem_rdata_sourcemux_sel,
	output logic wdata_portmux_sel,wdata_queuemux_sel,
	output logic [1:0] rdata_word_sourcemux_sel,load_index_sourcemux_sel,
//datapath to control
	input logic [1:0] dirty0_out,dirty1_out,data0_hit,data1_hit,rpb_hit,mshr_hit,mshr_reading_tag,mshr_addr_hit,
	input logic mshr_dirty,mshr_full,rpb_full,mshr_wait,rpb_wait,port_tag_compare,lru_out
);
enum int unsigned {standby,stall_p0,stall_p1,stall_p01,prep_stall_p01,bug,
						double_write,data_move} state, next_state;
logic [1:0] hit_port,load_data_sig;
logic mem_read_resp,prev_rw;

assign hit_port[0] = (data0_hit[0] | data1_hit[0] | rpb_hit[0] | mshr_hit[0]);
assign hit_port[1] = (data0_hit[1] | data1_hit[1] | rpb_hit[1] | mshr_hit[1]);
assign load_data_sig[0] = (d_mem_write[0] & data0_hit[0]) | ((~d_mem_write[0]) & d_mem_write[1] & data0_hit[1]);
assign load_data_sig[1] = (d_mem_write[0] & data1_hit[0]) | ((~d_mem_write[0]) & d_mem_write[1] & data1_hit[1]);

assign mem_read_resp = pmem_resp & rw_sel;

mpnc_arbiter arbiter(.mem_resp(pmem_resp), .rpb_wait, .rw_sel, .prev_rw);//1=read,0=write

always_comb
begin
	d_mem_resp=2'b00;//port 1, port 0
	pmem_read=1'b0;//read signal to MEM
	pmem_write=1'b0;//write signal to MEM
	update_lru=1'b0;
	lru_in=1'b0;//data_in for LRU
	load_wdata_tmp=1'b0;//usually used in the case of double_write
	//rw_sel=1'b0;
	port_index=1'b0;//used for mshr and rpb to determine which port should be used for loading
	mshr_load_addr=1'b0;//load mshr addr only, will inc empty ptr, mark "waiting" to be processed
	mshr_load_word=1'b0;//load mshr addr and word, will inc empty ptr, mark "waiting" to be processed
	mshr_load_line=1'b0;//load mshr line, unmark "waiting"
	inc_mshr_ptr=1'b0;//inc cur_ptr in mshr by 1, and clear current line in mshr
	rpb_load_line=1'b0;//load rpb line, will inc empty ptr, mark "waiting" to be processed
	rpb_load_word=1'b0;//update part of line in rpb without changing anything else
	inc_rpb_ptr=1'b0;//inc cur_ptr in rpb by 1
	datain_sourcemux_sel=2'b00;//data_in for cache way 0 and 1,
	//select: 2'b00: wdata port 0, 2'b01: wdata port 1, 2'b10: mshr, 2'b11: rpb
	load_data=2'b00;//load cache, [0]: way 0, [1]: way 1
	load_valid=2'b00;//load valid bit, [0]: way 0, [1]: way 1
	load_dirty=2'b00;//load dirty bit, [0]: way 0, [1]: way 1
	dirty_in=2'b00;//data_in for dirty bit, [0]: way 0, [1]: way 1
	load_dirty_sel=1'b0;
	d_mem_rdata_sourcemux_sel=4'h0;//choose where rdata sig(256 bits) for each port comes from
	//format [1:0][1:0], 2bit sel, [0]: port 0, [1]: port 1
	//select: 2'b00: data cache 0, 2'b01: data cache 1, 2'b10: rpb
	rdata_word_sourcemux_sel=2'b00;//choose where rdata sig( 16 bits) for each port comes from
	//1bit sel, [0]: port 0, [1]: port 1
	//select: 1'b0: sourcemux_out from above, 1'b1: mshr
	wdata_portmux_sel=1'b0;//pick which port of wdata is going to be used
	//select: 1'b0: port 0, 1'b1: port 1, default: port 0
	wdata_queuemux_sel=1'b0;//pick which port of wdata is going to be used in case of double_write
	//select: 1'b0: output from port mux above, 1'b1: tmp reg(should only be used in case of double_write)
	load_index_sourcemux_sel=2'b00;//pick where the set # of cache should be loading is coming from
	//select: 2'b00: port 0, 2'b01: port 1, 2'b10: mshr, 2'b11: rpb
	case(state)
		standby:begin
			//port 0, data flow specific
			//						read OR write is HIGH					HIGH IF NO Read Missed
			d_mem_resp[0] = (d_mem_read[0] | d_mem_write[0]) & (~d_mem_read[0] | hit_port[0]);
			//read								mshr_hit					hit anything else
			rdata_word_sourcemux_sel[0] = mshr_hit[0] & (~(data1_hit[0] | data0_hit[0] | rpb_hit[0]));//picking 16 bits
			//read													rpb_hit		NO rpb_hit, hit data,  don't care the value of this sel otherwise
			d_mem_rdata_sourcemux_sel[0] = (rpb_hit[0]) ? 2'b10 : {1'b0,data1_hit[0]};//picking 256 bits
			//port 1, data flow specific
			//						read OR write is HIGH					HIGH IF NO Read Missed
			d_mem_resp[1] = (d_mem_read[1] | d_mem_write[1]) & (~d_mem_read[1] | hit_port[1]) & (~d_mem_write[0]);
			//read								mshr_hit					hit anything else
			rdata_word_sourcemux_sel[1] = mshr_hit[1] & (~(data1_hit[1] | data0_hit[1] | rpb_hit[1]));//picking 16 bits
			//read													rpb_hit		NO rpb_hit, hit data,  don't care the value of this sel otherwise
			d_mem_rdata_sourcemux_sel[1] = (rpb_hit[1]) ? 2'b10 : {1'b0,data1_hit[1]};//picking 256 bits
			//WRITE, data flow specific
			//write			using w/e from port 1 iff w0=0,w1=1, port 0 otherwise
			port_index = ((~d_mem_write[0]) & d_mem_write[1]);
			//write			let port 1 through iff w0=0,w1=1, port 0 otherwise
			wdata_portmux_sel = ((~d_mem_write[0]) & d_mem_write[1]);
			//write			wdata tmp register will never be used in this state
			wdata_queuemux_sel = 1'b0;
			//write			let port 1 through iff w0=0,w1=1, port 0 otherwise
			datain_sourcemux_sel[1] = 1'b0;
			datain_sourcemux_sel[0] = ((~d_mem_write[0]) & d_mem_write[1]);
			//write			let port 1 through iff w0=0,w1=1, port 0 otherwise
			load_index_sourcemux_sel[1] = 1'b0;
			load_index_sourcemux_sel[0] = ((~d_mem_write[0]) & d_mem_write[1]);
			//STATUS specific
			//		only need to care "only hit_way0" & "only hit_way1", don't update otherwise
			lru_in = (data0_hit[0] | data0_hit[1]);
			//testing
			dirty_in[0] = load_data_sig[0];
			dirty_in[1] = load_data_sig[1];
			//To MEM specific, rw_sel: 1:read, 0:write
			pmem_read = rw_sel & mshr_wait;
			pmem_write = (~rw_sel) & rpb_wait;
			//LOADING specific, discuss case by case
			//general
			//		only need to care "only hit_way0" & "only hit_way1", don't update otherwise
			update_lru = ((data0_hit[0] | data0_hit[1]) ^ (data1_hit[0] | data1_hit[1]));
			//		load iff "both" port want to "write to diff addr"
			load_wdata_tmp = d_mem_write[0] & d_mem_write[1] & (~port_tag_compare);
			//		load if			"p0 write hit way 0"		or		"p0 not write, p1 write hit way 0"
			load_data[0] = load_data_sig[0];
			load_dirty[0] = load_data_sig[0];
			//		load if			"p0 write hit way 1"		or		"p0 not write, p1 write hit way 1"
			load_data[1] = load_data_sig[1];
			load_dirty[1] = load_data_sig[1];
			//there shouldn't be any case that valid bits need to be updated here
			load_valid = 2'b00;
			//mshr, priority: line > addr > word > inc_ptr, no need to consider simultaneous loads due to this priority
			//		load if mem_read is coming in, stall everything else, so above signals might not be finished
			mshr_load_line = mem_read_resp;
			//		load if either port read missed
			mshr_load_addr = (d_mem_read[0] & (~hit_port[0])) | (d_mem_read[1] & (~hit_port[1]));
			//		load if either port write missed
			mshr_load_word = (d_mem_write[0] & (~hit_port[0])) | (d_mem_write[1] & (~hit_port[1]));
			//		shouldn't be any case that this would happen
			inc_mshr_ptr = 1'b0;
			//rpb, priority: line > word > inc_ptr
			//		will never load in this state since there won't be any eviction unless mshr is trying to send data to cache
			//		rpb_load_line "might" be high IFF 1 clk cycle after mshr_load_line;
			rpb_load_line = 1'b0;
			rpb_load_word = (d_mem_write[0] & rpb_hit[0]) | ((~d_mem_write[0]) & d_mem_write[1] & rpb_hit[1]);
			inc_rpb_ptr = 1'b0;
		end
		stall_p0:begin//port 0 is bound to Read/Missed
			//port 1, data flow specific
			//															read OR write is HIGH					HIGH IF NO Read Missed
			d_mem_resp[1] = (mem_read_resp) ? 1'b0 : (d_mem_read[1] | d_mem_write[1]) & (~d_mem_read[1] | hit_port[1]);
			//read								mshr_hit					hit anything else
			rdata_word_sourcemux_sel[1] = mshr_hit[1] & (~(data1_hit[1] | data0_hit[1] | rpb_hit[1]));//picking 16 bits
			//read													rpb_hit		NO rpb_hit, hit data,  don't care the value of this sel otherwise
			d_mem_rdata_sourcemux_sel[1] = (rpb_hit[1]) ? 2'b10 : {1'b0,data1_hit[1]};//picking 256 bits
			//WRITE, data flow specific
			//write		bound to port 1
			port_index = 1'b1;
			wdata_portmux_sel = 1'b1;
			//write			bound to port 1 for now, but need to consider the case when hitting rpb
			datain_sourcemux_sel[1] = 1'b0;
			datain_sourcemux_sel[0] = 1'b1;
			//write			bound to port 1 for now, but need to consider the case when hitting rpb
			load_index_sourcemux_sel[1] = 1'b0;
			load_index_sourcemux_sel[0] = 1'b1;
			//STATUS specific
			//		only need to care "only hit_way0" & "only hit_way1", don't update otherwise
			lru_in = data0_hit[1];
			//don't care if it's read or write, hit = dirty, don't update it if it's not write
			dirty_in[0] = data0_hit[1];
			dirty_in[1] = data1_hit[1];
			//To MEM specific
			pmem_read = rw_sel & mshr_wait;
			pmem_write = (~rw_sel) & rpb_wait;
			//LOADING specific
			//		only need to care "only hit_way0" & "only hit_way1" using port 1
			update_lru = ((data0_hit[1]) ^ (data1_hit[1]));
			//		load if		"p1 write hit way 0"
			load_data[0] = d_mem_write[1] & data0_hit[1];
			load_dirty[0] = d_mem_write[1] & data0_hit[1];
			//		load if		"p1 write hit way 1"
			load_data[1] = d_mem_write[1] & data1_hit[1];
			load_dirty[1] = d_mem_write[1] & data1_hit[1];
			//mshr, priority: line > addr > word > inc_ptr
			//		load if mem_read is coming in regardless if it's currently waiting Read Miss port or not, stall everything else
			mshr_load_line = mem_read_resp;
			//		load if port 1 read missed
			mshr_load_addr = (~mshr_addr_hit[0]) | (d_mem_read[1] & (~hit_port[1]) & (~mshr_addr_hit[1]));
			//		load if port 1 write missed
			mshr_load_word = (d_mem_write[1] & (~(data0_hit[1] | data1_hit[1] | rpb_hit[1])));
			//rpb, priority: line > word > inc_ptr
			rpb_load_word = (d_mem_write[1] & rpb_hit[1]);
		end
		stall_p1:begin//port 1 is bound to Read/Missed
			//port 0, data flow specific
			//															read OR write is HIGH					HIGH IF NO Read Missed
			d_mem_resp[0] = (mem_read_resp) ? 1'b0 : (d_mem_read[0] | d_mem_write[0]) & (~d_mem_read[0] | hit_port[0]);
			//read								mshr_hit					hit anything else
			rdata_word_sourcemux_sel[0] = mshr_hit[0] & (~(data1_hit[0] | data0_hit[0] | rpb_hit[0]));//picking 16 bits
			//read													rpb_hit		NO rpb_hit, hit data,  don't care the value of this sel otherwise
			d_mem_rdata_sourcemux_sel[0] = (rpb_hit[0]) ? 2'b10 : {1'b0,data1_hit[0]};//picking 256 bits
			//WRITE, data flow specific
			//write		bound to port 0
			port_index = 1'b0;
			wdata_portmux_sel = 1'b0;
			//write			bound to port 0 for now, but need to consider the case when hitting rpb
			datain_sourcemux_sel[1] = 1'b0;
			datain_sourcemux_sel[0] = 1'b0;
			//write			bound to port 0 for now, but need to consider the case when hitting rpb
			load_index_sourcemux_sel[1] = 1'b0;
			load_index_sourcemux_sel[0] = 1'b0;
			//STATUS specific
			//		only need to care "only hit_way0" & "only hit_way1", don't update otherwise
			lru_in = data0_hit[0];
			//don't care if it's read or write, hit = dirty, don't update it if it's not write
			dirty_in[0] = data0_hit[0];
			dirty_in[1] = data1_hit[0];
			//To MEM specific
			pmem_read = rw_sel & mshr_wait;
			pmem_write = (~rw_sel) & rpb_wait;
			//LOADING specific
			//		only need to care "only hit_way0" & "only hit_way1" using port 0
			update_lru = ((data0_hit[0]) ^ (data1_hit[0]));
			//		load if			"p0 write hit way 0"
			load_data[0] = d_mem_write[0] & data0_hit[0];
			load_dirty[0] = d_mem_write[0] & data0_hit[0];
			//		load if			"p0 write hit way 1"
			load_data[1] = d_mem_write[0] & data1_hit[0];
			load_dirty[1] = d_mem_write[0] & data1_hit[0];
			//mshr, priority: line > addr > word > inc_ptr
			//		load if mem_read is coming in regardless if it's currently waiting Read Miss port or not, stall everything else
			mshr_load_line = mem_read_resp;
			//		load if port 0 read missed and requested addr is not in the mshr queue already
			mshr_load_addr = (~mshr_addr_hit[1]) | (d_mem_read[0] & (~hit_port[0]) & (~mshr_addr_hit[0]));
			//		load if port 0 write missed
			mshr_load_word = (d_mem_write[0] & (~(data0_hit[0] | data1_hit[0] | rpb_hit[0])));
			//rpb, priority: line > word > inc_ptr
			rpb_load_word = (d_mem_write[0] & rpb_hit[0]);
		end
		stall_p01:begin//port 0 & 1 are bound to Read/Missed, load data into mshr back from MEM, don't load if it's MW back
			//To MEM specific, rw_sel: 1:read, 0:write
			//maintain MEM signals since it's either read or write
			pmem_read = rw_sel & mshr_wait;
			pmem_write = (~rw_sel) & rpb_wait;
			//LOADING specific
			//mshr, priority: line > addr > word > inc_ptr
			mshr_load_line = mem_read_resp;
		end
		prep_stall_p01:begin//load another addr to mshr in case of double Read Missed at the same edge since only 1 write is allowed per edge
			port_index = mshr_addr_hit[0];
			//To MEM specific, rw_sel: 1:read, 0:write
			pmem_read = rw_sel & mshr_wait;
			pmem_write = (~rw_sel) & rpb_wait;
			//LOADING specific
			//mshr, priority: line > addr > word > inc_ptr
			mshr_load_line = mem_read_resp;
			//		load if either port read missed
			mshr_load_addr = (d_mem_read[0] & (~hit_port[0])) | (d_mem_read[1] & (~hit_port[1]));
		end
		data_move:begin//only deal with inc rpb/mshr ptr, loading mshr into cache, evict cache into rpb if needed
			//port 0, data flow specific
			//						read addr at port 0
			d_mem_resp[0] = mshr_reading_tag[0];
			//read					bound to mshr
			rdata_word_sourcemux_sel[0] = 1'b1;
			//port 1, data flow specific
			//						read OR write is HIGH					HIGH IF NO Read Missed
			d_mem_resp[1] = mshr_reading_tag[1];
			//read					bound to mshr
			rdata_word_sourcemux_sel[1] = 1'b1;
			//WRITE, data flow specific
			//write			get dirty bit of the loading set
			load_dirty_sel = 1'b1;
			//write				bound to mshr
			datain_sourcemux_sel = 2'b10;
			load_index_sourcemux_sel = 2'b10;
			//STATUS specific
			//		flip lru
			lru_in = ~lru_out;
			//			send mshr dirty bit
			dirty_in[0] = mshr_dirty;
			dirty_in[1] = mshr_dirty;
			//LOADING specific, discuss case by case
			//		have to update,if it's Read back
			update_lru = rw_sel;
			load_data[lru_in] = rw_sel;
			load_dirty[lru_in] = rw_sel;
			load_valid[lru_in] = rw_sel;
			//mshr
			inc_mshr_ptr = rw_sel;
			//rpb
			rpb_load_line = (lru_out) ? rw_sel & dirty1_out[0] : rw_sel & dirty0_out[0];
			inc_rpb_ptr = ~rw_sel;
		end
		double_write:begin//load port 1 which is bound to write
			//port 0 should have been taken care of, nothing about port 0 should be done in this state
			//port 1, data flow specific
			//						write is HIGH
			d_mem_resp[1] = d_mem_write[1];
			//read								mshr_hit					hit anything else
			rdata_word_sourcemux_sel[1] = mshr_hit[1] & (~(data1_hit[1] | data0_hit[1] | rpb_hit[1]));//picking 16 bits
			//read													rpb_hit		NO rpb_hit, hit data,  don't care the value of this sel otherwise
			d_mem_rdata_sourcemux_sel[1] = (rpb_hit[1]) ? 2'b10 : {1'b0,data1_hit[1]};//picking 256 bits
			//WRITE, data flow specific
			//write	bound to port 1
			port_index = 1'b1;
			wdata_portmux_sel = 1'b1;
			datain_sourcemux_sel = 2'b01;
			load_index_sourcemux_sel = 2'b01;
			//STATUS specific
			//		only need to care "only hit_way0" & "only hit_way1", don't update otherwise
			lru_in = data0_hit[1];
			//		bound to dirty, pick loading or not
			dirty_in[0] = 1'b1;
			dirty_in[1] = 1'b1;
			//To MEM specific, rw_sel: 1:read, 0:write
			pmem_read = rw_sel & mshr_wait;
			pmem_write = (~rw_sel) & rpb_wait;
			//LOADING specific
			//		only need to care "only hit_way0" & "only hit_way1", don't update otherwise
			update_lru = ((data0_hit[0] | data0_hit[1]) ^ (data1_hit[0] | data1_hit[1]));
			//		load if			"p0 write hit way 0"		or		"p0 not write, p1 write hit way 0"
			load_data[0] = data0_hit[1];
			load_dirty[0] = data0_hit[1];
			//		load if			"p0 write hit way 1"		or		"p0 not write, p1 write hit way 1"
			load_data[1] = data1_hit[1];
			load_dirty[1] = data1_hit[1];
			//mshr, priority: line > addr > word > inc_ptr, no need to consider simultaneous loads due to this priority
			//		load if mem_read is coming in, stall everything else, so above signals might not be finished
			mshr_load_line = mem_read_resp;
			//		load if port 1 write missed
			mshr_load_word = (d_mem_write[1] & (~hit_port[1]));
			//rpb, priority: line > word > inc_ptr
			rpb_load_word = ((~d_mem_write[0]) & d_mem_write[1] & rpb_hit[1]);
		end
		default: ;
	endcase
end

always_comb
begin
	next_state = state;
	case(state)
		standby:begin
			if(pmem_resp)
				next_state = data_move;
			else begin
				case( {d_mem_read[0],d_mem_write[0],hit_port[0],d_mem_read[1],d_mem_write[1],hit_port[1]} )
					6'b000000: next_state = standby;
					6'b000001: next_state = standby;
					6'b000010: next_state = standby;
					6'b000011: next_state = standby;
					6'b000100: next_state = stall_p1;
					6'b000101: next_state = standby;
					6'b001000: next_state = standby;
					6'b001001: next_state = standby;
					6'b001010: next_state = standby;
					6'b001011: next_state = standby;
					6'b001100: next_state = stall_p1;
					6'b001101: next_state = standby;
					6'b010000: next_state = standby;
					6'b010001: next_state = standby;
					6'b010010: next_state = double_write;
					6'b010011: next_state = double_write;
					6'b010100: next_state = stall_p1;
					6'b010101: next_state = standby;
					6'b011000: next_state = standby;
					6'b011001: next_state = standby;
					6'b011010: next_state = double_write;
					6'b011011: next_state = double_write;
					6'b011110: next_state = stall_p1;
					6'b011101: next_state = standby;
					6'b100000: next_state = stall_p0;
					6'b100001: next_state = stall_p0;
					6'b100010: next_state = stall_p0;
					6'b100011: next_state = stall_p0;
					6'b100100: next_state = prep_stall_p01;
					6'b100101: next_state = stall_p0;
					6'b101000: next_state = standby;
					6'b101001: next_state = standby;
					6'b101010: next_state = standby;
					6'b101011: next_state = standby;
					6'b101100: next_state = stall_p1;
					6'b101101: next_state = standby;
					default: next_state = bug;
				endcase
			end
		end
		stall_p0:begin
			if(pmem_resp)
				next_state = data_move;
			else if(d_mem_read[1] & (~hit_port[1]))
				next_state = stall_p01;
			else
				next_state = stall_p0;
		end
		stall_p1:begin
			if(pmem_resp)
				next_state = data_move;
			else if(d_mem_read[0] & (~hit_port[0]))
				next_state = stall_p01;
			else
				next_state = stall_p1;
		end
		prep_stall_p01:begin
			if(pmem_resp)
				next_state = data_move;
			else
				next_state = stall_p01;
		end
		stall_p01:begin
			if(pmem_resp)
				next_state = data_move;
			else
				next_state = stall_p01;
		end
		data_move:begin
			case( {d_mem_read[0],hit_port[0],d_mem_read[1],hit_port[1]} )
				4'b0010: next_state = stall_p1;
				4'b0110: next_state = stall_p1;
				4'b1000: next_state = stall_p0;
				4'b1001: next_state = stall_p0;
				4'b1010: next_state = stall_p01;
				4'b1011: next_state = stall_p0;
				4'b1110: next_state = stall_p1;
				default: next_state = standby;
			endcase
		end
		double_write:begin
			if(pmem_resp)
				next_state = data_move;
			else
				next_state = standby;
		end
		bug:begin
			next_state = bug;
		end
		default: next_state = standby;
	endcase
end

always_ff @ (posedge clk)
begin
	state <= next_state;
end

initial
begin
	state <= standby;
end

endmodule
/*
standby:begin
			case( {d_mem_read[0],d_mem_write[0],hit_port[0],d_mem_read[1],d_mem_write[1],hit_port[1],pmem_resp} )
				7'b0001000: next_state = stall_p1;
				7'b0100100: next_state = double_write;
				7'b0100110: next_state = double_write;
				7'b0101000: next_state = stall_p1;
				7'b0110100: next_state = double_write;
				7'b0110110: next_state = double_write;
				7'b0111000: next_state = stall_p1;
				7'b1000000: next_state = stall_p0;
				7'b1000100: next_state = stall_p0;
				7'b1000110: next_state = stall_p0;
				7'b1001000: next_state = stall_p01;
				7'b1001010: next_state = stall_p0;
				7'b1011000: next_state = stall_p1;
				7'b0000001: next_state = data_move;
				7'b0000101: next_state = data_move;
				7'b0000111: next_state = data_move;
//				7'b0001001: next_state = 
				7'b0001011: next_state = data_move;
				7'b0100001: next_state = data_move;
				7'b0100101: next_state = data_move;
				7'b0100111: next_state = data_move;
//				7'b0101001
				7'b0101011: next_state = data_move;
				7'b0110001: next_state = data_move;
				7'b0110101: next_state = data_move;
				7'b0110111: next_state = data_move;
//				7'b0111001
				7'b0111011: next_state = data_move;
//				7'b1000001
//				7'b1000101
//				7'b1000111
//				7'b1001001
//				7'b1001011
				7'b1010001: next_state = data_move;
				7'b1010101: next_state = data_move;
				7'b1010111: next_state = data_move;
//				7'b1011001
				7'b1011011: next_state = data_move;
				default: next_state = standby;
			endcase
		end*/