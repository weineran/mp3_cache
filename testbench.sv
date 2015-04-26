import lc3b_types::*;

module testbench();

timeunit 10ns;
timeprecision 1ns;

logic [31:0] count;
logic clk = 0;
//D-cache to cpu
logic[1:0] d_mem_resp;
lc3b_word[1:0] d_mem_rdata;
//cpu to D-cache
logic[1:0] d_mem_read;
logic[1:0] d_mem_write;
lc3b_word[1:0] d_mem_address;
lc3b_word[1:0] d_mem_wdata;
//lc3b_mem_wmask[1:0] d_mem_byte_enable;
//D-cache to L2    //  L2 to MEM
logic pmem_read,pmem_write;
lc3b_word pmem_address;
lc3b_32bytes pmem_wdata;
//L2 to D-cache    //  MEM to L2
logic pmem_resp;
lc3b_32bytes pmem_rdata;
logic[1:0] rw,send;
lc3b_word[1:0] t_wdata,t_addr;


mpnc cache( .clk,
//D-cache to cpu
.d_mem_resp,//output
.d_mem_rdata,//output
//cpu to D-cache
.d_mem_read,//input
.d_mem_write,//input
.d_mem_address,//input
.d_mem_wdata,//input
.d_mem_byte_enable(4'hF),//input
//D-cache to L2    //  L2 to MEM
.pmem_read, .pmem_write,//output
.pmem_address,//output
.pmem_wdata,//output
//L2 to D-cache    //  MEM to L2
.pmem_resp,//input
.pmem_rdata//input
);

test_cpu cpu0( .clk(clk), .rw(rw[0]), .send(send[0]), .wdata_in(t_wdata[0]), .addr_in(t_addr[0]),
					.read(d_mem_read[0]), .write(d_mem_write[0]), .wdata_out(d_mem_wdata[0]), .addr_out(d_mem_address[0]), .resp(d_mem_resp[0]) );
test_cpu cpu1( .clk(clk), .rw(rw[1]), .send(send[1]), .wdata_in(t_wdata[1]), .addr_in(t_addr[1]),
					.read(d_mem_read[1]), .write(d_mem_write[1]), .wdata_out(d_mem_wdata[1]), .addr_out(d_mem_address[1]), .resp(d_mem_resp[1]) );
test_mem mem0( .clk(clk), .read(pmem_read), .write(pmem_write), .addr_in(pmem_address), .line_in(pmem_wdata), .resp(pmem_resp), .line_out(pmem_rdata) );



always_ff @ (posedge clk or negedge clk)
begin
	count = count + 32'd1;
end

always #1 clk=~clk;
always #1 if(send[0])begin
	#2		send[0] = 0;
end
always #1 if(send[1])begin
	#2		send[1] = 0;
end

initial begin
	count = 32'd0;
	rw = 2'b11;//1=read, 0=write
	send = 2'b00;
	t_wdata[0] = 16'd0;
	t_wdata[1] = 16'd0;
	t_addr[0] = 16'd0;
	t_addr[1] = 16'd0;
	
#6		t_addr[0] = 16'h2340;
#1		send[0] = 1;


#4		t_addr[1] = 16'h6002;
#1		send[1] = 1;

#38	t_addr[0] = 16'h0000;
		t_addr[1] = 16'h0002;
		t_wdata[0] = 16'h600d;
		t_wdata[1] = 16'hdddd;
		rw = 2'b00;
#1		send = 2'b11;		

#6		rw = 2'b11;
#1		send = 2'b11;//58

#13	send = 2'b11;//71


end

endmodule


