#!/usr/bin/env bash
set -euo pipefail

NUM_SAMPLES="${1:-10}"
ROOT_DIR="/foss/designs/RTL/RTL/RTL_Design"
SEQ_DIR="${ROOT_DIR}/rtl_sequential"
RESULT_DIR="${SEQ_DIR}/batch_results"
LOG_DIR="${RESULT_DIR}/logs"
CSV_FILE="${RESULT_DIR}/sequential_batch_results.csv"
MD_FILE="${RESULT_DIR}/sequential_batch_summary.md"

cd "${ROOT_DIR}"
mkdir -p "${RESULT_DIR}" "${LOG_DIR}"

echo "=== Sequential CNN RTL MNIST Batch Test ==="
echo "[INFO] NUM_SAMPLES = ${NUM_SAMPLES}"

# 1. Compile RTL
echo "[INFO] Compiling sequential top-level and testbench..."
cd "${SEQ_DIR}"

cat << 'EOF' > tb_cnn_sram_batch.v
`timescale 1ns/1ps
module tb_cnn_sram_batch;
    reg clk;
    reg rst_n;
    reg start;
    wire done;
    wire valid_out;
    wire [3:0] class_idx;
    wire signed [15:0] score_out;

    cnn_sram_controller #(.DATA_WIDTH(16)) dut (
        .clk(clk), .rst_n(rst_n), .start(start), .done(done),
        .valid_out(valid_out), .class_idx(class_idx), .score_out(score_out)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // File I/O untuk dump logic Hex akan ditaruh di sini
    initial begin
        rst_n = 0; start = 0;
        #20 rst_n = 1;
        #10 start = 1;
        @(posedge clk) start = 0;
        
        wait(done);
        #50 $finish;
    end
endmodule
EOF

iverilog -o tb_sram_batch.vvp tb_cnn_sram_batch.v cnn_sram_controller.v cnn_top_serial.v cnn_convolution_serial.v line_buffer.v cnn_relu_stream.v cnn_maxpool_stream.v cnn_fully_connected_serial.v

# 2. Run Batch Loop
echo "index,true_label" > "${CSV_FILE}"

for ((idx=0; idx<NUM_SAMPLES; idx++)); do
    echo "===== MNIST index ${idx} ====="
    
    # Generate Hex untuk index ke-i
    python3 "${ROOT_DIR}/scripts/make_mnist_sample_hex_raw.py" --index "${idx}" > "${LOG_DIR}/make_idx_${idx}.log"
    TRUE_LABEL="$(cat ${ROOT_DIR}/generated_hex/mnist_sample_label.txt)"
    
    RUN_LOG="${LOG_DIR}/run_idx_${idx}.log"
    # Execute simulation (Ini akan melintasi Pipeline)
    vvp tb_sram_batch.vvp > "${RUN_LOG}" || true
    
    echo "${idx},${TRUE_LABEL}" >> "${CSV_FILE}"
done

echo ""
echo "=== SELESAI ==="
echo "Batch runner sudah dijalankan. Catatan: Saat ini hasil prediksi belum dikalkulasikan ke CSV karena cnn_top_serial masih dalam kerangka Proof-of-Concept 1-Channel."
