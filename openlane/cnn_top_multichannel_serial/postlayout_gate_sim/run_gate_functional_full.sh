#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT_DIR"

export PATH="/foss/tools/iverilog/bin:/foss/tools/yosys/bin:/foss/tools/verilator/bin:${PATH}"
export LD_LIBRARY_PATH="/foss/tools/iverilog/lib:${LD_LIBRARY_PATH:-}"

OUT_DIR="openlane/cnn_top_multichannel_serial/postlayout_gate_sim/build"
RUN_DIR="openlane/cnn_top_multichannel_serial/runs/wrapper_academic_final"
PDK_SC="/foss/pdks/gf180mcuD/libs.ref/gf180mcu_fd_sc_mcu7t5v0/verilog"
STD_CELL_MODEL="${PDK_SC}/gf180mcu_fd_sc_mcu7t5v0.v"
STD_CELL_MODEL_NOSPEC="${OUT_DIR}/gf180mcu_fd_sc_mcu7t5v0.nospec.v"
SRAM_MODEL="third_party/gf180mcu_ocd_ip_sram/sram1024x8m8wm1/gf180mcu_ocd_ip_sram__sram1024x8m8wm1.v"
SRAM_MODEL_NOSPEC="${OUT_DIR}/gf180mcu_ocd_ip_sram__sram1024x8m8wm1.nospec.v"
NETLIST="${RUN_DIR}/final/nl/cnn_top_multichannel_serial_with_param_sram.nl.v"
TB="openlane/cnn_top_multichannel_serial/postlayout_gate_sim/tb_cnn_top_multichannel_serial_gate_sdf.v"

mkdir -p "$OUT_DIR"

if [[ "${_GATE_FUNCTIONAL_TERMINAL_LOG_ACTIVE:-0}" != "1" ]]; then
    export _GATE_FUNCTIONAL_TERMINAL_LOG_ACTIVE=1
    exec > >(tee "${OUT_DIR}/terminal_gate_functional_full.log") 2>&1
fi

# Icarus Verilog does not support the GF180 specify/SDF timing constructs
# well enough for strict back-annotated simulation. This full run is a
# functional gate-level simulation of the final OpenLane netlist.
awk '
    /^[[:space:]]*specify[[:space:]]*$/ { skip = 1; next }
    /^[[:space:]]*endspecify[[:space:]]*$/ { skip = 0; next }
    !skip { print }
' "$STD_CELL_MODEL" > "$STD_CELL_MODEL_NOSPEC"

awk '
    /^[[:space:]]*specify[[:space:]]*$/ { skip = 1; next }
    /^[[:space:]]*endspecify[[:space:]]*$/ { skip = 0; next }
    !skip {
        gsub(/#Tdly/, "#0");
        print
    }
' "$SRAM_MODEL" > "$SRAM_MODEL_NOSPEC"

echo "=== Compile post-layout gate-level functional simulation ==="
iverilog -g2012 -Ttyp \
    -s tb_cnn_top_multichannel_serial_gate_sdf \
    -o "${OUT_DIR}/tb_gate_functional_full.vvp" \
    "${PDK_SC}/primitives.v" \
    "$STD_CELL_MODEL_NOSPEC" \
    "$SRAM_MODEL_NOSPEC" \
    "$NETLIST" \
    "$TB" \
    2>&1 | tee "${OUT_DIR}/compile_gate_functional_full.log"

echo ""
echo "=== Run post-layout gate-level functional simulation ==="
vvp "${OUT_DIR}/tb_gate_functional_full.vvp" \
    2>&1 | tee "${OUT_DIR}/run_gate_functional_full.log"

echo ""
echo "=== Extract post-layout gate-level result summary ==="
grep -E "class_scores\\[|valid_out received|predicted_class|\\[FAIL\\]" \
    "${OUT_DIR}/run_gate_functional_full.log" \
    | tee "${OUT_DIR}/gate_functional_full.summary"
