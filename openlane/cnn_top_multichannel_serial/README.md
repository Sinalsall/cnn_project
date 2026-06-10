# CNN OpenLane Academic Signoff Guide

This directory contains the OpenLane setup for the sequential CNN top with GF180 SRAM macros.

## Design Target

- OpenLane top: `cnn_top_multichannel_serial_with_param_sram`
- OpenLane config: `config.yaml`
- Timing constraints: `base.sdc`
- PDK: `gf180mcuD`
- Standard-cell library: `gf180mcu_fd_sc_mcu7t5v0`
- SRAM macro: `gf180mcu_ocd_ip_sram__sram1024x8m8wm1`
- Macro count: 48 SRAM1024x8 macros
- Clock period: `100 ns`

## Academic Final Run

Use this command from the repository root:

```sh
PATH=/foss/tools/bin:/foss/tools/openroad/bin:/foss/tools/openroad-latest/bin:/foss/tools/magic/bin:/foss/tools/netgen/bin:/foss/tools/verilator/bin:/foss/tools/yosys/bin:/foss/tools/klayout:$PATH \
openlane --condensed --manual-pdk --pdk-root /foss/pdks \
  -p gf180mcuD -s gf180mcu_fd_sc_mcu7t5v0 -j 4 \
  --run-tag wrapper_academic_final \
  openlane/cnn_top_multichannel_serial/config.yaml \
  2>&1 | tee openlane/cnn_top_multichannel_serial/runs/wrapper_academic_final.terminal.log
```

The `tee` file is the terminal transcript. `runtime.txt` files are not terminal transcripts; they only record step runtime.

## Important Logs

For the final run tag `wrapper_academic_final`, inspect:

- `runs/wrapper_academic_final.terminal.log`: full terminal transcript from `tee`
- `runs/wrapper_academic_final/flow.log`: OpenLane flow log
- `runs/wrapper_academic_final/warning.log`: aggregated warnings
- `runs/wrapper_academic_final/error.log`: aggregated errors; expected to be empty for the academic final run
- `runs/wrapper_academic_final/*/state_out.json`: metrics after each step
- `runs/wrapper_academic_final/*-misc-reportmanufacturability/manufacturability.rpt`: final manufacturability summary
- `runs/wrapper_academic_final/*-netgen-lvs/netgen-lvs.log`: LVS log
- `runs/wrapper_academic_final/*-openroad-stapostpnr/summary.rpt`: post-route STA summary

Step numbers can change when steps are enabled/disabled. Use `find` instead of hard-coding step numbers:

```sh
find openlane/cnn_top_multichannel_serial/runs/wrapper_academic_final \
  -maxdepth 2 -type d -name '*misc-reportmanufacturability' -print
```

## Metrics Command

This command finds the manufacturability step automatically and prints the key metrics:

```sh
STATE_OUT="$(find openlane/cnn_top_multichannel_serial/runs/wrapper_academic_final \
  -maxdepth 2 -path '*misc-reportmanufacturability/state_out.json' | sort | tail -1)"

jq '{
  route_drc:.metrics.route__drc_errors,
  lvs:.metrics.design__lvs_error__count,
  antenna_nets:.metrics.antenna__violating__nets,
  antenna_pins:.metrics.antenna__violating__pins,
  setup_wns:.metrics.timing__setup__wns,
  setup_tns:.metrics.timing__setup__tns,
  hold_wns:.metrics.timing__hold__wns,
  hold_tns:.metrics.timing__hold__tns,
  hold_vios:.metrics.timing__hold_vio__count,
  max_slew:.metrics.design__max_slew_violation__count,
  max_cap:.metrics.design__max_cap_violation__count,
  disconnected_pins:.metrics.design__disconnected_pin__count,
  critical_disconnected_pins:.metrics.design__critical_disconnected_pin__count,
  power_grid_violations:.metrics.design__power_grid_violation__count,
  magic_drc:.metrics.magic__drc_error__count,
  klayout_drc:.metrics.klayout__drc_error__count
}' "$STATE_OUT"
```

## Current Academic Final Metrics

From `wrapper_academic_final/76-misc-reportmanufacturability/state_out.json`:

| Check | Result |
| --- | --- |
| LVS | `0` errors, pass |
| OpenROAD route DRC | `0` errors, pass |
| Setup timing | WNS `0`, TNS `0`, pass |
| Power-grid checker | `0` violations, pass |
| Critical disconnected pins | `0`, pass |
| Disconnected pins | `3`, non-critical |
| Antenna | `2` nets / `2` pins remain |
| Hold timing | WNS `-1.8919986113330016`, TNS `-15.952171590746469`, `107` violations |
| Max slew | `498` violations |
| Max cap | `21` violations |
| Magic DRC | skipped in academic final; covered by SRAM/macro waiver evidence |
| KLayout DRC | unsupported for `gf180mcuD`; skipped/waived |

Manufacturability summary:

```text
Antenna: Failed, 2 pin violations, 2 net violations
LVS: Passed
DRC: N/A
```

## Known Warnings

These warnings are expected in the academic final run and are not the same as fatal errors:

- `PDN-0110 No via inserted...`
  - OpenROAD cannot place some PDN vias near SRAM macro obstructions.
  - The important evidence is that `design__power_grid_violation__count = 0` and LVS passes.
- `GRT-0097 No global routing found for nets`
  - Appears during intermediate STA/check steps before or between global-routing states.
  - Final detailed routing still reports `route__drc_errors = 0`.
- `STA-1140 library ... already exists`
  - Duplicate SRAM Liberty library loading warning.
  - Non-fatal.
- `LEF58_ENCLOSURE with no CUTCLASS is not supported`
  - TritonRoute warning for unsupported LEF58 rule syntax.
  - Final route DRC is still clean.
- `GPL_CELL_PADDING is set to 0`
  - Diode insertion legalization warning.
  - Final detailed-route DRC is still clean.

## Academic Waivers

This is an academic signoff, not strict tapeout signoff. The paper/report should explicitly state these waivers:

- Magic full-GDS DRC is dominated by SRAM/macro integration issues.
- Standalone SRAM Magic DRC evidence is documented in `signoff_evidence/signoff_status.md`.
- Magic abstract DRC with `MAGIC_DRC_USE_GDS: false` failed because Magic did not import the external SRAM macro LEF correctly.
- KLayout DRC is unsupported for this `gf180mcuD` OpenLane setup.
- Remaining antenna, hold, max slew, and max cap violations are documented academic limitations.

## Files To Commit

Commit source/config/documentation files:

- `config.yaml`
- `base.sdc`
- `macro_placement.cfg`
- `pdn_sram1024.tcl`
- `pin_order.cfg`
- `magic_sram_drc.tcl`
- `README.md`
- `signoff_evidence/signoff_status.md`

Do not commit generated run directories or large reports:

- `runs/`
- `*.terminal.log`
- generated `*.gds`, `*.spice`, `*.spef`, `*.sdf`, `*.odb`, `*.def`
- large `signoff_evidence/*.rpt`

These are ignored by the repository `.gitignore`.

## Paper Result Statement

Suggested concise wording:

> The final academic OpenLane run for the GF180 sequential CNN with 48 SRAM macros generated GDS and SPICE, passed Netgen LVS, passed OpenROAD detailed-route DRC, passed setup timing, passed the OpenROAD power-grid checker, and had zero critical disconnected pins. Remaining limitations are two antenna violations, hold timing violations, max slew/max cap violations, and SRAM/macro-related Magic DRC issues, which are documented as academic waivers.
