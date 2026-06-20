# GitHub Upload Manifest

Dokumen ini menjelaskan file yang perlu diupload ke GitHub dan file yang harus
tetap lokal/generated.

## Commit These Files

Core documentation:

```text
README.md
.gitignore
docs/
openlane/README.md
openlane/cnn_top_multichannel_serial/README.md
openlane/cnn_top_multichannel_serial/signoff_evidence/signoff_status.md
```

RTL source and RTL runners:

```text
rtl_sequential/*.v
rtl_sequential/*.sh
rtl_sequential/*.md
rtl_sequential/golden_functional/*.v
rtl_sequential/golden_functional/*.sh
```

Python/golden/sample scripts:

```text
scripts/*.py
scripts/*.sh
```

Fixed CNN weights and biases:

```text
generated_hex/conv*_weights_hex.txt
generated_hex/conv*_bias_hex.txt
generated_hex/fc_weights_hex.txt
generated_hex/fc_bias_hex.txt
```

OpenLane design inputs:

```text
openlane/cnn_top_multichannel_serial/config.yaml
openlane/cnn_top_multichannel_serial/base.sdc
openlane/cnn_top_multichannel_serial/macro_placement.cfg
openlane/cnn_top_multichannel_serial/pdn_sram1024.tcl
openlane/cnn_top_multichannel_serial/pin_order.cfg
openlane/cnn_top_multichannel_serial/magic_sram_drc.tcl
openlane/cnn_top_multichannel_serial/antenna_iteration_notes.md
```

Post-layout simulation scripts and testbench:

```text
openlane/cnn_top_multichannel_serial/postlayout_gate_sim/README.md
openlane/cnn_top_multichannel_serial/postlayout_gate_sim/*.sh
openlane/cnn_top_multichannel_serial/postlayout_gate_sim/*.v
openlane/cnn_top_multichannel_serial/postlayout_spice/README.md
openlane/cnn_top_multichannel_serial/postlayout_spice/*.sh
```

SRAM macro collateral required for OpenLane:

```text
third_party/gf180mcu_ocd_ip_sram/sram1024x8m8wm1/README.md
third_party/gf180mcu_ocd_ip_sram/sram1024x8m8wm1/*.v
third_party/gf180mcu_ocd_ip_sram/sram1024x8m8wm1/*.lef
third_party/gf180mcu_ocd_ip_sram/sram1024x8m8wm1/*.gds
third_party/gf180mcu_ocd_ip_sram/sram1024x8m8wm1/*.spice
third_party/gf180mcu_ocd_ip_sram/sram1024x8m8wm1/*.lib
```

The SRAM GDS is about 2.8 MB and is intentionally kept in Git because OpenLane
needs it to regenerate the layout.

## Do Not Commit These Files

Generated OpenLane runs:

```text
openlane/**/runs/
openlane/**/*.odb
openlane/**/*.def
openlane/**/*.spef
openlane/**/*.sdf
openlane/**/*.rpt
openlane/**/*.xml
openlane/**/final/
```

Simulation/build outputs:

```text
*.log
*.vcd
*.vvp
*.out
batch_results/
rtl_sequential/batch_results/
openlane/**/postlayout_gate_sim/build/
openlane/**/postlayout_spice/build/
```

Generated MNIST sample files:

```text
generated_hex/mnist_sample_hex.txt
generated_hex/mnist_sample_label.txt
generated_hex/mnist_sample_preview.pgm
generated_hex/mnist_sample_preview.txt
mnist_raw/
```

Local backup/archive files:

```text
backup/
*.zip
*.tar
*.tar.gz
*.bak
```

## Safe Git Add Command

Use this from the repository root:

```sh
git add README.md .gitignore docs
git add scripts/*.py scripts/*.sh
git add rtl_sequential/*.v rtl_sequential/*.sh rtl_sequential/*.md
git add rtl_sequential/golden_functional/*.v rtl_sequential/golden_functional/*.sh
git add generated_hex/conv*_weights_hex.txt generated_hex/conv*_bias_hex.txt
git add generated_hex/fc_weights_hex.txt generated_hex/fc_bias_hex.txt
git add openlane/README.md
git add openlane/cnn_top_multichannel_serial/*.yaml
git add openlane/cnn_top_multichannel_serial/*.sdc
git add openlane/cnn_top_multichannel_serial/*.cfg
git add openlane/cnn_top_multichannel_serial/*.tcl
git add openlane/cnn_top_multichannel_serial/*.md
git add openlane/cnn_top_multichannel_serial/signoff_evidence/signoff_status.md
git add openlane/cnn_top_multichannel_serial/postlayout_gate_sim/*.md
git add openlane/cnn_top_multichannel_serial/postlayout_gate_sim/*.sh
git add openlane/cnn_top_multichannel_serial/postlayout_gate_sim/*.v
git add openlane/cnn_top_multichannel_serial/postlayout_spice/*.md
git add openlane/cnn_top_multichannel_serial/postlayout_spice/*.sh
git add third_party/gf180mcu_ocd_ip_sram/sram1024x8m8wm1
```

Then inspect before commit:

```sh
git status --short
git diff --cached --stat
```

Commit and push:

```sh
git commit -m "Document CNN RTL and OpenLane verification flow"
git push origin main
```

If the branch is not `main`, check it with:

```sh
git branch --show-current
```

and push to that branch instead.
