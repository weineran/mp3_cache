package lc3b_types;

typedef logic [3:0] lc3b_if_id;
typedef logic [3:0] lc3b_reorder_id;
typedef logic [2:0] lc3b_rs_add_id;
typedef logic [2:0] lc3b_rs_ld_id;
typedef logic [1:0] lc3b_exec_hit;
typedef logic [2:0] lc3b_fetch_offset;

typedef logic [15:0] lc3b_word;
typedef logic  [7:0] lc3b_byte;

typedef logic 	[10:0] lc3b_offset11;
typedef logic  [8:0] lc3b_offset9;
typedef logic  [5:0] lc3b_offset6;

typedef logic	[4:0] lc3b_imm5;
typedef logic	[3:0] lc3b_imm4;
typedef logic 	[7:0] lc3b_trap_vec;

typedef logic  [2:0] lc3b_reg;
typedef logic  [2:0] lc3b_nzp;
typedef logic  [1:0] lc3b_mem_wmask;

typedef logic 	lc3b_index1;
typedef logic 	lc3b_index6;
typedef logic 	lc3b_index5;
typedef logic  lc3b_index12;

typedef logic 	[127:0] lc3b_mem_data;
typedef logic	[127:0] lc3b_16bytes;

//cache
typedef logic 	[2:0]	lc3b_c_index;
typedef logic 	[3:0]	lc3b_c_offset;
typedef logic 	[8:0]	lc3b_c_tag;

typedef logic 	[3:0]	lc3b_dc_index;
typedef logic 	[4:0]	lc3b_dc_offset;
typedef logic 	[6:0]	lc3b_dc_tag;
typedef logic	[10:0] lc3b_mpnc_tag;
typedef logic	[255:0] lc3b_32bytes;
typedef logic	[31:0] lc3b_32bits;


typedef enum bit [3:0] {
    op_add  = 4'b0001,
    op_and  = 4'b0101,
    op_br   = 4'b0000,
    op_jmp  = 4'b1100,   /* also RET */
    op_jsr  = 4'b0100,   /* also JSRR */
    op_ldb  = 4'b0010,
    op_ldi  = 4'b1010,
    op_ldr  = 4'b0110,
    op_lea  = 4'b1110,
    op_not  = 4'b1001,
    op_rti  = 4'b1000,
    op_shf  = 4'b1101,
    op_stb  = 4'b0011,
    op_sti  = 4'b1011,
    op_str  = 4'b0111,
    op_trap = 4'b1111
} lc3b_opcode;

typedef enum bit [3:0] {
    alu_add,
    alu_and,
    alu_not,
    alu_pass,
    alu_sll,
    alu_srl,
    alu_sra
} lc3b_aluop;


typedef enum bit [1:0] {
    alu_type,
    load_type,
    store_type,
    br_type
} lc3b_op_type;

typedef struct packed{
	lc3b_opcode opcode;
	lc3b_word address;
	lc3b_word vj;
	lc3b_word vk;
	lc3b_reorder_id qj;
	lc3b_reorder_id qk;
	lc3b_reorder_id qdest;
	logic ready;
}lc3b_ctl_word;

// data leaving the ALUs and Load Modules
typedef struct packed{
    lc3b_word data;
    lc3b_reorder_id qdest;
    lc3b_nzp cc;
    logic modifies_cc;      // 1 means this instruction is a "set cc" instr; 0 means it is not a "set cc" instr
}lc3b_word_plus;

// line of data in the reorder buffer
// may need to add or remove data
typedef struct packed{
    lc3b_opcode opcode;
    lc3b_word value;
    lc3b_reg dest_reg;
	 lc3b_word address;
    lc3b_nzp cc;
    logic modifies_cc;      // 1 means this instruction is a "set cc" instr; 0 means it is not a "set cc" instr
	 logic valid;
	 logic writes_reg;
	 logic writes_mem;
}lc3b_reord_buf_line;

typedef struct packed{
    lc3b_opcode opcode;
    lc3b_word value;
	 lc3b_reg dest_reg;
	 lc3b_word address;
	 logic modifies_cc;
}lc3b_IF_to_reord;

typedef struct packed{
	lc3b_word instr;
	lc3b_ctl_word ctl_word;
}lc3b_if_line_word;

endpackage : lc3b_types
