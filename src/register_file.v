// =============================================================================
// Module  : register_file
// Project : 8-Bit Single-Cycle RISC Microprocessor
// File    : src/register_file.v
//
// Description:
//   4 × 8-bit general-purpose register file (R0–R3).
//
//   Write port  : synchronous on rising clock edge, gated by `reg_write`.
//   Read ports  : asynchronous / combinational (two independent read ports).
//
//   Both read ports are available in the same cycle that data is written
//   (write-first / read-during-write) because reads are combinational and
//   Verilog evaluates the `always @(*)` after the register update.
//
// Register Encoding:
//   rd_addr / rs1_addr / rs2_addr   Register
//   ─────────────────────────────   ────────
//   2'b00                           R0
//   2'b01                           R1
//   2'b10                           R2
//   2'b11                           R3
// =============================================================================

`timescale 1ns/1ps

module register_file (
    input  wire       clk,          // System clock
    input  wire       reg_write,    // Write enable (active high)
    input  wire [1:0] rd_addr,      // Destination register address (write port)
    input  wire [1:0] rs1_addr,     // Source register 1 address   (read port A)
    input  wire [1:0] rs2_addr,     // Source register 2 address   (read port B)
    input  wire [7:0] wr_data,      // Data to write into Rd
    output wire [7:0] rs1_data,     // Data read from Rs1
    output wire [7:0] rs2_data      // Data read from Rs2
);

    // 4-entry × 8-bit register storage
    reg [7:0] regs [0:3];

    // -------------------------------------------------------------------------
    // Synchronous write port
    // -------------------------------------------------------------------------
    always @(posedge clk) begin
        if (reg_write)
            regs[rd_addr] <= wr_data;
    end

    // -------------------------------------------------------------------------
    // Asynchronous (combinational) read ports
    // -------------------------------------------------------------------------
    assign rs1_data = regs[rs1_addr];
    assign rs2_data = regs[rs2_addr];

endmodule
