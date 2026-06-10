# OpenLane Bring-Up Plan

OpenLane2 bring-up files are now available for the sequential CNN top.

## Target Top

Current RTL top:

```text
rtl_sequential/cnn_top_multichannel_serial.v
```

## Config

Use:

```text
openlane/cnn_top_multichannel_serial/config.yaml
```

First synthesis smoke test:

```sh
openlane --manual-pdk --pdk-root /foss/pdks -p gf180mcuD -s gf180mcu_fd_sc_mcu7t5v0 -j 4 --run-tag synth_smoke --to Yosys.Synthesis openlane/cnn_top_multichannel_serial/config.yaml
```

Floorplan smoke test:

```sh
openlane --manual-pdk --pdk-root /foss/pdks -p gf180mcuD -s gf180mcu_fd_sc_mcu7t5v0 -j 4 --run-tag floorplan_smoke --to OpenROAD.Floorplan openlane/cnn_top_multichannel_serial/config.yaml
```

PDN smoke test:

```sh
openlane --manual-pdk --pdk-root /foss/pdks -p gf180mcuD -s gf180mcu_fd_sc_mcu7t5v0 -j 4 --run-tag pdn_smoke_sram_ladder --to OpenROAD.GeneratePDN openlane/cnn_top_multichannel_serial/config.yaml
```

Global placement smoke test:

```sh
openlane --manual-pdk --pdk-root /foss/pdks -p gf180mcuD -s gf180mcu_fd_sc_mcu7t5v0 -j 4 --run-tag gpl_smoke --to OpenROAD.GlobalPlacement openlane/cnn_top_multichannel_serial/config.yaml
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

The layout target `cnn_top_multichannel_serial` instantiates the activation SRAM bank internally:

- Activation SRAM: 16 banks x 1024x16 = 32 macros of 1024x8.

The parameter SRAM bank is still external to this top through the `mem_req_*` / `mem_resp_data` interface and is used by the simulation testbench. A future SRAM-system wrapper should instantiate `cnn_param_sram_bank` if the final chip top must include parameter storage on-die, which would add 16 more SRAM macros.

## Next Tasks

## Current Smoke Status

Last checked locally:

- Sequential MNIST batch smoke: passed 2/2 samples.
- Yosys/OpenLane synthesis: passed, with 32 SRAM macro instances and no inferred memories.
- Floorplan/manual macro placement: passed, 32 SRAM instances placed.
- PDN generation: passed connectivity with `design__power_grid_violation__count = 0`.
- Global placement: passed. Final placement overflow reported around `0.0996`.

Known non-fatal warnings remain:

- Verilator width warnings in the sequential top.
- `MACRO_PLACEMENT_CFG` deprecation warning; OpenLane recommends migrating to `MACROS`.
- `PDN-0110` warnings for some via sites inside tiny SRAM power-pin shapes, while VDD/VSS connectivity still passes.

## Next Tasks

1. Clean width warnings in RTL without changing fixed-point behavior.
2. Migrate macro placement from `MACRO_PLACEMENT_CFG` to OpenLane2 `MACROS`.
3. Run global route smoke and inspect congestion/overflow.
4. Decide whether to create an SRAM-system wrapper with parameter SRAM included before full PnR/signoff.
