# Sequential CNN RTL with GF180 SRAM Banks

This project contains a sequential/time-division-multiplexed CNN RTL design intended as a layout-friendly baseline for OpenLane/GF180 bring-up.

## Current Status

The active implementation is in `rtl_sequential/`.

Implemented and verified so far:

- Full CNN architecture:
  - Conv1 1->10
  - ReLU
  - Conv2 10->10
  - ReLU
  - MaxPool1 28x28 -> 14x14
  - Conv3 10->10
  - ReLU
  - Conv4 10->10
  - ReLU
  - MaxPool2 14x14 -> 7x7
  - FC 490 -> 10
- Q8.8 fixed-point arithmetic.
- MAC product rescale uses arithmetic shift `>>> 8`.
- Weights and biases are stored through SRAM banks.
- Intermediate activations are stored through SRAM banks.
- Simulation against the Python golden model passes for the current MNIST sample flow.

The RTL has progressed into OpenLane physical-design bring-up. A first full GDS/SPICE/LVS run exists, and the current work is focused on closing residual antenna/timing issues before treating the layout as signoff-ready.

## Key Files

### RTL Sequential

- `rtl_sequential/cnn_top_multichannel_serial.v`  
  Main sequential CNN top.

- `rtl_sequential/cnn_param_sram_bank.v`  
  SRAM bank for Conv/FC weights and biases.

- `rtl_sequential/cnn_activation_sram_bank.v`  
  SRAM bank for feature-map activations.

- `rtl_sequential/sram16_1024_wrapper.v`  
  16-bit SRAM wrapper built from two 8-bit GF180 SRAM macros.

- `gf180mcu_ocd_ip_sram__sram1024x8m8wm1.v`  
  GF180 SRAM simulation model from Open Circuit Design / R. Timothy Edwards' SRAM repository.

### Scripts

- `scripts/make_mnist_sample_hex_raw.py`  
  Generates a Q8.8 MNIST input hex file.

- `scripts/golden_q8_8_rescale.py`  
  Python golden model using Q8.8 product rescale.

- `rtl_sequential/run_mnist_image_serial.sh`  
  Generates a MNIST sample, runs golden model, compiles RTL, and runs the sequential RTL simulation.

- `rtl_sequential/run_activation_sram_bank_tb.sh`  
  Unit test for the activation SRAM bank.

## Run Simulation

From the project root:

```bash
./rtl_sequential/run_mnist_image_serial.sh 0
```

Expected baseline for MNIST index 0:

```text
true label  = 7
RTL predict = 7
best score  = 4389 / 0x1125
```

Run activation SRAM unit test:

```bash
./rtl_sequential/run_activation_sram_bank_tb.sh
```

Expected result:

```text
[PASS] activation SRAM bank test passed
```

## Tool Paths

The Chipathon container may require these paths:

```bash
export PATH=/foss/tools/iverilog/bin:/foss/tools/yosys/bin:/foss/tools/verilator/bin:$PATH
export LD_LIBRARY_PATH=/foss/tools/iverilog/lib:${LD_LIBRARY_PATH:-}
```

The runner scripts set these automatically.

## SRAM Macro Source

The 1024x8 SRAM macro model is from:

https://github.com/RTimothyEdwards/gf180mcu_ocd_ip_sram/tree/main/cells

The macro is licensed under Apache-2.0 as indicated in the source header.

## OpenLane Status

OpenLane bring-up is active under:

```text
openlane/cnn_top_multichannel_serial/
```

Current layout top:

```text
cnn_top_multichannel_serial_with_param_sram
```

Current physical-design status:

- 48 SRAM1024x8 macros are integrated:
  - 32 macros for activation SRAM.
  - 16 macros for parameter SRAM.
- Synthesis, floorplan, macro placement, PDN, placement, CTS, routing, RCX, GDS streamout, SPICE extraction, and LVS have been brought up.
- Previous full run `wrapper_full_001` produced GDS and SPICE, and LVS passed.
- Current optimized config enables diode insertion plus post-GRT design/timing repair.
- Latest routing/timing optimization status:
  - route DRC clean.
  - disconnected pins clean.
  - setup timing clean at 100 ns.
  - residual issues remain: antenna, hold, max slew, and max cap.

Known best checkpoints:

- `wrapper_full_001`: first full GDS/SPICE/LVS run.
- `wrapper_antenna_003`: best antenna-only route so far, 6 antenna nets / 6 pins.
- `wrapper_repairtiming_001`: better hold/slew/cap trade-off, 10 antenna nets / 10 pins.

See `openlane/README.md` for commands to regenerate GDS/SPICE/LVS and continue signoff.

## Notes

Large simulation artifacts such as `.vcd`, `.vvp`, logs, downloaded MNIST data, and batch outputs are ignored by `.gitignore` and should not be committed.
