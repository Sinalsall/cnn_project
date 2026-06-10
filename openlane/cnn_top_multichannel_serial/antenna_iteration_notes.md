# Antenna Iteration Notes

Target layout: `cnn_top_multichannel_serial_with_param_sram`.

## Current Best Configuration

Keep routing at `RT_MAX_LAYER: Metal4` with heuristic diode insertion enabled:

- `RUN_HEURISTIC_DIODE_INSERTION: true`
- `DIODE_ON_PORTS: in`
- `GRT_ANTENNA_ITERS: 16`
- `GRT_ANTENNA_MARGIN: 60`
- `DIODE_PADDING: 2`

## Results

| Run tag | Change | Post-route antenna | Detailed-route DRC |
| --- | --- | --- | --- |
| `wrapper_full_001` | Original full run | 45 nets / 54 pins | clean |
| `wrapper_antenna_003` | Metal4 + aggressive diode cleanup | 6 nets / 6 pins | clean |
| `wrapper_antenna_m5_001` | Same cleanup + Metal5 routing | 19 nets / 21 pins | clean |
| `wrapper_repairtiming_001` | Metal4 + post-GRT design/timing repair | 10 nets / 10 pins | clean |
| `wrapper_repairtiming_ant100_001` | Repair timing + antenna margin 100 | 14 nets / 14 pins | clean |

Conclusion: Metal5 reduced total routed wirelength but made antenna worse. The safer next baseline is `wrapper_antenna_003` style cleanup with Metal4.

The post-GRT repair iteration improved timing health but increased residual antenna:

- Hold violations: 120 -> 37
- Hold TNS: -13.812 ns -> -5.698 ns
- Max slew violations: 1620 -> 680
- Max cap violations: 71 -> 35
- Antenna: 6 nets / 6 pins -> 10 nets / 10 pins

Increasing `GRT_ANTENNA_MARGIN` to `100` is not a good baseline: OpenROAD warns that the margin must be between 0 and 100 percent, and the post-route antenna result worsened to 14 nets / 14 pins.

## Remaining Antenna Violations From Best Run

The best post-route antenna report is:

`runs/wrapper_antenna_003/06-openroad-checkantennas-1/reports/antenna_summary.rpt`

Main remaining pins include a mix of standard-cell pins, SRAM input pins, activation SRAM output nets, and one clock sink. The next cleanup should target those residual long/high-fanout nets without changing CNN functionality.

## Suggested Next Steps

1. Keep the Metal4 diode-cleanup config as the main OpenLane baseline.
2. Try a small re-synthesis/placement iteration with stricter fanout or buffering constraints only if the remaining 6 antenna violations must be reduced before signoff.
3. Once antenna is acceptable, run a full signoff pass from this improved baseline and regenerate GDS/SPICE/LVS.
