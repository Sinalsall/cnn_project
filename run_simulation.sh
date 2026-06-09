#!/bin/bash
# RTL Simulation Script for CNN Design
# This script compiles and simulates the Verilog RTL design

echo "=== CNN RTL Simulation Script ==="
echo ""

# Create output directory
mkdir -p simulation_results

# Compile Verilog files
echo "[1] Compiling Verilog files..."
iverilog -o simulation_results/cnn_sim \
    cnn_convolution.v \
    cnn_maxpool.v \
    cnn_relu.v \
    cnn_fully_connected.v \
    cnn_testbench.v

if [ $? -eq 0 ]; then
    echo "✓ Compilation successful"
else
    echo "✗ Compilation failed"
    exit 1
fi

# Run simulation
echo ""
echo "[2] Running simulation..."
cd simulation_results
vvp cnn_sim

if [ $? -eq 0 ]; then
    echo "✓ Simulation successful"
else
    echo "✗ Simulation failed"
    exit 1
fi

# Check if VCD file was created
echo ""
echo "[3] Checking simulation output..."
if [ -f "cnn_simulation.vcd" ]; then
    echo "✓ VCD file generated: cnn_simulation.vcd"
    echo ""
    echo "To view waveforms in GTKWave:"
    echo "  gtkwave cnn_simulation.vcd &"
else
    echo "✗ VCD file not found"
    exit 1
fi

echo ""
echo "=== Simulation Complete ==="
