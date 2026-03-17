`include "./branch.vh"
`include "./itype.vh"
`include "./load.vh"
`include "./rtype.vh"
`include "./store.vh"
`include "./opcode.vh"
`include "./csr.vh"

module InstructionMemory (
    input [31:0] pc,
    output reg [31:0] instruction
);

    reg [31:0] data [0:2047];
    integer i;

    initial begin
        // Default everything to NOP so you never fetch X.
        for (i = 0; i < 2048; i = i + 1) begin
            data[i] = 32'h00000013; // ADDI x0,x0,0
        end

        // Program image (from your C->RISC-V compile / dump)
 data[0]  = {12'h100, 5'd0, `ITYPE_ADDI, 5'd1, `OPCODE_ITYPE};   // addi x1,x0,0x100
        data[1]  = {12'd5,   5'd0, `ITYPE_ADDI, 5'd2, `OPCODE_ITYPE};   // addi x2,x0,5
        data[2]  = {12'd7,   5'd2, `ITYPE_ADDI, 5'd3, `OPCODE_ITYPE};   // addi x3,x2,7        (RAW x2)
        // --- EX->EX forwarding chain ---
        data[3]  = {7'b0000000, 5'd2, 5'd3, `RTYPE_ADDSUB, 5'd4, `OPCODE_RTYPE}; // add x4,x3,x2 (RAW x3,x2)
        data[4]  = {7'b0000000, 5'd4, 5'd2, `RTYPE_ADDSUB, 5'd5, `OPCODE_RTYPE}; // add x5,x2,x4 (RAW x4)
        // --- store-data forwarding ---
        data[5]  = {7'd0, 5'd5, 5'd1, `STORE_SW, 5'd0, `OPCODE_STORE}; // sw x5,0(x1)
        // --- load-use hazard (must stall/bubble 1 cycle) ---
        data[6]  = {12'd0, 5'd1, `LOAD_LW, 5'd6, `OPCODE_LOAD};        // lw x6,0(x1)
        data[7]  = {7'b0000000, 5'd2, 5'd6, `RTYPE_ADDSUB, 5'd7, `OPCODE_RTYPE}; // add x7,x6,x2
        // --- another store/load to exercise forwarding paths ---
        data[8]  = {12'd1, 5'd7, `ITYPE_ADDI, 5'd7, `OPCODE_ITYPE};    // addi x7,x7,1
        data[9]  = {7'd0, 5'd7, 5'd1, `STORE_SW, 5'd4, `OPCODE_STORE}; // sw x7,4(x1)
        data[10] = {12'd4, 5'd1, `LOAD_LW, 5'd8, `OPCODE_LOAD};        // lw x8,4(x1)
        data[11] = {7'b0000000, 5'd7, 5'd8, `RTYPE_ADDSUB, 5'd9, `OPCODE_RTYPE}; // add x9,x8,x7
        // --- taken branch flush ---
        data[12] = {7'b0100000, 5'd9, 5'd9, `RTYPE_ADDSUB, 5'd10, `OPCODE_RTYPE}; // sub x10,x9,x9 => 0
        // beq x10,x0,+8 (skip next instruction)
        data[13] = {1'b0, 6'd0, 5'd0, 5'd10, `BRANCH_BEQ, 4'b0100, 1'b0, `OPCODE_BRANCH};
        data[14] = {12'h123, 5'd0, `ITYPE_ADDI, 5'd11, `OPCODE_ITYPE}; // addi x11,x0,0x123 (MUST be squashed)
        data[15] = {12'h456, 5'd0, `ITYPE_ADDI, 5'd12, `OPCODE_ITYPE}; // addi x12,x0,0x456 (branch target)
        // --- JAL flush ---
        // jal x0, +8 (skip next)
        data[16] = 32'h0080006f; // jal x0,+8
        data[17] = {12'h777, 5'd0, `ITYPE_ADDI, 5'd13, `OPCODE_ITYPE}; // addi x13,x0,0x777 (MUST be squashed)
        data[18] = {12'h888, 5'd0, `ITYPE_ADDI, 5'd14, `OPCODE_ITYPE}; // addi x14,x0,0x888
        // --- End ---
        data[19] = 32'h0000006f; // jal x0,0 (infinite loop)

    end

    always @(*) begin
        instruction = data[pc[31:2]];
    end

endmodule
