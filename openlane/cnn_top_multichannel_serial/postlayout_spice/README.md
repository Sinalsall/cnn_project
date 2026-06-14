# CNN Post-Layout SPICE Setup

This directory prepares a reproducible ngspice smoke-test deck for the latest
OpenLane post-layout SPICE output.

## Important Files

Latest OpenLane extracted SPICE:

```text
openlane/cnn_top_multichannel_serial/runs/wrapper_academic_final/final/spice/cnn_top_multichannel_serial_with_param_sram.spice
```

GF180 ngspice device models:

```text
/foss/pdks/gf180mcuD/libs.tech/ngspice/design.ngspice
/foss/pdks/gf180mcuD/libs.tech/ngspice/sm141064.ngspice
/foss/pdks/gf180mcuD/libs.tech/ngspice/sm141064_mim.ngspice
```

The earlier search failed because `rg` was not in the user's shell PATH. Use
plain `grep` if needed:

```sh
find /foss /pdks -type f \( -name '*.spice' -o -name '*.sp' -o -name '*.lib' -o -name '*.mod' -o -name '*.ngspice' \) \
  -exec grep -HEn '^[[:space:]]*\.(model|subckt)[[:space:]]+(nfet_06v0|pfet_06v0|nfet_03v3|pfet_03v3)([[:space:]]|$)' {} + 2>/dev/null
```

For this environment, the real GF180 device definitions are in `.lib` sections
inside `sm141064.ngspice`, especially:

```text
nfet_03v3_t
pfet_03v3_t
nfet_06v0_t
pfet_06v0_t
nfet_06v0_nvt_t
fets_mm
dio
```

## Generate The Smoke Deck

From the repository root:

```sh
bash openlane/cnn_top_multichannel_serial/postlayout_spice/prepare_postlayout_spice.sh wrapper_academic_final
```

Generated files are written to:

```text
openlane/cnn_top_multichannel_serial/postlayout_spice/build/wrapper_academic_final/
```

The generated files include:

- `cnn_top_multichannel_serial_with_param_sram.top_only.spice`
  - top extracted SPICE with the initial Magic black-box stubs removed
- `sram1024_core_renamed.spice`
  - the third-party SRAM SPICE with the top subckt renamed to a `_core` name
- `sram1024_openlane_pin_wrapper.spice`
  - adapter from OpenLane/Magic SRAM pin order to the third-party SRAM pin order
- `tb_smoke.spice`
  - ngspice deck with GF180 models, standard-cell SPICE, SRAM wrapper, top SPICE, and minimal stimulus

## Run The Smoke Test

```sh
ngspice -b \
  -o openlane/cnn_top_multichannel_serial/postlayout_spice/build/wrapper_academic_final/tb_smoke.log \
  openlane/cnn_top_multichannel_serial/postlayout_spice/build/wrapper_academic_final/tb_smoke.spice
```

This smoke test is intended to prove that:

- GF180 transistor models are found.
- Standard-cell subcircuits are found.
- SRAM subcircuits are found through the pin-order wrapper.
- The top-level extracted SPICE can elaborate.
- Clock/reset startup can begin.

It is not intended to simulate the full CNN/MNIST workload. A full transistor
simulation of the entire top with 48 SRAM macros is likely too heavy for normal
academic turnaround. Use gate-level simulation with SDF for full functional
post-layout behavior, and use this SPICE deck as transistor-level evidence.

On this project, a 30-second guarded ngspice run reached model/deck loading
without reporting missing GF180 transistor models or missing SRAM/standard-cell
subcircuits, then timed out because the real-SRAM full-chip deck is large. That
is expected for this design size.
