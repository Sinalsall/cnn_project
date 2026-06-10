# CNN OpenLane Signoff Status

Date: 2026-06-10

## Runs

- Baseline evidence run: `wrapper_full_next`
- Latest evidence run: `wrapper_academic_final`
- PDK/SCL: `gf180mcuD` / `gf180mcu_fd_sc_mcu7t5v0`
- Clock period: `100 ns`

The `wrapper_full_next` run reached `77-misc-reportmanufacturability`. The missing folder `78` is not the main issue.

## Implemented Inputs

- Updated `base.sdc` with realistic I/O delays:
  - `rst_n` is false-pathed.
  - Synchronous inputs use `-min 1.0` and `-max 20.0`.
  - Outputs use explicit `-min 1.0` and `-max 20.0`.
- Updated `config.yaml` for signoff exploration:
  - `HEURISTIC_ANTENNA_THRESHOLD: 10`
  - `RUN_HEURISTIC_DIODE_INSERTION: true`
  - `DIODE_ON_PORTS: in`
  - `GRT_ANTENNA_ITERS: 16`
  - `GRT_ANTENNA_MARGIN: 60`
  - stronger post-GRT design repair settings
  - `RUN_ANTENNA_REPAIR: false` because `OpenROAD.RepairAntennas` hung
  - `RUN_POST_GRT_RESIZER_TIMING: false` because `OpenROAD.ResizerTimingPostGRT` hung after fixing hold
  - `RUN_IRDROP_REPORT: false` because `OpenROAD.IRDropReport` hung
  - `RUN_KLAYOUT_XOR: false`
  - `RUN_KLAYOUT_DRC: false` because KLayout DRC is unsupported for `gf180mcuD` in this setup
  - `RUN_MAGIC_DRC: false` in the latest run because abstract Magic DRC failed to import the SRAM macro LEF
  - `HOLD_VIOLATION_CORNERS: [""]` for the academic final run so hold violations are recorded as waiver evidence instead of stopping OpenLane as a deferred fatal error

## Latest Evidence Metrics

From `wrapper_academic_final/76-misc-reportmanufacturability/state_out.json`:

- LVS: `design__lvs_error__count = 0`
- OpenROAD detailed-route DRC: `route__drc_errors = 0`
- Power-grid checker: `design__power_grid_violation__count = 0`
- Critical disconnected pins: `design__critical_disconnected_pin__count = 0`
- Disconnected pins: `design__disconnected_pin__count = 3`
- Setup timing: WNS `0`, TNS `0`, setup violations `0`
- Antenna: `antenna__violating__nets = 2`, `antenna__violating__pins = 2`
- Hold timing: WNS `-1.8919986113330016`, TNS `-15.952171590746469`, violations `107`
- DRV: max slew violations `498`, max cap violations `21`
- Magic DRC: skipped in `wrapper_academic_final`; baseline full-GDS Magic DRC still reports SRAM/macro-related issues
- KLayout DRC: unsupported for `gf180mcuD` in this OpenLane setup

Compared to baseline `wrapper_full_next`, antenna improved from `10` to `2`, max slew from `680` to `498`, and max cap from `35` to `21`, while LVS and OpenROAD route DRC remained clean.

Terminal transcript for the academic run was captured with `tee` at:

- `runs/wrapper_academic_final.terminal.log`

## SRAM DRC Evidence

Standalone SRAM Magic DRC was run with `magic_sram_drc.tcl`; report:

- `signoff_evidence/sram1024_magic_drc.rpt`

The standalone SRAM GDS has Magic DRC categories including:

- `P-Diffusion overlap of contact < 0.065um (CO.4)`
- `Metal1 overlap of contact < 0.055um in one direction (CO.6)`
- `N-well overlap of P-Diffusion < 0.43um (DF.7)`
- `N-Diffusion overlap of contact < 0.065um (CO.4)`
- `N-Diffusion spacing to N-well < 0.43um (DF.8)`

Baseline top-level full-GDS Magic DRC reports `Via2 width < 0.28um (V2.1 + 2 * V2.3)`. The first baseline top-level DRC coordinates align with SRAM macro placement regions. Example: top-level coordinate around `(251.110, 387.455)` maps to macro `u_core.u_activation_sram.g_bank[0].u_bank.u_sram_lo` at `(250, 300)`, local offset about `(1.110, 87.455)`, inside the SRAM macro footprint/PDN macro region. Similar repeated offsets appear across the SRAM placement grid in `macro_placement.cfg`.

Conclusion: the full-GDS Magic DRC blocker is not caused by random standard-cell routing; it is tied to SRAM macro integration / SRAM macro collateral. This can be treated as an academic SRAM waiver only if the instructor accepts the macro collateral waiver.

## Tool Findings

- User-mentioned `/pdks/tools` was not present in this environment.
- Tools used successfully were under `/foss/tools`, including `/foss/tools/bin`, `/foss/tools/magic/bin`, `/foss/tools/netgen/bin`, `/foss/tools/yosys/bin`, `/foss/tools/verilator/bin`, and `/foss/tools/klayout`.

## Remaining Blockers

This project is not at zero-violation signoff yet.

1. Antenna remains at `2` nets / `2` pins with heuristic diode insertion threshold `10`.
2. Hold remains negative when post-GRT timing resizer is disabled. The academic final config waives fatal hold checking but does not remove the hold metrics from reports.
3. Post-GRT timing resizer fixes hold in OpenROAD logs, but hangs after legalization/global-route cleanup:
   - `wrapper_full_next_signoff7` showed `final WNS 0.222` and `31` inserted hold buffers before hanging.
   - Setting `GRT_RESIZER_RUN_GRT: false` avoids the hang but produces invalid route guides and detailed routing fails.
4. Max slew and max cap are improved but not closed.
5. Magic abstract DRC with `MAGIC_DRC_USE_GDS: false` fails to import the external SRAM macro LEF, so it cannot be used as clean top-level evidence without fixing Magic macro LEF loading.

## Practical Next Actions

The next closure attempt should focus on one of these paths:

1. Fix the OpenROAD post-GRT resizer hang, because that is the only tested path that makes hold positive.
2. Add a Magic DRC wrapper/config patch that explicitly reads the SRAM LEF before DEF import, then retry abstract Magic DRC.
3. If academic signoff allows waivers, submit:
   - baseline full-GDS GDS/SPICE/LVS evidence,
   - `wrapper_academic_final` LVS/route-DRC/manufacturability evidence,
   - SRAM Magic DRC evidence,
   - explicit waiver for SRAM/macro Magic DRC and remaining timing/DRV/antenna.
