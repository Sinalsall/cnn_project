#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT_DIR"

export PATH="/foss/tools/iverilog/bin:/foss/tools/yosys/bin:/foss/tools/verilator/bin:${PATH}"
export LD_LIBRARY_PATH="/foss/tools/iverilog/lib:${LD_LIBRARY_PATH:-}"

INDEX="${1:-0}"
OUT_DIR="openlane/cnn_top_multichannel_serial/postlayout_gate_sim/build"
mkdir -p "$OUT_DIR"

if [[ "${_COMPARE_TERMINAL_LOG_ACTIVE:-0}" != "1" ]]; then
    export _COMPARE_TERMINAL_LOG_ACTIVE=1
    exec > >(tee "${OUT_DIR}/terminal_rtl_vs_gate_functional.log") 2>&1
fi

RTL_LOG="rtl_sequential/run_multichannel_serial_tb.log"
GATE_LOG="${OUT_DIR}/run_gate_functional_full.log"
RTL_SUMMARY="${OUT_DIR}/rtl_functional.summary"
GATE_SUMMARY="${OUT_DIR}/gate_functional_full.summary"
DIFF_SUMMARY="${OUT_DIR}/rtl_vs_gate_functional.diff"

echo "=== Generate shared MNIST sample index ${INDEX} ==="
python3 scripts/make_mnist_sample_hex_raw.py --index "$INDEX"

echo ""
echo "=== Run RTL functional baseline ==="
bash rtl_sequential/run_mnist_image_serial.sh "$INDEX"

echo ""
echo "=== Run post-layout gate-level functional simulation ==="
bash openlane/cnn_top_multichannel_serial/postlayout_gate_sim/run_gate_functional_full.sh

echo ""
echo "=== Extract comparable result lines ==="
grep -E "class_scores\\[|valid_out received|predicted_class|\\[FAIL\\]" "$RTL_LOG" \
    > "$RTL_SUMMARY"
grep -E "class_scores\\[|valid_out received|predicted_class|\\[FAIL\\]" "$GATE_LOG" \
    > "$GATE_SUMMARY"

echo "--- RTL summary ---"
cat "$RTL_SUMMARY"

echo ""
echo "--- Gate-level summary ---"
cat "$GATE_SUMMARY"

echo ""
echo "=== Compare RTL vs gate-level summaries ==="
if diff -u "$RTL_SUMMARY" "$GATE_SUMMARY" | tee "$DIFF_SUMMARY"; then
    echo "[PASS] RTL and post-layout gate-level functional summaries match."
else
    echo "[FAIL] RTL and post-layout gate-level functional summaries differ."
    exit 1
fi
