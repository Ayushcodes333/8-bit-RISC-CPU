// =============================================================================
// Module  : alu
// Project : 8-Bit Single-Cycle RISC Microprocessor
// File    : src/alu.v
//
// Description:
//   8-bit Arithmetic Logic Unit.  Performs one of four operations selected by
//   the 2-bit `alu_op` control signal.  The `zero` flag is asserted whenever
//   the result is 0x00 and is used by the BIZ (Branch-If-Zero) instruction.
//
// ALU Operation Encoding (matches control_unit.v):
//   alu_op  Operation
//   ──────  ─────────
//   2'b00   ADD   result = a + b
//   2'b01   SUB   result = a - b
//   2'b10   AND   result = a & b
//   2'b11   OR    result = a | b
// =============================================================================

`timescale 1ns/1ps

module alu (
    input  wire [7:0] a,        // Operand A  (Rs1 data)
    input  wire [7:0] b,        // Operand B  (Rs2 data or immediate)
    input  wire [1:0] alu_op,   // Operation select
    output reg  [7:0] result,   // 8-bit computation result
    output wire       zero      // High when result == 0
);

    // -------------------------------------------------------------------------
    // Combinational datapath
    // -------------------------------------------------------------------------
    always @(*) begin
        case (alu_op)
            2'b00 : result = a + b;         // ADD
            2'b01 : result = a - b;         // SUB
            2'b10 : result = a & b;         // AND
            2'b11 : result = a | b;         // OR
            default: result = 8'h00;
        endcase
    end

    // Zero flag — combinational, derived directly from result
    assign zero = (result == 8'h00);

endmodule
