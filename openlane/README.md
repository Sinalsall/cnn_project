# OpenLane Bring-Up Plan

OpenLane2 bring-up files are now available for the sequential CNN top.

## Target Top

Current OpenLane layout top:

```text
rtl_sequential/cnn_top_multichannel_serial_with_param_sram.v
```

The wrapper instantiates:

- `cnn_top_multichannel_serial` as the compute core.
- `cnn_param_sram_bank` for on-chip weights and biases.
- `cnn_activation_sram_bank` inside the compute core for on-chip activations.

Weights and biases can be loaded before inference through the wrapper ports
`param_wr_en`, `param_wr_addr`, and `param_wr_data`.

## Config

Use:

```text
openlane/cnn_top_multichannel_serial/config.yaml
```

First synthesis smoke test:

```sh
openlane --manual-pdk --pdk-root /foss/pdks -p gf180mcuD -s gf180mcu_fd_sc_mcu7t5v0 -j 4 --run-tag wrapper_synth_smoke --to Yosys.Synthesis openlane/cnn_top_multichannel_serial/config.yaml
```

Manual macro placement smoke test:

```sh
openlane --manual-pdk --pdk-root /foss/pdks -p gf180mcuD -s gf180mcu_fd_sc_mcu7t5v0 -j 4 --run-tag wrapper_macro_place_smoke --to Odb.ManualMacroPlacement openlane/cnn_top_multichannel_serial/config.yaml
```

PDN smoke test:

```sh
openlane --manual-pdk --pdk-root /foss/pdks -p gf180mcuD -s gf180mcu_fd_sc_mcu7t5v0 -j 4 --run-tag wrapper_pdn_smoke --to OpenROAD.GeneratePDN openlane/cnn_top_multichannel_serial/config.yaml
```

Global placement smoke test:

```sh
openlane --manual-pdk --pdk-root /foss/pdks -p gf180mcuD -s gf180mcu_fd_sc_mcu7t5v0 -j 4 --run-tag wrapper_gpl_smoke --to OpenROAD.GlobalPlacement openlane/cnn_top_multichannel_serial/config.yaml
```

## SRAM Macro

The 1024x8 SRAM macro views are vendored under:

```text
third_party/gf180mcu_ocd_ip_sram/sram1024x8m8wm1/
```

Required views are present:

```text
gf180mcu_ocd_ip_sram__sram1024x8m8wm1.blackbox.v
gf180mcu_ocd_ip_sram__sram1024x8m8wm1.lef
gf180mcu_ocd_ip_sram__sram1024x8m8wm1.gds
gf180mcu_ocd_ip_sram__sram1024x8m8wm1.spice
gf180mcu_ocd_ip_sram__sram1024x8m8wm1__*.lib
```

The OpenLane config uses `pdn_sram1024.tcl` because this SRAM exposes power pins
on Metal1/Metal2/Metal3, while the top-level GF180 PDN grid is on Metal4/Metal5.
The custom PDN file adds the macro via ladder needed to connect SRAM VDD/VSS.

## SRAM Count

Important current-state note:

The layout target `cnn_top_multichannel_serial_with_param_sram` instantiates both activation and parameter SRAM:

- Activation SRAM: 16 banks x 1024x16 = 32 macros of 1024x8.
- Parameter SRAM: 8 banks x 1024x16 = 16 macros of 1024x8.

Total: 48 macros of 1024x8.

## Current Smoke Status

Last checked locally:

- Sequential MNIST batch smoke: passed 2/2 samples.
- Yosys/OpenLane synthesis: passed, with 48 SRAM macro instances and no inferred memories.
- Floorplan/manual macro placement: passed, 48 SRAM instances placed.
- PDN generation: passed connectivity with `design__power_grid_violation__count = 0`.
- Global placement has not yet been rerun after adding parameter SRAM; this is the next physical-design smoke step.

Known non-fatal warnings remain:

- Verilator width warnings in the sequential top.
- `MACRO_PLACEMENT_CFG` deprecation warning; OpenLane recommends migrating to `MACROS`.
- `PDN-0110` warnings for some via sites inside tiny SRAM power-pin shapes, while VDD/VSS connectivity still passes.

## Next Tasks

1. Clean width warnings in RTL without changing fixed-point behavior.
2. Migrate macro placement from `MACRO_PLACEMENT_CFG` to OpenLane2 `MACROS`.
3. Run global route smoke and inspect congestion/overflow.
4. Run PDN/global-placement again after each macro placement or die-size iteration.
