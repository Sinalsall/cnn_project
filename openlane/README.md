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

Last known good full run:

```text
wrapper_full_001
```

That run completed:

- GDS streamout.
- SPICE extraction.
- Netgen LVS.
- LVS result: circuits match uniquely.

Known output paths from that run:

```text
openlane/cnn_top_multichannel_serial/runs/wrapper_full_001/56-magic-streamout/cnn_top_multichannel_serial_with_param_sram.gds
openlane/cnn_top_multichannel_serial/runs/wrapper_full_001/57-klayout-streamout/cnn_top_multichannel_serial_with_param_sram.klayout.gds
openlane/cnn_top_multichannel_serial/runs/wrapper_full_001/65-magic-spiceextraction/cnn_top_multichannel_serial_with_param_sram.spice
openlane/cnn_top_multichannel_serial/runs/wrapper_full_001/67-netgen-lvs/reports/lvs.netgen.rpt
```

Current optimized config status:

- Route DRC clean.
- Disconnected pins clean.
- Setup timing clean at `CLOCK_PERIOD: 100`.
- Residual signoff work remains:
  - antenna violations,
  - hold violations,
  - max slew violations,
  - max cap violations.

Best recent run tags:

| Run tag | Result |
| --- | --- |
| `wrapper_full_001` | First full GDS/SPICE/LVS run; LVS passed. |
| `wrapper_antenna_003` | Best antenna-only route: 6 nets / 6 pins. |
| `wrapper_repairtiming_001` | Better hold/slew/cap trade-off: 10 antenna nets / 10 pins, route DRC clean. |

Detailed antenna notes are in:

```text
openlane/cnn_top_multichannel_serial/antenna_iteration_notes.md
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

## Generate GDS/SPICE/LVS

Run the full flow from the current config:

```sh
openlane --condensed --manual-pdk --pdk-root /foss/pdks \
  -p gf180mcuD -s gf180mcu_fd_sc_mcu7t5v0 -j 4 \
  --run-tag wrapper_full_next \
  openlane/cnn_top_multichannel_serial/config.yaml
```

Outputs will appear under:

```text
openlane/cnn_top_multichannel_serial/runs/wrapper_full_next/
```

Typical output locations:

```text
*/magic-streamout/*.gds
*/klayout-streamout/*.gds
*/magic-spiceextraction/*.spice
*/netgen-lvs/reports/lvs.netgen.rpt
final/metrics.json
flow.log
```

Useful checks after a full run:

```sh
find openlane/cnn_top_multichannel_serial/runs/wrapper_full_next \
  -type f \( -name '*.gds' -o -name '*.spice' -o -name 'lvs.netgen.rpt' -o -name 'metrics.json' \)
```

```sh
rg -n "Final result|Circuits match|failed|ERROR|violation" \
  openlane/cnn_top_multichannel_serial/runs/wrapper_full_next/flow.log \
  openlane/cnn_top_multichannel_serial/runs/wrapper_full_next/*/reports/* 2>/dev/null
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
- `PDN-0110` warnings for some via sites around SRAM macro power pins.
- `LEF58_ENCLOSURE with no CUTCLASS is not supported` warnings in TritonRoute.
- Large-net routing warnings on several control/data nets.

Warnings that still need engineering attention:

- residual antenna violations,
- hold violations,
- max slew violations,
- max cap violations.

## Recommended Next Work

1. Optimize high-fanout/long nets reported by detailed routing and STA.
2. Keep the current post-GRT repair timing settings as the main baseline unless a new run improves antenna and timing together.
3. Re-run full GDS/SPICE/LVS after residual timing/antenna is acceptable.
4. If Magic DRC is needed, run with higher Docker memory and swap; the first full run skipped/struggled there due memory pressure.
