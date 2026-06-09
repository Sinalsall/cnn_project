# OpenLane Bring-Up Plan

OpenLane is not fully configured yet. The sequential CNN RTL is ready for bring-up, but SRAM macro files and macro placement need to be integrated.

## Target Top

Current RTL top:

```text
rtl_sequential/cnn_top_multichannel_serial.v
```

## Required RTL Files

Minimum design files for the sequential SRAM-backed top:

```text
gf180mcu_ocd_ip_sram__sram1024x8m8wm1.v
rtl_sequential/sram16_1024_wrapper.v
rtl_sequential/cnn_param_sram_bank.v
rtl_sequential/cnn_activation_sram_bank.v
rtl_sequential/cnn_top_multichannel_serial.v
```

## Macro Requirement

The RTL wrapper instantiates:

```text
gf180mcu_ocd_ip_sram__sram1024x8m8wm1
```

For physical layout, OpenLane needs at least:

- Verilog blackbox/model
- Liberty `.lib`
- LEF `.lef`
- GDS `.gds`

These should come from:

```text
https://github.com/RTimothyEdwards/gf180mcu_ocd_ip_sram/tree/main/cells/gf180mcu_ocd_ip_sram__sram1024x8m8wm1
```

## SRAM Count

Current architecture uses:

- Parameter SRAM: 8 banks x 1024x16 = 16 macros of 1024x8.
- Activation SRAM: 16 banks x 1024x16 = 32 macros of 1024x8.

Total current macro estimate:

```text
48 macros of gf180mcu_ocd_ip_sram__sram1024x8m8wm1
```

## Next Tasks

1. Add an OpenLane config directory for the top.
2. Add macro LEF/GDS/LIB paths.
3. Create macro placement constraints.
4. Run `openlane` synthesis/floorplan.
5. Iterate on floorplan area and macro placement.
