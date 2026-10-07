// =============================================================================
// Module  : control_unit
// Project : 8-Bit Single-Cycle RISC Microprocessor
// File    : src/control_unit.v
//
// Description:
//   Pure combinational decoder.  Receives the 3-bit opcode field from the
//   current instruction word and drives every control signal in the datapath
//   for that same cycle.
//
//   All outputs are registered with `always @(*)` (no flip-flops) so they
//   settle before the clock edge that commits state changes.
//
// ─── Instruction Format Reminder ────────────────────────────────────────────
//   [15:13] opcode  [12:11] Rd  [10:9] Rs1  [8:7] Rs2  [7:0] Imm
//
// ─── Opcode Table ────────────────────────────────────────────────────────────
//   Opcode  Mnemonic  Description
//   3'b000  ADD       Rd ← Rs1 + Rs2
//   3'b001  SUB       Rd ← Rs1 - Rs2
//   3'b010  AND       Rd ← Rs1 & Rs2
//   3'b011  OR        Rd ← Rs1 | Rs2
//   3'b100  LOAD      Rd ← MEM[Imm]
//   3'b101  STORE     MEM[Imm] ← Rs1
//   3'b110  JUMP      PC ← Imm
//   3'b111  BIZ       if (Rs1 == 0) PC ← Imm
//
// ─── Control Signal Summary ──────────────────────────────────────────────────
//   Signal      Width  0 = …                  1 = …
//   ─────────── ─────  ─────────────────────  ────────────────────────────────
//   reg_write     1    no register write       write result into Rd
//   mem_read      1    data RAM idle           read  data_ram[Imm]  → reg
//   mem_write     1    data RAM idle           write Rs1 → data_ram[Imm]
//   mem_to_reg    1    ALU result → Rd         memory read data → Rd
//   jump          1    normal flow             unconditional PC ← Imm
//   branch        1    normal flow             conditional  PC ← Imm (if zero)
//   imm_sel       1    use Rs2 as ALU B-in     use Imm as ALU B-in / address
//   alu_op        2    (see ALU encoding)      00=ADD 01=SUB 10=AND 11=OR
// =============================================================================

`timescale 1ns/1ps

module control_unit (
    input  wire [2:0] opcode,       // Instruction[15:13]
    output reg        reg_write,    // Register file write enable
    output reg        mem_read,     // Data memory read enable
    output reg        mem_write,    // Data memory write enable
    output reg        mem_to_reg,   // Writeback mux: 0=ALU result, 1=mem data
    output reg        jump,         // Unconditional jump enable
    output reg        branch,       // Conditional branch enable (BIZ)
    output reg        imm_sel,      // ALU B-operand mux: 0=Rs2, 1=Immediate
    output reg  [1:0] alu_op        // ALU operation select
);

    // -------------------------------------------------------------------------
    // Opcode parameter constants (improves readability)
    // -------------------------------------------------------------------------
    localparam OP_ADD   = 3'b000;
    localparam OP_SUB   = 3'b001;
    localparam OP_AND   = 3'b010;
    localparam OP_OR    = 3'b011;
    localparam OP_LOAD  = 3'b100;
    localparam OP_STORE = 3'b101;
    localparam OP_JUMP  = 3'b110;
    localparam OP_BIZ   = 3'b111;

    // -------------------------------------------------------------------------
    // Control signal truth table (combinational)
    //
    //            | reg_ | mem_ | mem_  | mem_   | jump | branch | imm_ | alu_
    //  opcode    | write| read | write | to_reg |      |        | sel  |  op
    //  ──────────┼──────┼──────┼───────┼────────┼──────┼────────┼──────┼─────
    //  ADD 000   |  1   |  0   |   0   |   0    |  0   |   0    |  0   | 00
    //  SUB 001   |  1   |  0   |   0   |   0    |  0   |   0    |  0   | 01
    //  AND 010   |  1   |  0   |   0   |   0    |  0   |   0    |  0   | 10
    //  OR  011   |  1   |  0   |   0   |   0    |  0   |   0    |  0   | 11
    //  LOAD 100  |  1   |  1   |   0   |   1    |  0   |   0    |  1   | 00
    //  STORE 101 |  0   |  0   |   1   |   0    |  0   |   0    |  1   | 00
    //  JUMP 110  |  0   |  0   |   0   |   0    |  1   |   0    |  1   | 00
    //  BIZ  111  |  0   |  0   |   0   |   0    |  0   |   1    |  1   | 00
    // -------------------------------------------------------------------------
    always @(*) begin
        // Safe defaults — prevents latches on undefined opcodes
        reg_write  = 1'b0;
        mem_read   = 1'b0;
        mem_write  = 1'b0;
        mem_to_reg = 1'b0;
        jump       = 1'b0;
        branch     = 1'b0;
        imm_sel    = 1'b0;
        alu_op     = 2'b00;

        case (opcode)
            // ── R-Type: ALU operations ────────────────────────────────────
            OP_ADD : begin
                reg_write = 1'b1;
                alu_op    = 2'b00;  // ADD
            end
            OP_SUB : begin
                reg_write = 1'b1;
                alu_op    = 2'b01;  // SUB
            end
            OP_AND : begin
                reg_write = 1'b1;
                alu_op    = 2'b10;  // AND
            end
            OP_OR  : begin
                reg_write = 1'b1;
                alu_op    = 2'b11;  // OR
            end
            // ── I-Type: Memory ────────────────────────────────────────────
            OP_LOAD : begin
                reg_write  = 1'b1;  // Write memory data into Rd
                mem_read   = 1'b1;  // Enable data RAM read
                mem_to_reg = 1'b1;  // Writeback from memory, not ALU
                imm_sel    = 1'b1;  // Address comes from Imm field
                alu_op     = 2'b00; // ALU unused; keep ADD as default
            end
            OP_STORE : begin
                mem_write  = 1'b1;  // Enable data RAM write
                imm_sel    = 1'b1;  // Address comes from Imm field
                alu_op     = 2'b00; // ALU unused
            end
            // ── I-Type: Control flow ──────────────────────────────────────
            OP_JUMP : begin
                jump    = 1'b1;     // Unconditional PC load
                imm_sel = 1'b1;     // Jump target from Imm field
            end
            OP_BIZ  : begin
                branch  = 1'b1;     // Conditional PC load (resolved in top.v)
                imm_sel = 1'b1;     // Branch target from Imm field
            end
            // ── Catch-all (should never occur in a correct program) ────────
            default : begin
                /* All signals already defaulted to 0 above */
            end
        endcase
    end

endmodule
