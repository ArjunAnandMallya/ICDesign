`include "./branch.vh"
`include "./itype.vh"
`include "./load.vh"
`include "./rtype.vh"
`include "./store.vh"
`include "./opcode.vh"
`include "./csr.vh"

module InstructionMemory (
    input clk,
    input reset,
    input [31:0] pc,
    output reg [31:0] instruction
);

    reg [31:0] data [0:31];
    integer i;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            // Default everything to NOP so you never fetch X.
            for (i = 0; i < 32; i = i + 1) begin
                data[i] <= 32'h00000013; // ADDI x0,x0,0
            end

//        // Program image (from your C->RISC-V compile / dump)
// data[0]  = {12'h100, 5'd0, `ITYPE_ADDI, 5'd1, `OPCODE_ITYPE};   // addi x1,x0,0x100
//        data[1]  = {12'd5,   5'd0, `ITYPE_ADDI, 5'd2, `OPCODE_ITYPE};   // addi x2,x0,5
//        data[2]  = {12'd7,   5'd2, `ITYPE_ADDI, 5'd3, `OPCODE_ITYPE};   // addi x3,x2,7        (RAW x2)
//        // --- EX->EX forwarding chain ---
//        data[3]  = {7'b0000000, 5'd2, 5'd3, `RTYPE_ADDSUB, 5'd4, `OPCODE_RTYPE}; // add x4,x3,x2 (RAW x3,x2)
//        data[4]  = {7'b0000000, 5'd4, 5'd2, `RTYPE_ADDSUB, 5'd5, `OPCODE_RTYPE}; // add x5,x2,x4 (RAW x4)
//        // --- store-data forwarding ---
//        data[5]  = {7'd0, 5'd5, 5'd1, `STORE_SW, 5'd0, `OPCODE_STORE}; // sw x5,0(x1)
//        // --- load-use hazard (must stall/bubble 1 cycle) ---
//        data[6]  = {12'd0, 5'd1, `LOAD_LW, 5'd6, `OPCODE_LOAD};        // lw x6,0(x1)
//        data[7]  = {7'b0000000, 5'd2, 5'd6, `RTYPE_ADDSUB, 5'd7, `OPCODE_RTYPE}; // add x7,x6,x2
//        // --- another store/load to exercise forwarding paths ---
//        data[8]  = {12'd1, 5'd7, `ITYPE_ADDI, 5'd7, `OPCODE_ITYPE};    // addi x7,x7,1
//        data[9]  = {7'd0, 5'd7, 5'd1, `STORE_SW, 5'd4, `OPCODE_STORE}; // sw x7,4(x1)
//        data[10] = {12'd4, 5'd1, `LOAD_LW, 5'd8, `OPCODE_LOAD};        // lw x8,4(x1)
//        data[11] = {7'b0000000, 5'd7, 5'd8, `RTYPE_ADDSUB, 5'd9, `OPCODE_RTYPE}; // add x9,x8,x7
//        // --- taken branch flush ---
//        data[12] = {7'b0100000, 5'd9, 5'd9, `RTYPE_ADDSUB, 5'd10, `OPCODE_RTYPE}; // sub x10,x9,x9 => 0
//        // beq x10,x0,+8 (skip next instruction)
//        data[13] = {1'b0, 6'd0, 5'd0, 5'd10, `BRANCH_BEQ, 4'b0100, 1'b0, `OPCODE_BRANCH};
//        data[14] = {12'h123, 5'd0, `ITYPE_ADDI, 5'd11, `OPCODE_ITYPE}; // addi x11,x0,0x123 (MUST be squashed)
//        data[15] = {12'h456, 5'd0, `ITYPE_ADDI, 5'd12, `OPCODE_ITYPE}; // addi x12,x0,0x456 (branch target)
//        // --- JAL flush ---
//        // jal x0, +8 (skip next)
//        data[16] = 32'h0080006f; // jal x0,+8
//        data[17] = {12'h777, 5'd0, `ITYPE_ADDI, 5'd13, `OPCODE_ITYPE}; // addi x13,x0,0x777 (MUST be squashed)
//        data[18] = {12'h888, 5'd0, `ITYPE_ADDI, 5'd14, `OPCODE_ITYPE}; // addi x14,x0,0x888
//        // --- End ---
//        data[19] = 32'h0000006f; // jal x0,0 (infinite loop)
// 1. EX-to-EX Forwarding
        // ========================================================================
        data[0] = {12'h2BC, 5'd0, `ITYPE_ADDI, 5'd1, `OPCODE_ITYPE};				// ADDI:  x1 = x0 + 2BC = 000002BC
		data[1] = {12'd24,  5'd1, `ITYPE_SLLI, 5'd2, `OPCODE_ITYPE};				// SLLI:  x2 = x1 << 24 = BC000000
		data[2] = {12'd0,  5'd2, `ITYPE_SLTI, 5'd3, `OPCODE_ITYPE};				// SLTI:  x3 = (x2(-1140850688d) < 0) ? 1 : 0 = 00000001
		data[3] = {12'd0,  5'd2, `ITYPE_SLTIU, 5'd4, `OPCODE_ITYPE};				// SLTIU: x4 = (x2(3154116608d) < 0) ? 1 : 0 = 00000000
		data[4] = {12'h653,  5'd1, `ITYPE_XORI, 5'd5, `OPCODE_ITYPE};			// XORI:  x5 = x1 XOR 653 = 000004EF
		data[5] = {7'b0000000, 5'd4, 5'd2, `ITYPE_SRXI, 5'd6, `OPCODE_ITYPE};	// SRLI:  x6 = x2 >> 4 = 0BC00000
		data[6] = {7'b0100000, 5'd4, 5'd2, `ITYPE_SRXI, 5'd7, `OPCODE_ITYPE};	// SRAI:  x7 = x2 >>> 4 = FBC00000
		data[7] = {12'h0BC, 5'd2, `ITYPE_ORI, 5'd8, `OPCODE_ITYPE};				// ORI:   x8 = x2 OR BC = BC0000BC
		data[8] = {12'h0EC, 5'd5, `ITYPE_ANDI, 5'd9, `OPCODE_ITYPE};				// ANDI:  x9 = x5 AND 0EC = 000000EC

		// ??????????????????????????????????????????????
		// R-?? ??? (10?)
		// {funct7, rs2, rs1, funct3, rd, OPCODE_RTYPE}
		data[9]  = {7'b0000000, 5'd9, 5'd1, `RTYPE_ADDSUB, 5'd10, `OPCODE_RTYPE};	// ADD: x10 = x1 + x9 = 000003A8
		data[10] = {7'b0100000, 5'd5, 5'd6, `RTYPE_ADDSUB, 5'd11, `OPCODE_RTYPE};	// SUB: x11 = x6 - x5 = 0BBFFB11
		data[11] = {7'b0000000, 5'd3, 5'd7, `RTYPE_SLL, 5'd12, `OPCODE_RTYPE};		// SLL: x12 = x7 << x3 = F7800000
		data[12] = {7'b0000000, 5'd2, 5'd1, `RTYPE_SLT, 5'd13, `OPCODE_RTYPE};		// SLT: x13 = (x1 < x2) ? 1 : 0 = 00000000
		data[13] = {7'b0000000, 5'd2, 5'd1, `RTYPE_SLTU, 5'd14, `OPCODE_RTYPE};		// SLTU: x14 = (x1 < x2 unsigned) ? 1 : 0 = 00000001
		data[14] = {7'b0000000, 5'd8, 5'd12, `RTYPE_XOR, 5'd15, `OPCODE_RTYPE};		// XOR: x15 = x12 XOR x8 = 4B8000BC
		data[15] = {7'b0000000, 5'd3, 5'd12, `RTYPE_SR, 5'd16, `OPCODE_RTYPE};		// SRL: x16 = x12 >> x3 = 7BC00000
		data[16] = {7'b0100000, 5'd3, 5'd12, `RTYPE_SR, 5'd17, `OPCODE_RTYPE};		// SRA: x17 = x12 >>> x3 = FBC00000
		data[17] = {7'b0000000, 5'd7, 5'd11, `RTYPE_OR, 5'd18, `OPCODE_RTYPE};		// OR:  x18 = x11 OR x7 = FBFFFB11
		data[18] = {7'b0000000, 5'd11, 5'd7, `RTYPE_AND, 5'd19, `OPCODE_RTYPE};		// AND: x19 = x7 AND x11 = 0B800000

        end
    end

    always @(*) begin
        instruction = data[pc[31:2]];
    end

endmodule
