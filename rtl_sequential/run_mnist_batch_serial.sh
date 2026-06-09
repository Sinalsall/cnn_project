#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Sequential SRAM-backed MNIST RTL Batch Runner
#
# Usage:
#   ./rtl_sequential/run_mnist_batch_serial.sh 10
#   ./rtl_sequential/run_mnist_batch_serial.sh 100
#
# Output:
#   rtl_sequential/batch_results/serial_mnist_batch_results.csv
#   rtl_sequential/batch_results/serial_mnist_batch_summary.md
#   rtl_sequential/batch_results/logs/run_idx_<N>.log
# ============================================================

NUM_SAMPLES="${1:-10}"

ROOT_DIR="/foss/designs/RTL/RTL/RTL_Design"
SEQ_DIR="${ROOT_DIR}/rtl_sequential"
RESULT_DIR="${SEQ_DIR}/batch_results"
LOG_DIR="${RESULT_DIR}/logs"
CSV_FILE="${RESULT_DIR}/serial_mnist_batch_results.csv"
MD_FILE="${RESULT_DIR}/serial_mnist_batch_summary.md"
COMPILE_LOG="${RESULT_DIR}/compile_serial_sram_tb.log"

cd "${ROOT_DIR}"

export PATH="/foss/tools/iverilog/bin:/foss/tools/yosys/bin:/foss/tools/verilator/bin:${PATH}"
export LD_LIBRARY_PATH="/foss/tools/iverilog/lib:${LD_LIBRARY_PATH:-}"

mkdir -p "${RESULT_DIR}" "${LOG_DIR}"

echo "=== Sequential SRAM-backed MNIST RTL Batch Test ==="
echo "[INFO] ROOT_DIR    = ${ROOT_DIR}"
echo "[INFO] NUM_SAMPLES = ${NUM_SAMPLES}"
echo "[INFO] RESULT_DIR  = ${RESULT_DIR}"
echo ""

echo "[INFO] Compiling sequential SRAM-backed RTL testbench..."
iverilog -g2012 -Wall -DFAST_SRAM_SIM -s tb_cnn_top_multichannel_serial \
    -o "${SEQ_DIR}/tb_cnn_top_multichannel_serial.vvp" \
    rtl_sequential/sram16_1024_wrapper.v \
    rtl_sequential/cnn_param_sram_bank.v \
    rtl_sequential/cnn_activation_sram_bank.v \
    rtl_sequential/cnn_top_multichannel_serial.v \
    rtl_sequential/tb_cnn_top_multichannel_serial.v \
    2>&1 | tee "${COMPILE_LOG}"

if grep -iE "error|unknown|failed|syntax|not a port|unable" "${COMPILE_LOG}"; then
    echo "[FAIL] Compile has errors. Stop."
    exit 1
fi

echo "[OK] Compile passed."
echo ""

echo "index,true_label,predicted_class,correct,best_score_hex,best_score_signed,cycles" > "${CSV_FILE}"

CORRECT_COUNT=0
TOTAL_CYCLES=0

for ((idx=0; idx<NUM_SAMPLES; idx++)); do
    echo "===== MNIST index ${idx} ====="

    python3 scripts/make_mnist_sample_hex_raw.py --index "${idx}" > "${LOG_DIR}/make_idx_${idx}.log"
    TRUE_LABEL="$(cat generated_hex/mnist_sample_label.txt)"

    RUN_LOG="${LOG_DIR}/run_idx_${idx}.log"
    vvp "${SEQ_DIR}/tb_cnn_top_multichannel_serial.vvp" > "${RUN_LOG}"

    PRED_LINE="$(grep "predicted_class" "${RUN_LOG}" | tail -1 || true)"
    CYCLE_LINE="$(grep "valid_out received" "${RUN_LOG}" | tail -1 || true)"

    if [[ -z "${PRED_LINE}" || -z "${CYCLE_LINE}" ]]; then
        echo "[FAIL] index=${idx} missing prediction/cycle line. See ${RUN_LOG}"
        echo "${idx},${TRUE_LABEL},NA,0,NA,NA,NA" >> "${CSV_FILE}"
        continue
    fi

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

    TOTAL_CYCLES=$((TOTAL_CYCLES + CYCLES))

    echo "${idx},${TRUE_LABEL},${PRED_CLASS},${CORRECT},${BEST_SCORE_HEX},${BEST_SCORE_SIGNED},${CYCLES}" >> "${CSV_FILE}"
    echo "[${STATUS}] index=${idx} label=${TRUE_LABEL} pred=${PRED_CLASS} best=${BEST_SCORE_SIGNED}/${BEST_SCORE_HEX} cycles=${CYCLES}"
done

ACCURACY_PERCENT="$(awk -v c="${CORRECT_COUNT}" -v n="${NUM_SAMPLES}" 'BEGIN { printf "%.2f", (c/n)*100.0 }')"
AVG_CYCLES="$(awk -v c="${TOTAL_CYCLES}" -v n="${NUM_SAMPLES}" 'BEGIN { printf "%.2f", c/n }')"

echo ""
echo "=== SUMMARY ==="
echo "Correct    : ${CORRECT_COUNT}/${NUM_SAMPLES}"
echo "Accuracy   : ${ACCURACY_PERCENT}%"
echo "Avg cycles : ${AVG_CYCLES}"
echo "CSV        : ${CSV_FILE}"

{
    echo "# Sequential SRAM-backed CNN RTL MNIST Batch Summary"
    echo ""
    echo "## Configuration"
    echo ""
    echo "- RTL testbench: \`rtl_sequential/tb_cnn_top_multichannel_serial.v\`"
    echo "- Top: \`rtl_sequential/cnn_top_multichannel_serial.v\`"
    echo "- Weight/bias storage: parameter SRAM bank"
    echo "- Activation storage: activation SRAM bank"
    echo "- Fixed-point format: Q8.8"
    echo "- Product rescale: \`>>> 8\`"
    echo "- Number of samples: ${NUM_SAMPLES}"
    echo ""
    echo "## Result"
    echo ""
    echo "- Correct predictions: ${CORRECT_COUNT}/${NUM_SAMPLES}"
    echo "- Accuracy: ${ACCURACY_PERCENT}%"
    echo "- Average cycles per prediction: ${AVG_CYCLES}"
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
} > "${MD_FILE}"

echo "Markdown report: ${MD_FILE}"
echo "[DONE] Sequential batch test completed."
