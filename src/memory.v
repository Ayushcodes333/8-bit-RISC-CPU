// =============================================================================
// Module  : memory
// Project : 8-Bit Single-Cycle RISC Microprocessor
// File    : src/memory.v
//
// Description:
//   Harvard-lite memory subsystem housed in a single module:
//
//   ┌─────────────────────────────────────────────────────────────────────┐
//   │  Instruction ROM  256 × 16-bit words                                │
//   │    • Loaded at elaboration from programs/test_program.hex           │
//   │    • Asynchronous read — instr available combinationally from pc    │
//   │                                                                     │
//   │  Data RAM         256 × 8-bit bytes                                 │
//   │    • Asynchronous read  — mem_rd_data available combinationally     │
//   │    • Synchronous  write — write occurs on rising edge (mem_write=1) │
//   └─────────────────────────────────────────────────────────────────────┘
//
//   Address space: 8-bit (0x00–0xFF) for both sub-memories.
//   Instruction words are 16 bits; the ROM is word-indexed by pc_addr.
// =============================================================================

`timescale 1ns/1ps

module memory (
    input  wire        clk,           // System clock
    // ── Instruction ROM interface ──────────────────────────────────────────
    input  wire [7:0]  pc_addr,       // Word-index from PC → instruction ROM
    output wire [15:0] instr,         // 16-bit instruction word (async read)
    // ── Data RAM interface ─────────────────────────────────────────────────
    input  wire [7:0]  mem_addr,      // Byte address into data RAM
    input  wire        mem_read,      // Read enable  (combinational path)
    input  wire        mem_write,     // Write enable (synchronous)
    input  wire [7:0]  mem_wr_data,   // Data to write into RAM
    output wire [7:0]  mem_rd_data    // Data read from RAM (async)
);

    // =========================================================================
    // Instruction ROM — 256 × 16-bit
    // =========================================================================
    reg [15:0] instr_rom [0:255];

    // Load program at simulation start
    initial begin
        $readmemh("programs/test_program.hex", instr_rom);
    end

    // Asynchronous instruction fetch
    assign instr = instr_rom[pc_addr];

    // =========================================================================
    // Data RAM — 256 × 8-bit
    // =========================================================================
    reg [7:0] data_ram [0:255];

    // Synchronous write
    always @(posedge clk) begin
        if (mem_write)
            data_ram[mem_addr] <= mem_wr_data;
    end

    // Asynchronous read (single-cycle processor — no read latency)
    assign mem_rd_data = mem_read ? data_ram[mem_addr] : 8'h00;

endmodule
