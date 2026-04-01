module DataMemory (
    input clk,                      // clock signal
    input clk_enable,
    input reset,
    input write_enable,             // enabling signal for writing Data Memory
    input [9:0] address,            // Take address of memory to read/write value
    input [31:0] write_data,        // data to write to Data Memory
    input [3:0] write_mask,         // bitmask for writing data (Should receive 4'b1111 in RV32I47F and 50F top module)

    output reg [31:0] read_data    // data read from Data Memory
);

    reg [31:0] memory [0:31];     // 1024 words (4KB)
    
    // 32 bit extended mask from 4 bit write_mask
    wire [31:0] extended_mask = {{8{write_mask[3]}}, {8{write_mask[2]}}, {8{write_mask[1]}}, {8{write_mask[0]}}};

    integer i;

    always @(*) begin
        read_data = memory[address];
    end

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            for (i = 0; i < 32; i = i + 1) begin
                memory[i] <= 32'b0;
            end
        end else if (clk_enable && write_enable) begin
            memory[address] <= ((memory[address] & ~extended_mask) | (write_data & extended_mask));
        end
    end

endmodule
