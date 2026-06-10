# OpenLane Bring-Up Status

OpenLane2 bring-up files are available for the sequential CNN SRAM wrapper.

## Target

Current layout top:

```text
cnn_top_multichannel_serial_with_param_sram
```

RTL wrapper:

```text
rtl_sequential/cnn_top_multichannel_serial_with_param_sram.v
```

The wrapper instantiates:

- `cnn_top_multichannel_serial` as the sequential/TDM CNN compute core.
- `cnn_param_sram_bank` for on-chip Conv/FC weights and biases.
- `cnn_activation_sram_bank` inside the compute core for on-chip activations.

Weights and biases are loaded before inference through:

```text
param_wr_en
param_wr_addr
param_wr_data
```

## Main Config

Use:

```text
openlane/cnn_top_multichannel_serial/config.yaml
```

The current config targets `gf180mcuD` with the `gf180mcu_fd_sc_mcu7t5v0` standard-cell library and the vendored 1024x8 SRAM macro.

## SRAM Macro

The SRAM 1024x8 views are vendored under:

```text
third_party/gf180mcu_ocd_ip_sram/sram1024x8m8wm1/
```

Required views:

```text
gf180mcu_ocd_ip_sram__sram1024x8m8wm1.blackbox.v
gf180mcu_ocd_ip_sram__sram1024x8m8wm1.lef
gf180mcu_ocd_ip_sram__sram1024x8m8wm1.gds
gf180mcu_ocd_ip_sram__sram1024x8m8wm1.spice
gf180mcu_ocd_ip_sram__sram1024x8m8wm1__*.lib
```

Current macro count:

- Activation SRAM: 16 banks x 1024x16 = 32 macros of 1024x8.
- Parameter SRAM: 8 banks x 1024x16 = 16 macros of 1024x8.
- Total: 48 SRAM1024x8 macros.

`pdn_sram1024.tcl` is used because the SRAM exposes power pins on Metal1/Metal2/Metal3, while the top-level GF180 PDN grid uses upper layers. The custom PDN file adds the via ladder needed to connect SRAM VDD/VSS.

## Current Status

Academic final run:

```text
wrapper_academic_final
```

That run completed:

- GDS streamout.
- SPICE extraction.
- Netgen LVS.
- Manufacturability report generation.

Academic final result:

- LVS: pass, `design__lvs_error__count = 0`.
- OpenROAD route DRC: pass, `route__drc_errors = 0`.
- Setup timing: pass, WNS `0`, TNS `0`.
- Power-grid checker: pass, `design__power_grid_violation__count = 0`.
- Critical disconnected pins: pass, `design__critical_disconnected_pin__count = 0`.
- Antenna: 2 nets / 2 pins remain.
- Hold: remaining violations, documented as an academic waiver.
- Max slew/max cap: remaining violations, documented as academic limitations.
- Magic DRC: skipped in the academic final run; baseline full-GDS and SRAM evidence are documented separately.
- KLayout DRC: unsupported for `gf180mcuD` in this OpenLane setup.

Useful final-run paths:

```text
openlane/cnn_top_multichannel_serial/runs/wrapper_academic_final.terminal.log
openlane/cnn_top_multichannel_serial/runs/wrapper_academic_final/flow.log
openlane/cnn_top_multichannel_serial/runs/wrapper_academic_final/warning.log
openlane/cnn_top_multichannel_serial/runs/wrapper_academic_final/error.log
openlane/cnn_top_multichannel_serial/runs/wrapper_academic_final/76-misc-reportmanufacturability/state_out.json
openlane/cnn_top_multichannel_serial/runs/wrapper_academic_final/76-misc-reportmanufacturability/manufacturability.rpt
```

The step number can change if the config changes. Prefer:

```sh
find openlane/cnn_top_multichannel_serial/runs/wrapper_academic_final \
  -maxdepth 2 -type d -name '*misc-reportmanufacturability' -print
```

For a detailed teammate-facing guide, see:

```text
openlane/cnn_top_multichannel_serial/README.md
openlane/cnn_top_multichannel_serial/signoff_evidence/signoff_status.md
```

## Environment

Recommended resource settings:

- Docker RAM: preferably 12-14 GB if the host has 16 GB.
- Swap: 16-32 GB is useful.
- OpenLane jobs: start with `-j 4`.

Common command prefix:

```sh
openlane --condensed \
  --manual-pdk \
  --pdk-root /foss/pdks \
  -p gf180mcuD \
  -s gf180mcu_fd_sc_mcu7t5v0 \
  -j 4
```

## Smoke Commands

Synthesis only:

```sh
openlane --condensed --manual-pdk --pdk-root /foss/pdks \
  -p gf180mcuD -s gf180mcu_fd_sc_mcu7t5v0 -j 4 \
  --run-tag wrapper_synth_smoke \
  --to Yosys.Synthesis \
  openlane/cnn_top_multichannel_serial/config.yaml
```

Macro placement:

```sh
openlane --condensed --manual-pdk --pdk-root /foss/pdks \
  -p gf180mcuD -s gf180mcu_fd_sc_mcu7t5v0 -j 4 \
  --run-tag wrapper_macro_place_smoke \
  --to Odb.ManualMacroPlacement \
  openlane/cnn_top_multichannel_serial/config.yaml
```

PDN:

```sh
openlane --condensed --manual-pdk --pdk-root /foss/pdks \
  -p gf180mcuD -s gf180mcu_fd_sc_mcu7t5v0 -j 4 \
  --run-tag wrapper_pdn_smoke \
  --to OpenROAD.GeneratePDN \
  openlane/cnn_top_multichannel_serial/config.yaml
```

Global placement:

```sh
openlane --condensed --manual-pdk --pdk-root /foss/pdks \
  -p gf180mcuD -s gf180mcu_fd_sc_mcu7t5v0 -j 4 \
  --run-tag wrapper_gpl_smoke \
  --to OpenROAD.GlobalPlacement \
  openlane/cnn_top_multichannel_serial/config.yaml
```

## Generate Academic GDS/SPICE/LVS Evidence

Run the academic final flow from the current config:

```sh
PATH=/foss/tools/bin:/foss/tools/openroad/bin:/foss/tools/openroad-latest/bin:/foss/tools/magic/bin:/foss/tools/netgen/bin:/foss/tools/verilator/bin:/foss/tools/yosys/bin:/foss/tools/klayout:$PATH \
openlane --condensed --manual-pdk --pdk-root /foss/pdks \
  -p gf180mcuD -s gf180mcu_fd_sc_mcu7t5v0 -j 4 \
  --run-tag wrapper_academic_final \
  openlane/cnn_top_multichannel_serial/config.yaml \
  2>&1 | tee openlane/cnn_top_multichannel_serial/runs/wrapper_academic_final.terminal.log
```

Outputs will appear under:

```text
openlane/cnn_top_multichannel_serial/runs/wrapper_academic_final/
```

Typical output locations:

```text
*/magic-streamout/*.gds
*/klayout-streamout/*.gds
*/magic-spiceextraction/*.spice
*/netgen-lvs/reports/lvs.netgen.rpt
final/metrics.json
flow.log
warning.log
error.log
```

Useful checks after a full run:

```sh
find openlane/cnn_top_multichannel_serial/runs/wrapper_academic_final \
  -type f \( -name '*.gds' -o -name '*.spice' -o -name 'lvs.netgen.rpt' -o -name 'metrics.json' \)
```

```sh
STATE_OUT="$(find openlane/cnn_top_multichannel_serial/runs/wrapper_academic_final \
  -maxdepth 2 -path '*misc-reportmanufacturability/state_out.json' | sort | tail -1)"

jq '{
  route_drc:.metrics.route__drc_errors,
  lvs:.metrics.design__lvs_error__count,
  antenna_nets:.metrics.antenna__violating__nets,
  antenna_pins:.metrics.antenna__violating__pins,
  setup_wns:.metrics.timing__setup__wns,
  hold_wns:.metrics.timing__hold__wns,
  hold_vios:.metrics.timing__hold_vio__count,
  max_slew:.metrics.design__max_slew_violation__count,
  max_cap:.metrics.design__max_cap_violation__count,
  crit_disc:.metrics.design__critical_disconnected_pin__count,
  pgv:.metrics.design__power_grid_violation__count
}' "$STATE_OUT"
```

## Continue From a Checkpoint

To continue signoff from the current best repair-timing run after RCX/STA checkpoints are available, use `--with-initial-state`.

Example: rerun post-route STA from an RCX checkpoint:

```sh
openlane --condensed --manual-pdk --pdk-root /foss/pdks \
  -p gf180mcuD -s gf180mcu_fd_sc_mcu7t5v0 -j 4 \
  --run-tag wrapper_sta_resume \
  --with-initial-state openlane/cnn_top_multichannel_serial/runs/wrapper_repairtiming_001/18-openroad-rcx/state_out.json \
  --from OpenROAD.STAPostPNR \
  --to OpenROAD.STAPostPNR \
  openlane/cnn_top_multichannel_serial/config.yaml
```

Example: continue from a routed/STA checkpoint into GDS/SPICE/LVS:

```sh
openlane --condensed --manual-pdk --pdk-root /foss/pdks \
  -p gf180mcuD -s gf180mcu_fd_sc_mcu7t5v0 -j 4 \
  --run-tag wrapper_signoff_next \
  --with-initial-state openlane/cnn_top_multichannel_serial/runs/wrapper_repairtiming_001/19-openroad-stapostpnr/state_out.json \
  --from OpenROAD.IRDropReport \
  openlane/cnn_top_multichannel_serial/config.yaml
```

If the checkpoint path does not exist, inspect the run directory:

```sh
find openlane/cnn_top_multichannel_serial/runs/wrapper_repairtiming_001 \
  -maxdepth 2 -name state_out.json | sort
```

## Known Warnings

These warnings are currently known and not automatically fatal:

- Verilator width warnings in sequential RTL.
- `MACRO_PLACEMENT_CFG` deprecation warning. OpenLane recommends migrating to `MACROS`.
- `PDN-0110` warnings for some via sites around SRAM macro power pins. These are acceptable for the academic run because the OpenROAD power-grid checker reports zero violations and LVS passes.
- `GRT-0097 No global routing found for nets` during intermediate STA/check steps. Final detailed route is still clean.
- `LEF58_ENCLOSURE with no CUTCLASS is not supported` warnings in TritonRoute.
- Large-net routing warnings on several control/data nets.

Academic waiver items:

- residual antenna violations,
- hold violations,
- max slew violations,
- max cap violations.
- SRAM/macro-related Magic DRC.
- unsupported KLayout DRC for `gf180mcuD`.

## Recommended Next Work

1. For the paper, use `wrapper_academic_final` plus `signoff_evidence/signoff_status.md`.
2. If stricter signoff is required later, debug `OpenROAD.ResizerTimingPostGRT`, which fixes hold but hangs before completing the step in this environment.
3. Fix Magic abstract DRC macro loading so SRAM LEF is read before DEF import.
4. Continue antenna/DRV closure only if the academic waiver is not accepted.
