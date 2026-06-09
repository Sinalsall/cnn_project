#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="/foss/designs/RTL/RTL/RTL_Design"
cd "${ROOT_DIR}"

export PATH="/foss/tools/iverilog/bin:/foss/tools/yosys/bin:/foss/tools/verilator/bin:${PATH}"
export LD_LIBRARY_PATH="/foss/tools/iverilog/lib:${LD_LIBRARY_PATH:-}"

iverilog -g2012 -Wall -DFAST_SRAM_SIM -s tb_activation_sram_bank \
    -o rtl_sequential/tb_activation_sram_bank.vvp \
    rtl_sequential/sram16_1024_wrapper.v \
    rtl_sequential/cnn_activation_sram_bank.v \
    rtl_sequential/tb_activation_sram_bank.v

vvp rtl_sequential/tb_activation_sram_bank.vvp | tee rtl_sequential/run_activation_sram_bank_tb.log
