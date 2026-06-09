#!/usr/bin/env bash
set -euo pipefail

INDEX="${1:-0}"

ROOT_DIR="/foss/designs/RTL/RTL/RTL_Design"
cd "${ROOT_DIR}"

export PATH="/foss/tools/iverilog/bin:/foss/tools/yosys/bin:/foss/tools/verilator/bin:${PATH}"
export LD_LIBRARY_PATH="/foss/tools/iverilog/lib:${LD_LIBRARY_PATH:-}"

echo "=== Generate MNIST sample index ${INDEX} ==="
python3 scripts/make_mnist_sample_hex_raw.py --index "${INDEX}"

echo ""
echo "=== Golden model ==="
python3 scripts/golden_q8_8_rescale.py --wrap-only | tee rtl_sequential/golden_multichannel_serial.log

echo ""
echo "=== Compile RTL sequential ==="
iverilog -g2012 -Wall -DFAST_SRAM_SIM -s tb_cnn_top_multichannel_serial \
    -o rtl_sequential/tb_cnn_top_multichannel_serial.vvp \
    rtl_sequential/sram16_1024_wrapper.v \
    rtl_sequential/cnn_param_sram_bank.v \
    rtl_sequential/cnn_top_multichannel_serial.v \
    rtl_sequential/tb_cnn_top_multichannel_serial.v

echo ""
echo "=== Run RTL sequential ==="
vvp rtl_sequential/tb_cnn_top_multichannel_serial.vvp | tee rtl_sequential/run_multichannel_serial_tb.log
