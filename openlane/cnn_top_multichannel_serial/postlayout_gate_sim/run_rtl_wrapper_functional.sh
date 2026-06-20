#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT_DIR"

export PATH="/foss/tools/iverilog/bin:/foss/tools/yosys/bin:/foss/tools/verilator/bin:${PATH}"
export LD_LIBRARY_PATH="/foss/tools/iverilog/lib:${LD_LIBRARY_PATH:-}"

OUT_DIR="openlane/cnn_top_multichannel_serial/postlayout_gate_sim/build"
SRAM_MODEL="third_party/gf180mcu_ocd_ip_sram/sram1024x8m8wm1/gf180mcu_ocd_ip_sram__sram1024x8m8wm1.v"
SRAM_MODEL_NOSPEC="${OUT_DIR}/gf180mcu_ocd_ip_sram__sram1024x8m8wm1.nospec.v"
TB="openlane/cnn_top_multichannel_serial/postlayout_gate_sim/tb_cnn_top_multichannel_serial_gate_sdf.v"

mkdir -p "$OUT_DIR"

if [[ "${_RTL_WRAPPER_TERMINAL_LOG_ACTIVE:-0}" != "1" ]]; then
    export _RTL_WRAPPER_TERMINAL_LOG_ACTIVE=1
    exec > >(tee "${OUT_DIR}/terminal_rtl_wrapper_functional.log") 2>&1
fi

# Keep the RTL wrapper baseline on the same SRAM behavioral model used by
# the gate-level run. Icarus cannot use the SRAM specify block, so strip it.
awk '
    /^[[:space:]]*specify[[:space:]]*$/ { skip = 1; next }
    /^[[:space:]]*endspecify[[:space:]]*$/ { skip = 0; next }
    !skip {
        gsub(/#Tdly/, "#0");
        print
    }
' "$SRAM_MODEL" > "$SRAM_MODEL_NOSPEC"

echo "=== Compile RTL wrapper functional simulation ==="
iverilog -g2012 -Ttyp \
    -s tb_cnn_top_multichannel_serial_gate_sdf \
    -o "${OUT_DIR}/tb_rtl_wrapper_functional.vvp" \
    "$SRAM_MODEL_NOSPEC" \
    rtl_sequential/sram16_1024_wrapper.v \
    rtl_sequential/cnn_activation_sram_bank.v \
    rtl_sequential/cnn_param_sram_bank.v \
    rtl_sequential/cnn_top_multichannel_serial.v \
    rtl_sequential/cnn_top_multichannel_serial_with_param_sram.v \
    "$TB" \
    2>&1 | tee "${OUT_DIR}/compile_rtl_wrapper_functional.log"

echo ""
echo "=== Run RTL wrapper functional simulation ==="
vvp "${OUT_DIR}/tb_rtl_wrapper_functional.vvp" \
    2>&1 | tee "${OUT_DIR}/run_rtl_wrapper_functional.log"

echo ""
echo "=== Extract RTL wrapper result summary ==="
grep -E "class_scores\\[|valid_out received|predicted_class|\\[FAIL\\]" \
    "${OUT_DIR}/run_rtl_wrapper_functional.log" \
    | tee "${OUT_DIR}/rtl_wrapper_functional.summary"
