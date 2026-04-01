`timescale 1ns/1ps

module tb_rv32i46f5spdebug;
  localparam int XLEN = 32;

  // Program-specific "done" heuristic:
  // Your current InstructionMemory image ends at data[18] (PC=18*4=0x48).
  // After that, memory defaults to NOPs (0x00000013). We stop once we see NOPs
  // after the last programmed PC for a few cycles.
  localparam logic [31:0] LAST_PC   = 32'h0000_0048;
  localparam logic [31:0] NOP_INSN  = 32'h0000_0013;
  localparam int MAX_CYCLES = 3000;
  localparam int DONE_STREAK_CYCLES = 8;

  logic clk;
  logic reset;
  logic clk_enable;

  wire [XLEN-1:0] debug_pc;
  wire [31:0]     debug_instruction;
  wire [XLEN-1:0] debug_reg_data;
  wire [4:0]      debug_reg_addr;
  wire [XLEN-1:0] debug_alu_result;

  // DUT
  RV32I46F5SPDebug #(.XLEN(XLEN)) dut (
    .clk(clk),
    .clk_enable(clk_enable),
    .reset(reset),
    .debug_pc(debug_pc),
    .debug_instruction(debug_instruction),
    .debug_reg_data(debug_reg_data),
    .debug_reg_addr(debug_reg_addr),
    .debug_alu_result(debug_alu_result)
  );

  // 100MHz-ish clock (10ns period). Adjust as needed.
  initial clk = 1'b0;
  always #5 clk = ~clk;
    int done_streak;
  // Simple run control
  initial begin
    clk_enable = 1'b1;
    reset      = 1'b1;

    // Waves (optional)
    $dumpfile("tb_rv32i46f5spdebug.vcd");
    $dumpvars(0, tb_rv32i46f5spdebug);

    // Hold reset for a few cycles
    repeat (5) @(posedge clk);
    reset = 1'b0;

    // OPTIONAL: overwrite instruction memory with your tiny program.
    // Comment this block out if you want to use whatever is already in Instruction_Memory.v.
    //
    // Note: InstructionMemory indexes by pc[31:2], so data[0] is at PC=0x0, data[1] at PC=0x4, etc.

    // Generic run: stop when we detect the terminal jal x0,0 loop,
    // or after MAX_CYCLES to avoid infinite simulation.

    done_streak = 0;

    repeat (MAX_CYCLES) begin
      @(posedge clk);
      if (debug_pc > LAST_PC && debug_instruction == NOP_INSN) begin
        done_streak = done_streak + 1;
        if (done_streak >= DONE_STREAK_CYCLES) begin
          $display("DONE: observed NOPs after LAST_PC=%08h for %0d cycles", LAST_PC, DONE_STREAK_CYCLES);
          $display("FINAL: a0/x10 = 0x%08h", dut.register_file_debug.registers[10]);
          $finish;
        end
      end else begin
        done_streak = 0;
      end
    end

    $display("TIMEOUT: program did not reach DONE_PC within %0d cycles", MAX_CYCLES);
    $display("FINAL (timeout): a0/x10 = 0x%08h", dut.register_file_debug.registers[10]);
    $finish;
  end

  // Very simple cycle-by-cycle trace
  int cycle;
  initial cycle = 0;
  always @(posedge clk) begin
    cycle <= cycle + 1;
    if (!reset && clk_enable) begin
      $display("C%0d PC=%08h INSN=%08h ALU=%08h lastWB: x%0d=%08h",
               cycle, debug_pc, debug_instruction, debug_alu_result, debug_reg_addr, debug_reg_data);
    end
  end

  // Print actual data-memory writes (stores) with word index mapping.
  // DataMemory is word-addressed; the core uses byte addresses in alu_result.
  // Effective word index for the 4KB RAM is byte_addr[11:2].
  logic [31:0] mon_byte_addr;
  logic [9:0]  mon_word_index;
  logic [31:0] mon_mem_prev;
  always @(posedge clk) begin
    if (!reset && clk_enable) begin
      if (dut.MEM_memory_write) begin
        mon_byte_addr  = dut.MEM_alu_result;
        mon_word_index = mon_byte_addr[11:2];
        mon_mem_prev   = dut.data_memory.memory[mon_word_index];
        // Note: DataMemory updates with nonblocking assignment on this same posedge,
        // so we show the previous value along with mask/wdata.
        $display("  STORE: byte_addr=%08h word_index=%0d (0x%0h) mask=%b wdata=%08h mem_before=%08h",
                 mon_byte_addr, mon_word_index, mon_word_index, dut.write_mask, dut.data_memory_write_data, mon_mem_prev);
      end
    end
  end

endmodule

