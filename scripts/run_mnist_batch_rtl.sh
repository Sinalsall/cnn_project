#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Batch MNIST RTL Test Runner
#
# Usage:
#   ./scripts/run_mnist_batch_rtl.sh 10
#   ./scripts/run_mnist_batch_rtl.sh 100
#
# Output:
#   batch_results/mnist_batch_results.csv
#   batch_results/mnist_batch_summary.md
#   batch_results/logs/run_idx_<N>.log
# ============================================================

NUM_SAMPLES="${1:-10}"

ROOT_DIR="/foss/designs/RTL/RTL/RTL_Design"
RESULT_DIR="${ROOT_DIR}/batch_results"
LOG_DIR="${RESULT_DIR}/logs"
CSV_FILE="${RESULT_DIR}/mnist_batch_results.csv"
MD_FILE="${RESULT_DIR}/mnist_batch_summary.md"

cd "${ROOT_DIR}"

export PATH="/foss/tools/iverilog/bin:/foss/tools/yosys/bin:/foss/tools/verilator/bin:${PATH}"
export LD_LIBRARY_PATH="/foss/tools/iverilog/lib:${LD_LIBRARY_PATH:-}"

mkdir -p "${RESULT_DIR}"
mkdir -p "${LOG_DIR}"

echo "=== MNIST RTL Batch Test ==="
echo "[INFO] ROOT_DIR    = ${ROOT_DIR}"
echo "[INFO] NUM_SAMPLES = ${NUM_SAMPLES}"
echo "[INFO] RESULT_DIR  = ${RESULT_DIR}"
echo ""

# ------------------------------------------------------------
# Compile RTL once
# ------------------------------------------------------------
echo "[INFO] Compiling RTL full-weight testbench..."

iverilog -g2012 -Wall -s cnn_top_full_weight_tb -o tb/cnn_top_full_weight_tb_sim \
    backup_parallel/cnn_convolution_index_based.v \
    backup_parallel/cnn_relu.v \
    backup_parallel/cnn_maxpool.v \
    backup_parallel/cnn_fully_connected.v \
    gf180mcu_ocd_ip_sram__sram256x8m8wm1.v \
    cnn_top_rtl_first_pass/cnn_top_rtl/cnn_conv_multi_channel_parallel.v \
    backup_parallel/cnn_multi_channel_relu.v \
    backup_parallel/cnn_multi_channel_maxpool.v \
    cnn_top_rtl_first_pass/cnn_top_rtl/cnn_fc_bias_sram_wrapper.v \
    cnn_top_rtl_first_pass/cnn_top_rtl/cnn_top_parallel_sram_fc_bias.v \
    tb/cnn_top_full_weight_tb.v \
    2>&1 | tee "${RESULT_DIR}/compile_top_full_weight_tb.log"

if grep -iE "error|unknown|failed|syntax|not a port|unable" "${RESULT_DIR}/compile_top_full_weight_tb.log"; then
    echo "[FAIL] Compile has errors. Stop."
    exit 1
fi

echo "[OK] Compile passed."
echo ""

# ------------------------------------------------------------
# CSV header
# ------------------------------------------------------------
echo "index,true_label,predicted_class,correct,best_score_hex,best_score_signed,cycles" > "${CSV_FILE}"

CORRECT_COUNT=0

# ------------------------------------------------------------
# Run samples
# ------------------------------------------------------------
for ((idx=0; idx<NUM_SAMPLES; idx++)); do
    echo "===== MNIST index ${idx} ====="

    python3 scripts/make_mnist_sample_hex_raw.py --index "${idx}" > "${LOG_DIR}/make_idx_${idx}.log"

    TRUE_LABEL="$(cat generated_hex/mnist_sample_label.txt)"

    RUN_LOG="${LOG_DIR}/run_idx_${idx}.log"
    vvp tb/cnn_top_full_weight_tb_sim > "${RUN_LOG}"

    PRED_LINE="$(grep "predicted_class" "${RUN_LOG}" | tail -1)"
    CYCLE_LINE="$(grep "valid_out received" "${RUN_LOG}" | tail -1)"

    PRED_CLASS="$(echo "${PRED_LINE}" | sed -E 's/.*predicted_class = ([0-9-]+),.*/\1/')"
    BEST_SCORE_SIGNED="$(echo "${PRED_LINE}" | sed -E 's/.*best_score = ([0-9-]+) \/ 0x[0-9a-fA-F]+.*/\1/')"
    BEST_SCORE_HEX="$(echo "${PRED_LINE}" | sed -E 's/.*\/ 0x([0-9a-fA-F]+).*/0x\1/')"
    CYCLES="$(echo "${CYCLE_LINE}" | sed -E 's/.*after ([0-9]+) cycles.*/\1/')"

    if [[ "${PRED_CLASS}" == "${TRUE_LABEL}" ]]; then
        CORRECT=1
        CORRECT_COUNT=$((CORRECT_COUNT + 1))
        STATUS="PASS"
    else
        CORRECT=0
        STATUS="FAIL"
    fi

    echo "${idx},${TRUE_LABEL},${PRED_CLASS},${CORRECT},${BEST_SCORE_HEX},${BEST_SCORE_SIGNED},${CYCLES}" >> "${CSV_FILE}"

    echo "[${STATUS}] index=${idx} label=${TRUE_LABEL} pred=${PRED_CLASS} best=${BEST_SCORE_SIGNED}/${BEST_SCORE_HEX} cycles=${CYCLES}"
done

# ------------------------------------------------------------
# Accuracy
# ------------------------------------------------------------
ACCURACY_PERCENT="$(awk -v c="${CORRECT_COUNT}" -v n="${NUM_SAMPLES}" 'BEGIN { printf "%.2f", (c/n)*100.0 }')"

echo ""
echo "=== SUMMARY ==="
echo "Correct : ${CORRECT_COUNT}/${NUM_SAMPLES}"
echo "Accuracy: ${ACCURACY_PERCENT}%"
echo "CSV     : ${CSV_FILE}"

# ------------------------------------------------------------
# Markdown report
# ------------------------------------------------------------
{
    echo "# CNN RTL MNIST Batch Verification Summary"
    echo ""
    echo "## Configuration"
    echo ""
    echo "- RTL testbench: \`tb/cnn_top_full_weight_tb.v\`"
    echo "- Weight/bias source: \`generated_hex/*.txt\`"
    echo "- Input source: MNIST test dataset"
    echo "- Fixed-point format: Q8.8"
    echo "- Product rescale: \`>>> 8\`"
    echo "- FC bias storage: SRAM proof-of-concept"
    echo "- Number of samples: ${NUM_SAMPLES}"
    echo ""
    echo "## Result"
    echo ""
    echo "- Correct predictions: ${CORRECT_COUNT}/${NUM_SAMPLES}"
    echo "- Accuracy: ${ACCURACY_PERCENT}%"
    echo ""
    echo "## Per-sample Results"
    echo ""
    echo "| Index | True Label | Predicted | Correct | Best Score | Cycles |"
    echo "|---:|---:|---:|---:|---:|---:|"

    tail -n +2 "${CSV_FILE}" | while IFS=',' read -r idx label pred correct best_hex best_signed cycles; do
        if [[ "${correct}" == "1" ]]; then
            mark="yes"
        else
            mark="no"
        fi
        echo "| ${idx} | ${label} | ${pred} | ${mark} | ${best_signed} / ${best_hex} | ${cycles} |"
    done

    echo ""
    echo "## Interpretation"
    echo ""
    echo "The RTL full-weight CNN simulation successfully completed inference for the selected MNIST samples. The test verifies that the generated Q8.8 weight/bias hex files, MNIST input hex file, convolution pipeline, ReLU, MaxPool, flatten stage, fully connected layer, and FC-bias SRAM path operate together through the top-level design."
    echo ""
    echo "This result is a functional simulation milestone. It does not yet prove OpenLane synthesis, timing closure, DRC/LVS cleanliness, or final silicon readiness."
} > "${MD_FILE}"

echo "Markdown report: ${MD_FILE}"
echo "[DONE] Batch test completed."
