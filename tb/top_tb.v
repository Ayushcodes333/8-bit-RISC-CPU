// =============================================================================
// Module  : top_tb  (Full-System Integration Testbench)
// Project : 8-Bit Single-Cycle RISC Microprocessor
// File    : tb/top_tb.v
//
// Description:
//   Self-checking integration testbench for the complete single-cycle processor.
//   Drives clock and reset, pre-initialises the data memory with test operands,
//   runs the program in programs/test_program.hex, and verifies every observable
//   result against a golden reference after each instruction completes.
//
// ─── Clock / Reset scheme ────────────────────────────────────────────────────
//   CLK_PERIOD = 10 ns  (100 MHz)
//   reset is held HIGH for 2 clock cycles, then released.
//
// ─── Cycle-accurate execution timeline ───────────────────────────────────────
//   Posedge | Instruction executing (combinational) → committed on this edge
//   ────────┼──────────────────────────────────────────────────────────────────
//     1,2   │  reset active — PC = 0x00, no writeback
//       3   │  PC=0  LOAD R1,[0x10]  → R1 = 0x07, PC ← 1
//       4   │  PC=1  LOAD R2,[0x11]  → R2 = 0x03, PC ← 2
//       5   │  PC=2  ADD  R0,R1,R2   → R0 = 0x0A, PC ← 3
//       6   │  PC=3  STORE R0,[0x20] → MEM[0x20] = 0x0A, PC ← 4
//       7   │  PC=4  SUB  R3,R1,R2   → R3 = 0x04, PC ← 5
//       8   │  PC=5  AND  R0,R1,R2   → R0 = 0x03, PC ← 6
//       9   │  PC=6  OR   R0,R1,R2   → R0 = 0x07, PC ← 7
//      10   │  PC=7  JUMP 0x00       → PC ← 0x00  (infinite loop)
//
// Simulation:
//   iverilog -g2012 -o sim_out/top_tb \
//       src/alu.v src/pc.v src/register_file.v src/memory.v \
//       src/control_unit.v src/top.v tb/top_tb.v
//   vvp sim_out/top_tb
//   → generates sim_out/top_tb.vcd
// =============================================================================

`timescale 1ns/1ps

module top_tb;

    // ── Parameters ───────────────────────────────────────────────────────────
    parameter CLK_PERIOD = 10;          // ns
    parameter TIMEOUT_CYCLES = 200;     // failsafe watchdog

    // ── DUT ports ────────────────────────────────────────────────────────────
    reg clk;
    reg reset;

    // ── Error / test counters ─────────────────────────────────────────────────
    integer errors;
    integer tests;

    // ── DUT instantiation ─────────────────────────────────────────────────────
    top dut (
        .clk   (clk),
        .reset (reset)
    );

    // ── Clock generator ───────────────────────────────────────────────────────
    initial clk = 1'b0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // ── Watchdog timer ────────────────────────────────────────────────────────
    initial begin
        #(CLK_PERIOD * TIMEOUT_CYCLES);
        $display("\nERROR: Simulation TIMEOUT after %0d cycles — possible hang.", TIMEOUT_CYCLES);
        $finish;
    end

    // =========================================================================
    // Task: check_reg
    //   Reads the register file through hierarchical reference and compares
    //   against the expected value.  Called after the posedge that committed
    //   the write (with a small #1 guard time for delta-cycle settling).
    // =========================================================================
    task check_reg;
        input [1:0]   reg_idx;
        input [7:0]   expected;
        input [255:0] label;      // up to 32-char description string
        reg   [7:0]   actual;
        begin
            actual = dut.u_regfile.regs[reg_idx];
            tests  = tests + 1;
            if (actual !== expected) begin
                $display("  FAIL [%0s]  R%0d = 0x%02h  (expected 0x%02h)",
                         label, reg_idx, actual, expected);
                errors = errors + 1;
            end else begin
                $display("  PASS [%0s]  R%0d = 0x%02h ✓",
                         label, reg_idx, actual);
            end
        end
    endtask

    // =========================================================================
    // Task: check_mem
    //   Reads a data RAM location and compares against the expected value.
    // =========================================================================
    task check_mem;
        input [7:0]   addr;
        input [7:0]   expected;
        input [255:0] label;
        reg   [7:0]   actual;
        begin
            actual = dut.u_memory.data_ram[addr];
            tests  = tests + 1;
            if (actual !== expected) begin
                $display("  FAIL [%0s]  MEM[0x%02h] = 0x%02h  (expected 0x%02h)",
                         label, addr, actual, expected);
                errors = errors + 1;
            end else begin
                $display("  PASS [%0s]  MEM[0x%02h] = 0x%02h ✓",
                         label, addr, actual);
            end
        end
    endtask

    // =========================================================================
    // Task: check_pc
    //   Reads the PC register and compares against expected value.
    // =========================================================================
    task check_pc;
        input [7:0]   expected;
        input [255:0] label;
        reg   [7:0]   actual;
        begin
            actual = dut.u_pc.pc_out;
            tests  = tests + 1;
            if (actual !== expected) begin
                $display("  FAIL [%0s]  PC = 0x%02h  (expected 0x%02h)",
                         label, actual, expected);
                errors = errors + 1;
            end else begin
                $display("  PASS [%0s]  PC = 0x%02h ✓", label, actual);
            end
        end
    endtask

    // =========================================================================
    // Main stimulus
    // =========================================================================
    initial begin
        // ── VCD waveform dump ─────────────────────────────────────────────────
        $dumpfile("sim_out/top_tb.vcd");
        $dumpvars(0, top_tb);

        errors = 0;
        tests  = 0;

        $display("");
        $display("╔══════════════════════════════════════════════════════╗");
        $display("║       8-Bit RISC Processor — System Testbench        ║");
        $display("╚══════════════════════════════════════════════════════╝");

        // ── Pre-initialise data RAM with operands ─────────────────────────────
        // MEM[0x10] = 0x07  (operand A for LOAD R1)
        // MEM[0x11] = 0x03  (operand B for LOAD R2)
        // These values are NOT in the hex file; the testbench owns data setup.
        dut.u_memory.data_ram[8'h10] = 8'h07;
        dut.u_memory.data_ram[8'h11] = 8'h03;
        $display("\n[SETUP] data_ram[0x10] = 0x07,  data_ram[0x11] = 0x03");

        // ── Apply synchronous reset for 2 clock cycles ────────────────────────
        reset = 1'b1;
        repeat(2) @(posedge clk);
        @(negedge clk);
        reset = 1'b0;
        $display("[RESET] Released after 2 cycles.  PC = 0x00\n");

        // =====================================================================
        // Cycle 1 (posedge 3): PC=0 → LOAD R1, [0x10]
        //   Expected: R1 = MEM[0x10] = 0x07,  PC becomes 0x01
        // =====================================================================
        $display("--- Cycle 1 | PC=0 | LOAD R1, [0x10] ---");
        @(posedge clk); #1;
        check_reg(2'd1, 8'h07, "LOAD R1,[0x10]");
        check_pc (8'h01,       "PC after LOAD  ");

        // =====================================================================
        // Cycle 2 (posedge 4): PC=1 → LOAD R2, [0x11]
        //   Expected: R2 = MEM[0x11] = 0x03,  PC becomes 0x02
        // =====================================================================
        $display("\n--- Cycle 2 | PC=1 | LOAD R2, [0x11] ---");
        @(posedge clk); #1;
        check_reg(2'd2, 8'h03, "LOAD R2,[0x11]");
        check_pc (8'h02,       "PC after LOAD  ");

        // =====================================================================
        // Cycle 3 (posedge 5): PC=2 → ADD R0, R1, R2
        //   Expected: R0 = 0x07 + 0x03 = 0x0A,  PC becomes 0x03
        // =====================================================================
        $display("\n--- Cycle 3 | PC=2 | ADD R0, R1, R2 ---");
        @(posedge clk); #1;
        check_reg(2'd0, 8'h0A, "ADD R0=R1+R2   ");
        check_pc (8'h03,       "PC after ADD   ");

        // =====================================================================
        // Cycle 4 (posedge 6): PC=3 → STORE R0, [0x20]
        //   Expected: MEM[0x20] = R0 = 0x0A,  PC becomes 0x04
        //   Note: R0 should be unchanged (reg_write=0 for STORE)
        // =====================================================================
        $display("\n--- Cycle 4 | PC=3 | STORE R0, [0x20] ---");
        @(posedge clk); #1;
        check_mem(8'h20, 8'h0A, "STORE→MEM[0x20]");
        check_reg(2'd0,  8'h0A, "R0 unchanged   ");
        check_pc (8'h04,        "PC after STORE ");

        // =====================================================================
        // Cycle 5 (posedge 7): PC=4 → SUB R3, R1, R2
        //   Expected: R3 = 0x07 - 0x03 = 0x04,  PC becomes 0x05
        // =====================================================================
        $display("\n--- Cycle 5 | PC=4 | SUB R3, R1, R2 ---");
        @(posedge clk); #1;
        check_reg(2'd3, 8'h04, "SUB R3=R1-R2   ");
        check_pc (8'h05,       "PC after SUB   ");

        // =====================================================================
        // Cycle 6 (posedge 8): PC=5 → AND R0, R1, R2
        //   Expected: R0 = 0x07 & 0x03 = 0x03,  PC becomes 0x06
        // =====================================================================
        $display("\n--- Cycle 6 | PC=5 | AND R0, R1, R2 ---");
        @(posedge clk); #1;
        check_reg(2'd0, 8'h03, "AND R0=R1&R2   ");
        check_pc (8'h06,       "PC after AND   ");

        // =====================================================================
        // Cycle 7 (posedge 9): PC=6 → OR R0, R1, R2
        //   Expected: R0 = 0x07 | 0x03 = 0x07,  PC becomes 0x07
        // =====================================================================
        $display("\n--- Cycle 7 | PC=6 | OR R0, R1, R2 ---");
        @(posedge clk); #1;
        check_reg(2'd0, 8'h07, "OR  R0=R1|R2   ");
        check_pc (8'h07,       "PC after OR    ");

        // =====================================================================
        // Cycle 8 (posedge 10): PC=7 → JUMP 0x00
        //   Expected: PC loops back to 0x00
        // =====================================================================
        $display("\n--- Cycle 8 | PC=7 | JUMP 0x00 ---");
        @(posedge clk); #1;
        check_pc(8'h00, "JUMP PC=0x00   ");

        // =====================================================================
        // Cycle 9 (posedge 11): PC=0 again → LOAD R1 re-executes (loop verify)
        //   R1 should still be 0x07 after re-executing LOAD
        // =====================================================================
        $display("\n--- Cycle 9 | PC=0 (looped) | LOAD R1 re-exec ---");
        @(posedge clk); #1;
        check_reg(2'd1, 8'h07, "R1 after loop  ");
        check_pc (8'h01,       "PC after loop  ");

        // ── Final summary ─────────────────────────────────────────────────────
        $display("");
        $display("╔══════════════════════════════════════════════════════╗");
        if (errors == 0)
            $display("║   RESULT: ALL %0d CHECKS PASSED — PROCESSOR OK ✓    ║", tests);
        else
            $display("║   RESULT: %0d / %0d CHECKS FAILED ✗                 ║", errors, tests);
        $display("╚══════════════════════════════════════════════════════╝");
        $display("");

        $finish;
    end

endmodule
