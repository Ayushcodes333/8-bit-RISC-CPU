// =============================================================================
// Module  : alu_tb  (ALU Unit Testbench)
// Project : 8-Bit Single-Cycle RISC Microprocessor
// File    : tb/alu_tb.v
//
// Description:
//   Self-checking unit testbench for the ALU module.  Applies stimulus for all
//   four operations across normal, boundary, zero-flag, and overflow cases.
//   Each test case is checked automatically and a PASS/FAIL summary is printed.
//
// Simulation:
//   iverilog -g2012 -o sim_out/alu_tb src/alu.v tb/alu_tb.v
//   vvp sim_out/alu_tb
//   → generates sim_out/alu_tb.vcd
// =============================================================================

`timescale 1ns/1ps

module alu_tb;

    // ── DUT ports ────────────────────────────────────────────────────────────
    reg  [7:0] a, b;
    reg  [1:0] alu_op;
    wire [7:0] result;
    wire       zero;

    // ── Error counter ────────────────────────────────────────────────────────
    integer errors;
    integer tests;

    // ── DUT instantiation ────────────────────────────────────────────────────
    alu dut (
        .a      (a),
        .b      (b),
        .alu_op (alu_op),
        .result (result),
        .zero   (zero)
    );

    // =========================================================================
    // Task: apply_and_check
    //   Sets inputs, waits 10 ns for combinational paths to settle, then
    //   compares actual outputs against expected values.
    // =========================================================================
    task apply_and_check;
        input [7:0]   a_in;
        input [7:0]   b_in;
        input [1:0]   op_in;
        input [7:0]   exp_result;
        input         exp_zero;
        input [191:0] label;      // up to 24-char string
        begin
            a      = a_in;
            b      = b_in;
            alu_op = op_in;
            #10;  // allow combinational logic to settle

            tests = tests + 1;
            if (result !== exp_result || zero !== exp_zero) begin
                $display("  FAIL [%0s]  a=0x%02h b=0x%02h op=%02b | result=0x%02h(exp 0x%02h) zero=%b(exp %b)",
                         label, a, b, alu_op, result, exp_result, zero, exp_zero);
                errors = errors + 1;
            end else begin
                $display("  PASS [%0s]  => result=0x%02h  zero=%b", label, result, zero);
            end
        end
    endtask

    // =========================================================================
    // Stimulus
    // =========================================================================
    initial begin
        $dumpfile("sim_out/alu_tb.vcd");
        $dumpvars(0, alu_tb);

        errors = 0;
        tests  = 0;
        a = 0; b = 0; alu_op = 0;

        $display("");
        $display("╔══════════════════════════════════════╗");
        $display("║         ALU Testbench Start          ║");
        $display("╚══════════════════════════════════════╝");

        // ── ADD (alu_op = 2'b00) ─────────────────────────────────────────────
        $display("\n--- ADD (2'b00) ---");
        apply_and_check(8'h07, 8'h03, 2'b00, 8'h0A, 1'b0, "ADD 07+03=0A      ");
        apply_and_check(8'h00, 8'h00, 2'b00, 8'h00, 1'b1, "ADD 00+00=00 zero ");
        apply_and_check(8'hFF, 8'h01, 2'b00, 8'h00, 1'b1, "ADD FF+01 overflow");
        apply_and_check(8'hAA, 8'h55, 2'b00, 8'hFF, 1'b0, "ADD AA+55=FF      ");
        apply_and_check(8'h01, 8'hFE, 2'b00, 8'hFF, 1'b0, "ADD 01+FE=FF      ");

        // ── SUB (alu_op = 2'b01) ─────────────────────────────────────────────
        $display("\n--- SUB (2'b01) ---");
        apply_and_check(8'h07, 8'h03, 2'b01, 8'h04, 1'b0, "SUB 07-03=04      ");
        apply_and_check(8'h03, 8'h03, 2'b01, 8'h00, 1'b1, "SUB 03-03=00 zero ");
        apply_and_check(8'h00, 8'h01, 2'b01, 8'hFF, 1'b0, "SUB 00-01=FF wrap ");
        apply_and_check(8'hFF, 8'hFF, 2'b01, 8'h00, 1'b1, "SUB FF-FF=00 zero ");
        apply_and_check(8'h0A, 8'h07, 2'b01, 8'h03, 1'b0, "SUB 0A-07=03      ");

        // ── AND (alu_op = 2'b10) ─────────────────────────────────────────────
        $display("\n--- AND (2'b10) ---");
        apply_and_check(8'h07, 8'h03, 2'b10, 8'h03, 1'b0, "AND 07&03=03      ");
        apply_and_check(8'hFF, 8'h00, 2'b10, 8'h00, 1'b1, "AND FF&00=00 zero ");
        apply_and_check(8'hAA, 8'hAA, 2'b10, 8'hAA, 1'b0, "AND AA&AA=AA      ");
        apply_and_check(8'hFF, 8'hFF, 2'b10, 8'hFF, 1'b0, "AND FF&FF=FF      ");
        apply_and_check(8'hF0, 8'h0F, 2'b10, 8'h00, 1'b1, "AND F0&0F=00 zero ");

        // ── OR (alu_op = 2'b11) ──────────────────────────────────────────────
        $display("\n--- OR (2'b11) ---");
        apply_and_check(8'h07, 8'h03, 2'b11, 8'h07, 1'b0, "OR  07|03=07      ");
        apply_and_check(8'h00, 8'h00, 2'b11, 8'h00, 1'b1, "OR  00|00=00 zero ");
        apply_and_check(8'hAA, 8'h55, 2'b11, 8'hFF, 1'b0, "OR  AA|55=FF      ");
        apply_and_check(8'hF0, 8'h0F, 2'b11, 8'hFF, 1'b0, "OR  F0|0F=FF      ");
        apply_and_check(8'h00, 8'hFF, 2'b11, 8'hFF, 1'b0, "OR  00|FF=FF      ");

        // ── Summary ──────────────────────────────────────────────────────────
        $display("");
        $display("╔══════════════════════════════════════╗");
        if (errors == 0)
            $display("║  RESULT: ALL %0d TESTS PASSED ✓      ║", tests);
        else
            $display("║  RESULT: %0d / %0d TESTS FAILED ✗     ║", errors, tests);
        $display("╚══════════════════════════════════════╝");
        $display("");

        $finish;
    end

endmodule
