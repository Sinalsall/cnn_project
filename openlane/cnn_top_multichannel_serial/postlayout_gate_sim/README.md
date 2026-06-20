# Post-Layout Gate-Level Functional Simulation

This directory contains gate-level functional simulation helpers for the
latest OpenLane academic-signoff run.

Use the smoke run first to check that the final netlist, GF180 cell models,
SRAM model, and wrapper parameter-write path elaborate correctly:

```sh
bash openlane/cnn_top_multichannel_serial/postlayout_gate_sim/run_gate_sdf_smoke.sh
```

Use the full run to simulate one complete MNIST image through the final
post-layout gate netlist:

```sh
bash openlane/cnn_top_multichannel_serial/postlayout_gate_sim/run_gate_functional_full.sh
```

Use the RTL wrapper run to simulate the pre-synthesis wrapper top with the same
testbench and SRAM behavioral model as the gate-level run:

```sh
bash openlane/cnn_top_multichannel_serial/postlayout_gate_sim/run_rtl_wrapper_functional.sh
```

Use the compare run to regenerate the same MNIST sample, run the RTL wrapper
baseline, run the final gate-level netlist, and diff the comparable result
lines:

```sh
bash openlane/cnn_top_multichannel_serial/postlayout_gate_sim/compare_rtl_vs_gate_functional.sh 0
```

The runner uses:

- Final gate netlist:
  `openlane/cnn_top_multichannel_serial/runs/wrapper_academic_final/final/nl/cnn_top_multichannel_serial_with_param_sram.nl.v`
- Final nominal SDF path requested by the testbench:
  `openlane/cnn_top_multichannel_serial/runs/wrapper_academic_final/final/sdf/nom_tt_025C_5v00/cnn_top_multichannel_serial_with_param_sram__nom_tt_025C_5v00.sdf`
- GF180 MCU 7-track standard-cell functional Verilog models.
- The behavioral SRAM model used by the project.

## Current Result

The smoke simulation passes when run with Icarus Verilog:

```text
[PASS] Gate-level SDF smoke reached post-reset state. ready_out=1 valid_out=0 last_out=0
```

Generated logs are written under `postlayout_gate_sim/build/`:

- `compile_gate_sdf.log`: compile/elaboration log.
- `run_gate_sdf_smoke.log`: simulation log.
- `terminal_gate_sdf_smoke.log`: combined terminal transcript from the script.
- `compile_gate_functional_full.log`: full functional compile log.
- `run_gate_functional_full.log`: full post-layout gate functional log.
- `gate_functional_full.summary`: extracted post-layout output scores/class.
- `compile_rtl_wrapper_functional.log`: RTL wrapper compile log.
- `run_rtl_wrapper_functional.log`: RTL wrapper functional log.
- `rtl_wrapper_functional.summary`: extracted RTL wrapper output scores/class.
- `rtl_vs_gate_functional.diff`: diff between RTL and gate summaries.
- `terminal_rtl_vs_gate_functional.log`: combined compare-run transcript.

The `build/` directory is intentionally ignored by Git.

## Important Limitation

Icarus Verilog does not support the GF180 timing `specify`/SDF constructs
needed for strict back-annotated timing simulation. The runner therefore
strips `specify` blocks from the functional cell/SRAM models so the final
gate netlist can be elaborated and smoke-tested.

Expected Icarus warning:

```text
warning: Omitting $sdf_annotate() since specify blocks and interconnects are being omitted.
```

Use the full/compare result as post-layout gate-level functional evidence. For
timing evidence in the report, cite the OpenLane/OpenROAD STA reports and final
SDF generation from `wrapper_academic_final`.

## Compare Criteria

The compare script reports two levels:

- Bit-exact score equality: all 10 output scores, cycle count, and predicted
  class match exactly.
- Application-level equality: `predicted_class` and output cycle count match,
  but one or more raw scores differ.

By default, application-level equality exits successfully and prints a warning
if the score vector is not bit-exact. Set `STRICT_COMPARE=1` when a non-zero
exit code is required for any score mismatch:

```sh
STRICT_COMPARE=1 bash openlane/cnn_top_multichannel_serial/postlayout_gate_sim/compare_rtl_vs_gate_functional.sh 0
```

For equivalence against the final layout netlist, prefer the RTL wrapper
baseline in this directory over `rtl_sequential/run_mnist_image_serial.sh`,
because the older RTL runner uses `FAST_SRAM_SIM` and a core-level testbench.
