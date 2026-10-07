// =============================================================================
// Module  : pc  (Program Counter)
// Project : 8-Bit Single-Cycle RISC Microprocessor
// File    : src/pc.v
//
// Description:
//   8-bit synchronous Program Counter.  On every rising clock edge:
//     - If `reset`     is asserted   → PC loads 0x00 (synchronous reset)
//     - If `pc_load`   is asserted   → PC loads `pc_next` (JUMP / BIZ taken)
//     - Otherwise                    → PC increments by 1 (normal fetch)
//
//   PC is index-addressed: each increment steps to the next 16-bit instruction
//   word.  The instruction memory uses pc_out as a word-index, not a byte addr.
// =============================================================================

`timescale 1ns/1ps

module pc (
    input  wire       clk,       // System clock
    input  wire       reset,     // Synchronous active-high reset
    input  wire       pc_load,   // Load pc_next instead of incrementing
    input  wire [7:0] pc_next,   // Branch / jump target address
    output reg  [7:0] pc_out     // Current PC value → instruction memory
);

    always @(posedge clk) begin
        if (reset)
            pc_out <= 8'h00;
        else if (pc_load)
            pc_out <= pc_next;
        else
            pc_out <= pc_out + 8'h01;
    end

endmodule
