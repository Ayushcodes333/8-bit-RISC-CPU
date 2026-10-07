#!/usr/bin/env bash
# =============================================================================
# Script  : simulate.sh
# Project : 8-Bit Single-Cycle RISC Microprocessor
#
# Description:
#   One-command simulation driver.  Compiles all Verilog source files and
#   testbenches with Icarus Verilog (iverilog), then runs both simulations
#   with vvp.  VCD waveform files are written to sim_out/ for viewing in
#   GTKWave.
#
# Usage:
#   chmod +x simulate.sh       # (first time only)
#   ./simulate.sh              # run everything
#   ./simulate.sh alu          # run ALU testbench only
#   ./simulate.sh top          # run top-level testbench only
#
# Dependencies:
#   iverilog  — Icarus Verilog compiler  (https://bleyer.org/icarus/)
#   vvp       — Icarus Verilog runtime   (bundled with iverilog)
#   gtkwave   — optional waveform viewer (https://gtkwave.sourceforge.net/)
#
# Output files:
#   sim_out/alu_tb        compiled ALU simulation executable
#   sim_out/top_tb        compiled top-level simulation executable
#   sim_out/alu_tb.vcd    ALU waveform (open with: gtkwave sim_out/alu_tb.vcd)
#   sim_out/top_tb.vcd    system waveform (open with: gtkwave sim_out/top_tb.vcd)
# =============================================================================

set -euo pipefail   # exit on error, unset variable, or pipe failure

# ── ANSI colour helpers ────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'   # No Colour

pass() { echo -e "${GREEN}[PASS]${NC} $*"; }
fail() { echo -e "${RED}[FAIL]${NC} $*"; }
info() { echo -e "${CYAN}[INFO]${NC} $*"; }
step() { echo -e "\n${BOLD}${YELLOW}▶ $*${NC}"; }

# ── Detect script location so paths are correct regardless of CWD ─────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# ── Output directory ───────────────────────────────────────────────────────────
OUT_DIR="sim_out"
mkdir -p "$OUT_DIR"

# ── Source file lists ──────────────────────────────────────────────────────────
RTL_SOURCES=(
    src/alu.v
    src/pc.v
    src/register_file.v
    src/memory.v
    src/control_unit.v
    src/top.v
)

ALU_SOURCES=(
    src/alu.v
    tb/alu_tb.v
)

TOP_SOURCES=(
    "${RTL_SOURCES[@]}"
    tb/top_tb.v
)

# ── Icarus Verilog flags ───────────────────────────────────────────────────────
IVERILOG_FLAGS="-g2012 -Wall"

# ── Track overall result ───────────────────────────────────────────────────────
OVERALL_PASS=true

# ── Argument handling (default = run both) ────────────────────────────────────
RUN_ALU=true
RUN_TOP=true

if [[ $# -ge 1 ]]; then
    case "$1" in
        alu)  RUN_TOP=false ;;
        top)  RUN_ALU=false ;;
        *)
            echo "Usage: $0 [alu|top]"
            echo "  (no argument = run both testbenches)"
            exit 1
            ;;
    esac
fi

# =============================================================================
# Print banner
# =============================================================================
echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║     8-Bit Single-Cycle RISC Microprocessor — Simulation      ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
info "Output directory : $OUT_DIR/"
info "Verilog standard : SystemVerilog 2012 (-g2012)"
info "VCD viewer hint  : gtkwave $OUT_DIR/top_tb.vcd"

# =============================================================================
# Helper: compile_and_run <label> <output_bin> <sources...>
# =============================================================================
compile_and_run() {
    local label="$1"
    local out_bin="$2"
    shift 2
    local sources=("$@")

    # ── Compile ────────────────────────────────────────────────────────────────
    step "Compiling $label"
    echo "  iverilog $IVERILOG_FLAGS -o $OUT_DIR/$out_bin ${sources[*]}"

    if iverilog $IVERILOG_FLAGS -o "$OUT_DIR/$out_bin" "${sources[@]}" 2>&1; then
        pass "Compilation succeeded → $OUT_DIR/$out_bin"
    else
        fail "Compilation FAILED for $label"
        OVERALL_PASS=false
        return 1
    fi

    # ── Simulate ───────────────────────────────────────────────────────────────
    step "Simulating $label"
    echo "  vvp $OUT_DIR/$out_bin"
    echo ""

    if vvp "$OUT_DIR/$out_bin"; then
        echo ""
        pass "Simulation finished without runtime errors."
    else
        echo ""
        fail "Simulation reported errors for $label (vvp exit code: $?)"
        OVERALL_PASS=false
        return 1
    fi
}

# =============================================================================
# Run ALU testbench
# =============================================================================
if $RUN_ALU; then
    compile_and_run "ALU Testbench" "alu_tb" "${ALU_SOURCES[@]}" || true
fi

# =============================================================================
# Run top-level testbench
# =============================================================================
if $RUN_TOP; then
    compile_and_run "Top-Level (System) Testbench" "top_tb" "${TOP_SOURCES[@]}" || true
fi

# =============================================================================
# Final summary
# =============================================================================
echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
if $OVERALL_PASS; then
    echo -e "${BOLD}${GREEN}║         ALL SIMULATIONS COMPLETED SUCCESSFULLY ✓             ║${NC}"
else
    echo -e "${BOLD}${RED}║         ONE OR MORE SIMULATIONS FAILED — SEE LOG ABOVE ✗     ║${NC}"
fi
echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"

echo ""
if $RUN_ALU && [[ -f "$OUT_DIR/alu_tb.vcd" ]]; then
    info "ALU waveform    : gtkwave $OUT_DIR/alu_tb.vcd"
fi
if $RUN_TOP && [[ -f "$OUT_DIR/top_tb.vcd" ]]; then
    info "System waveform : gtkwave $OUT_DIR/top_tb.vcd"
fi
echo ""

# Exit with non-zero code if anything failed (useful in CI pipelines)
$OVERALL_PASS && exit 0 || exit 1
