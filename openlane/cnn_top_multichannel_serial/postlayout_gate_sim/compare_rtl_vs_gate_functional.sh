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

RTL_LOG="${OUT_DIR}/run_rtl_wrapper_functional.log"
GATE_LOG="${OUT_DIR}/run_gate_functional_full.log"
RTL_SUMMARY="${OUT_DIR}/rtl_wrapper_functional.summary"
GATE_SUMMARY="${OUT_DIR}/gate_functional_full.summary"
DIFF_SUMMARY="${OUT_DIR}/rtl_vs_gate_functional.diff"

echo "=== Generate shared MNIST sample index ${INDEX} ==="
python3 scripts/make_mnist_sample_hex_raw.py --index "$INDEX"

echo ""
echo "=== Golden model reference ==="
python3 scripts/golden_q8_8_rescale.py --wrap-only | tee rtl_sequential/golden_multichannel_serial.log

echo ""
echo "=== Run RTL wrapper functional baseline ==="
bash openlane/cnn_top_multichannel_serial/postlayout_gate_sim/run_rtl_wrapper_functional.sh

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
    echo "[PASS] Bit-exact score summary matches between RTL wrapper and post-layout gate-level netlist."
else
    rtl_class="$(sed -n 's/^predicted_class = \\([0-9][0-9]*\\),.*/\\1/p' "$RTL_SUMMARY" | tail -1)"
    gate_class="$(sed -n 's/^predicted_class = \\([0-9][0-9]*\\),.*/\\1/p' "$GATE_SUMMARY" | tail -1)"
    rtl_cycles="$(sed -n 's/^valid_out received after \\([0-9][0-9]*\\) cycles.*/\\1/p' "$RTL_SUMMARY" | tail -1)"
    gate_cycles="$(sed -n 's/^valid_out received after \\([0-9][0-9]*\\) cycles.*/\\1/p' "$GATE_SUMMARY" | tail -1)"

    if [[ "$rtl_class" == "$gate_class" && "$rtl_cycles" == "$gate_cycles" ]]; then
        echo "[WARN] Score vectors differ, so this is not bit-exact equivalence."
        echo "[PASS] Application-level result matches: predicted_class=${gate_class}, cycles=${gate_cycles}."
        if [[ "${STRICT_COMPARE:-0}" == "1" ]]; then
            echo "[FAIL] STRICT_COMPARE=1 requires bit-exact score equality."
            exit 1
        fi
    else
        echo "[FAIL] RTL and post-layout gate-level functional behavior differ."
        echo "       RTL:  predicted_class=${rtl_class:-missing}, cycles=${rtl_cycles:-missing}"
        echo "       Gate: predicted_class=${gate_class:-missing}, cycles=${gate_cycles:-missing}"
        exit 1
    fi
fi
