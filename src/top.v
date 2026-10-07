// =============================================================================
// Module  : top  (Single-Cycle Datapath)
// Project : 8-Bit Single-Cycle RISC Microprocessor
// File    : src/top.v
//
// Description:
//   Integrates all sub-modules to form the complete single-cycle processor.
//   Every instruction completes in one clock cycle; all combinational paths
//   settle before the rising edge commits state (PC, registers, memory).
//
// ─── Instruction Format ───────────────────────────────────────────────────────
//   [15:13] opcode  [12:11] Rd  [10:9] Rs1  [8:7] Rs2  [7:0] Imm
//
// ─── Datapath (signal flow per cycle) ────────────────────────────────────────
//
//   ① PC → Instruction Memory
//        pc_out ──► instr_rom[pc_out] ──► instr[15:0]
//
//   ② Decode
//        instr[15:13] ──► control_unit ──► {reg_write, mem_read, mem_write,
//                                           mem_to_reg, jump, branch,
//                                           imm_sel, alu_op}
//
//   ③ Register Read
//        instr[12:11] ──► rd_addr  (write port address)
//        instr[10:9]  ──► rs1_addr ──► rs1_data
//        instr[8:7]   ──► rs2_addr ──► rs2_data
//
//   ④ ALU B-operand mux
//        imm_sel=0 ──► alu_b = rs2_data
//        imm_sel=1 ──► alu_b = instr[7:0]   (immediate)
//
//   ⑤ ALU
//        {rs1_data, alu_b, alu_op} ──► {alu_result, zero}
//
//   ⑥ Data Memory
//        LOAD  : mem_addr=Imm, mem_read=1  ──► mem_rd_data
//        STORE : mem_addr=Imm, mem_write=1, mem_wr_data=rs1_data
//
//   ⑦ Writeback mux
//        mem_to_reg=0 ──► wr_data = alu_result
//        mem_to_reg=1 ──► wr_data = mem_rd_data
//
//   ⑧ PC Next mux
//        pc_load = jump | (branch & zero)
//        pc_load=0 ──► PC + 1
//        pc_load=1 ──► pc_next = instr[7:0]   (jump / branch target)
//
// =============================================================================

`timescale 1ns/1ps

module top (
    input wire clk,     // System clock
    input wire reset    // Synchronous active-high reset
);

    // =========================================================================
    // Internal Wires — Instruction fields
    // =========================================================================
    wire [15:0] instr;              // Full 16-bit fetched instruction
    wire [2:0]  opcode;             // instr[15:13]
    wire [1:0]  rd_addr;            // instr[12:11]  destination register
    wire [1:0]  rs1_addr;           // instr[10:9]   source register 1
    wire [1:0]  rs2_addr;           // instr[8:7]    source register 2
    wire [7:0]  imm;                // instr[7:0]    8-bit immediate / address

    assign opcode   = instr[15:13];
    assign rd_addr  = instr[12:11];
    assign rs1_addr = instr[10:9];
    assign rs2_addr = instr[8:7];
    assign imm      = instr[7:0];

    // =========================================================================
    // Internal Wires — Datapath signals
    // =========================================================================
    wire [7:0] pc_out;              // Current PC value
    wire [7:0] rs1_data;            // Register file port A output
    wire [7:0] rs2_data;            // Register file port B output
    wire [7:0] alu_b;               // ALU second operand (after mux)
    wire [7:0] alu_result;          // ALU computation result
    wire       zero;                // ALU zero flag (used by BIZ)
    wire [7:0] mem_rd_data;         // Data memory read output
    wire [7:0] wr_data;             // Writeback data into register file
    wire       pc_load;             // PC load enable (jump or branch-taken)

    // =========================================================================
    // Internal Wires — Control signals
    // =========================================================================
    wire        reg_write;
    wire        mem_read;
    wire        mem_write;
    wire        mem_to_reg;
    wire        jump;
    wire        branch;
    wire        imm_sel;
    wire [1:0]  alu_op;

    // =========================================================================
    // ① Program Counter
    // =========================================================================
    pc u_pc (
        .clk     (clk),
        .reset   (reset),
        .pc_load (pc_load),
        .pc_next (imm),         // Jump/branch target is always the Imm field
        .pc_out  (pc_out)
    );

    // =========================================================================
    // ② Instruction ROM + Data RAM
    // =========================================================================
    memory u_memory (
        .clk         (clk),
        // Instruction ROM
        .pc_addr     (pc_out),
        .instr       (instr),
        // Data RAM
        .mem_addr    (imm),         // LOAD/STORE address comes from Imm field
        .mem_read    (mem_read),
        .mem_write   (mem_write),
        .mem_wr_data (rs1_data),    // STORE writes Rs1 into memory
        .mem_rd_data (mem_rd_data)
    );

    // =========================================================================
    // ③ Control Unit (combinational decoder)
    // =========================================================================
    control_unit u_ctrl (
        .opcode    (opcode),
        .reg_write (reg_write),
        .mem_read  (mem_read),
        .mem_write (mem_write),
        .mem_to_reg(mem_to_reg),
        .jump      (jump),
        .branch    (branch),
        .imm_sel   (imm_sel),
        .alu_op    (alu_op)
    );

    // =========================================================================
    // ④ Register File
    // =========================================================================
    register_file u_regfile (
        .clk      (clk),
        .reg_write(reg_write),
        .rd_addr  (rd_addr),
        .rs1_addr (rs1_addr),
        .rs2_addr (rs2_addr),
        .wr_data  (wr_data),
        .rs1_data (rs1_data),
        .rs2_data (rs2_data)
    );

    // =========================================================================
    // ⑤ ALU B-operand mux
    //      imm_sel=0 → Rs2 data (R-type: ADD, SUB, AND, OR)
    //      imm_sel=1 → Immediate (I-type: LOAD, STORE, JUMP, BIZ)
    // =========================================================================
    assign alu_b = imm_sel ? imm : rs2_data;

    // =========================================================================
    // ⑥ ALU
    // =========================================================================
    alu u_alu (
        .a      (rs1_data),
        .b      (alu_b),
        .alu_op (alu_op),
        .result (alu_result),
        .zero   (zero)
    );

    // =========================================================================
    // ⑦ Writeback mux
    //      mem_to_reg=0 → ALU result written to Rd  (R-type)
    //      mem_to_reg=1 → Memory data written to Rd (LOAD)
    // =========================================================================
    assign wr_data = mem_to_reg ? mem_rd_data : alu_result;

    // =========================================================================
    // ⑧ PC-next control
    //      pc_load asserted for JUMP (unconditional) or BIZ when zero=1
    // =========================================================================
    assign pc_load = jump | (branch & zero);

endmodule
