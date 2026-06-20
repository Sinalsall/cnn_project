#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

export PATH="/foss/tools/bin:/foss/tools/iverilog/bin:/foss/tools/yosys/bin:/foss/tools/verilator/bin:/foss/tools/openroad/bin:/foss/tools/openroad-latest/bin:/foss/tools/magic/bin:/foss/tools/netgen/bin:/foss/tools/klayout:${PATH}"
export LD_LIBRARY_PATH="/foss/tools/iverilog/lib:${LD_LIBRARY_PATH:-}"

echo "=== CNN GitHub Smoke Test ==="
echo "[INFO] ROOT_DIR = ${ROOT_DIR}"

echo ""
echo "=== Tool check ==="
command -v python3
command -v iverilog
command -v vvp

echo ""
echo "=== Generate MNIST sample index 0 ==="
python3 scripts/make_mnist_sample_hex_raw.py --index 0

echo ""
echo "=== RTL activation SRAM unit test ==="
bash rtl_sequential/run_activation_sram_bank_tb.sh

echo ""
echo "=== RTL single-image functional test ==="
bash rtl_sequential/run_mnist_image_serial.sh 0

NETLIST="openlane/cnn_top_multichannel_serial/runs/wrapper_academic_final/final/nl/cnn_top_multichannel_serial_with_param_sram.nl.v"
if [[ -f "$NETLIST" ]]; then
    echo ""
    echo "=== Post-layout gate smoke test ==="
    bash openlane/cnn_top_multichannel_serial/postlayout_gate_sim/run_gate_sdf_smoke.sh
else
    echo ""
    echo "[SKIP] Post-layout gate smoke test skipped."
    echo "       Missing final netlist: ${NETLIST}"
    echo "       Run OpenLane first if post-layout tests are required."
fi

echo ""
echo "[DONE] GitHub smoke sequence completed."
