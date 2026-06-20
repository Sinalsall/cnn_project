# GitHub Quickstart

Panduan ini ditujukan untuk anggota tim yang baru clone repository dan ingin
menjalankan test project dari awal.

## 1. Clone Repository

```sh
git clone https://github.com/Sinalsall/cnn_project.git
cd cnn_project
```

Di container Chipathon/foss, lokasi kerja project sebelumnya adalah:

```sh
cd /foss/designs/RTL/RTL/RTL_Design
```

## 2. Tool Requirement

Minimal untuk RTL simulation:

- `python3`
- `iverilog`
- `vvp`

Untuk OpenLane/layout:

- `openlane`
- GF180 PDK di `/foss/pdks`
- tools di `/foss/tools`

Setup PATH manual jika diperlukan:

```sh
export PATH=/foss/tools/bin:/foss/tools/iverilog/bin:/foss/tools/yosys/bin:/foss/tools/verilator/bin:/foss/tools/openroad/bin:/foss/tools/openroad-latest/bin:/foss/tools/magic/bin:/foss/tools/netgen/bin:/foss/tools/klayout:$PATH
export LD_LIBRARY_PATH=/foss/tools/iverilog/lib:${LD_LIBRARY_PATH:-}
```

## 3. First Command After Clone

Run smoke sequence:

```sh
bash scripts/run_github_smoke.sh
```

Script ini akan:

1. Cek tool basic.
2. Generate MNIST sample index `0`.
3. Run activation SRAM unit test.
4. Run RTL single-image functional test.
5. Run post-layout gate smoke jika final OpenLane netlist sudah tersedia.

Expected RTL result untuk sample index `0`:

```text
predicted_class = 7
```

Jika post-layout netlist belum ada, script akan menampilkan `SKIP` untuk
post-layout gate smoke. Itu normal pada clone baru karena folder
`openlane/**/runs/` tidak disimpan di Git.

## 4. Full Test Sequence

Tutorial lengkap command dari RTL sampai post-layout ada di:

```text
docs/test_execution_tutorial.md
```

Ringkasan command utama:

```sh
bash rtl_sequential/run_activation_sram_bank_tb.sh
bash rtl_sequential/run_mnist_image_serial.sh 0
bash rtl_sequential/run_mnist_batch_serial.sh 10
```

Untuk menjalankan OpenLane academic final:

```sh
PATH=/foss/tools/bin:/foss/tools/openroad/bin:/foss/tools/openroad-latest/bin:/foss/tools/magic/bin:/foss/tools/netgen/bin:/foss/tools/verilator/bin:/foss/tools/yosys/bin:/foss/tools/klayout:$PATH \
openlane --condensed --manual-pdk --pdk-root /foss/pdks \
  -p gf180mcuD -s gf180mcu_fd_sc_mcu7t5v0 -j 4 \
  --run-tag wrapper_academic_final \
  openlane/cnn_top_multichannel_serial/config.yaml \
  2>&1 | tee openlane/cnn_top_multichannel_serial/runs/wrapper_academic_final.terminal.log
```

Setelah OpenLane selesai, jalankan post-layout comparison:

```sh
bash openlane/cnn_top_multichannel_serial/postlayout_gate_sim/compare_rtl_vs_gate_functional.sh 0
```

## 5. Important Project Files

RTL final:

```text
rtl_sequential/cnn_top_multichannel_serial.v
rtl_sequential/cnn_top_multichannel_serial_with_param_sram.v
rtl_sequential/cnn_param_sram_bank.v
rtl_sequential/cnn_activation_sram_bank.v
rtl_sequential/sram16_1024_wrapper.v
```

OpenLane/layout input:

```text
openlane/cnn_top_multichannel_serial/config.yaml
openlane/cnn_top_multichannel_serial/base.sdc
openlane/cnn_top_multichannel_serial/macro_placement.cfg
openlane/cnn_top_multichannel_serial/pdn_sram1024.tcl
openlane/cnn_top_multichannel_serial/pin_order.cfg
```

Post-layout simulation:

```text
openlane/cnn_top_multichannel_serial/postlayout_gate_sim/tb_cnn_top_multichannel_serial_gate_sdf.v
openlane/cnn_top_multichannel_serial/postlayout_gate_sim/run_gate_sdf_smoke.sh
openlane/cnn_top_multichannel_serial/postlayout_gate_sim/run_rtl_wrapper_functional.sh
openlane/cnn_top_multichannel_serial/postlayout_gate_sim/run_gate_functional_full.sh
openlane/cnn_top_multichannel_serial/postlayout_gate_sim/compare_rtl_vs_gate_functional.sh
```

SRAM macro collateral required by OpenLane:

```text
third_party/gf180mcu_ocd_ip_sram/sram1024x8m8wm1/
```

## 6. What Is Not In Git

The following are generated locally and intentionally ignored:

```text
openlane/**/runs/
openlane/**/postlayout_gate_sim/build/
openlane/**/postlayout_spice/build/
rtl_sequential/batch_results/
batch_results/
*.log
*.vcd
*.vvp
generated_hex/mnist_sample_*
mnist_raw/
```

So on a fresh clone, the final GDS/SPICE/SDF/netlist will not exist until
OpenLane is run again.
