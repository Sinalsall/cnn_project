# Sequential CNN RTL with GF180 SRAM Banks

This project contains a sequential/time-division-multiplexed CNN RTL design intended as a layout-friendly baseline for OpenLane/GF180 bring-up.

## GitHub Quickstart

Clone and run the lightweight smoke sequence:

```bash
git clone https://github.com/Sinalsall/cnn_project.git
cd cnn_project
bash scripts/run_github_smoke.sh
```

The smoke script checks the basic tools, generates MNIST sample index `0`, runs
the activation SRAM unit test, runs the RTL single-image CNN test, and runs the
post-layout gate smoke test only if the OpenLane final netlist already exists.

Full end-to-end command sequence:

```text
docs/test_execution_tutorial.md
```

GitHub upload/commit manifest:

```text
docs/github_upload_manifest.md
```

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

The RTL has progressed into OpenLane physical-design bring-up. The current repository state targets an academic signoff package: GDS/SPICE/LVS are generated, LVS and OpenROAD detailed-route DRC pass, and remaining antenna/timing/DRV/Magic-DRC limitations are documented as academic waivers.

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
- Academic final run `wrapper_academic_final` produced GDS/SPICE artifacts and terminal logging.
- LVS passed with `design__lvs_error__count = 0`.
- OpenROAD detailed-route DRC passed with `route__drc_errors = 0`.
- Setup timing is clean at 100 ns.
- Power-grid checker reports `0` violations.
- Critical disconnected pins are `0`.
- Residual academic-waived issues remain: 2 antenna nets/pins, hold violations, max slew/max cap violations, and SRAM/macro-related Magic DRC.

Important documentation:

- `docs/github_quickstart.md`: clone-and-run instructions for a fresh GitHub checkout.
- `docs/github_upload_manifest.md`: files to commit, files to ignore, and safe `git add` commands.
- `docs/test_execution_tutorial.md`: end-to-end command sequence for RTL tests, OpenLane academic signoff checks, post-layout gate functional simulation, and SPICE smoke setup.
- `openlane/cnn_top_multichannel_serial/README.md`: how to run academic signoff, where logs live, how to extract metrics, and what warnings mean.
- `openlane/cnn_top_multichannel_serial/signoff_evidence/signoff_status.md`: signoff status and waiver rationale.

See `openlane/README.md` for commands to regenerate GDS/SPICE/LVS and continue signoff.

## Notes

Large simulation artifacts such as `.vcd`, `.vvp`, logs, downloaded MNIST data, and batch outputs are ignored by `.gitignore` and should not be committed.
