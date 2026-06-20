# CNN Test Execution Tutorial

Dokumen ini menjelaskan urutan command untuk menjalankan verifikasi project CNN
dari RTL sampai post-layout. Jalankan semua command dari root repository:

```sh
cd /foss/designs/RTL/RTL/RTL_Design
```

## 0. Setup Environment

Sebagian besar script sudah mengatur `PATH` sendiri. Untuk command manual,
pakai environment berikut:

```sh
export PATH=/foss/tools/bin:/foss/tools/iverilog/bin:/foss/tools/yosys/bin:/foss/tools/verilator/bin:/foss/tools/openroad/bin:/foss/tools/openroad-latest/bin:/foss/tools/magic/bin:/foss/tools/netgen/bin:/foss/tools/klayout:$PATH
export LD_LIBRARY_PATH=/foss/tools/iverilog/lib:${LD_LIBRARY_PATH:-}
```

Pastikan file input MNIST/weight/bias dapat dibuat:

```sh
python3 scripts/make_mnist_sample_hex_raw.py --index 0
ls generated_hex/
```

File penting yang akan dipakai:

- RTL core: `rtl_sequential/cnn_top_multichannel_serial.v`
- Layout wrapper top: `rtl_sequential/cnn_top_multichannel_serial_with_param_sram.v`
- RTL testbench: `rtl_sequential/tb_cnn_top_multichannel_serial.v`
- Post-layout gate testbench: `openlane/cnn_top_multichannel_serial/postlayout_gate_sim/tb_cnn_top_multichannel_serial_gate_sdf.v`
- OpenLane config: `openlane/cnn_top_multichannel_serial/config.yaml`

## 1. Quick Start Sequence

Urutan ringkas dari awal sampai post-layout functional compare:

```sh
# 1. Unit test SRAM aktivasi
bash rtl_sequential/run_activation_sram_bank_tb.sh

# 2. RTL single-image test + Python golden reference
bash rtl_sequential/run_mnist_image_serial.sh 0

# 3. Optional: RTL batch test untuk beberapa sample
bash rtl_sequential/run_mnist_batch_serial.sh 10

# 4. OpenLane academic final run, jika perlu regenerate layout
PATH=/foss/tools/bin:/foss/tools/openroad/bin:/foss/tools/openroad-latest/bin:/foss/tools/magic/bin:/foss/tools/netgen/bin:/foss/tools/verilator/bin:/foss/tools/yosys/bin:/foss/tools/klayout:$PATH \
openlane --condensed --manual-pdk --pdk-root /foss/pdks \
  -p gf180mcuD -s gf180mcu_fd_sc_mcu7t5v0 -j 4 \
  --run-tag wrapper_academic_final \
  openlane/cnn_top_multichannel_serial/config.yaml \
  2>&1 | tee openlane/cnn_top_multichannel_serial/runs/wrapper_academic_final.terminal.log

# 5. Cek metrics hasil OpenLane
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
  critical_disconnected_pins:.metrics.design__critical_disconnected_pin__count,
  power_grid_violations:.metrics.design__power_grid_violation__count
}' "$STATE_OUT"

# 6. Gate-level post-layout smoke test
bash openlane/cnn_top_multichannel_serial/postlayout_gate_sim/run_gate_sdf_smoke.sh

# 7. Full RTL-wrapper vs post-layout gate-level functional compare
bash openlane/cnn_top_multichannel_serial/postlayout_gate_sim/compare_rtl_vs_gate_functional.sh 0
```

Jika full compare ingin ditinggal lama:

```sh
mkdir -p openlane/cnn_top_multichannel_serial/postlayout_gate_sim/build
nohup bash openlane/cnn_top_multichannel_serial/postlayout_gate_sim/compare_rtl_vs_gate_functional.sh 0 \
  > openlane/cnn_top_multichannel_serial/postlayout_gate_sim/build/compare_nohup.log 2>&1 &
```

## 2. RTL Unit Test

### Activation SRAM Bank

Command:

```sh
bash rtl_sequential/run_activation_sram_bank_tb.sh
```

Log:

```text
rtl_sequential/run_activation_sram_bank_tb.log
```

Expected result:

```text
[PASS] activation SRAM bank test passed
```

Tujuan test:

- Membuktikan `cnn_activation_sram_bank` dapat melakukan read/write.
- Membuktikan wrapper SRAM 16-bit berjalan dalam mode `FAST_SRAM_SIM`.

## 3. RTL Functional Test Single Image

Command:

```sh
bash rtl_sequential/run_mnist_image_serial.sh 0
```

Yang dilakukan script:

1. Generate sample MNIST index `0`.
2. Run Python golden model `scripts/golden_q8_8_rescale.py`.
3. Compile RTL sequential CNN.
4. Run RTL testbench.

Log penting:

```text
rtl_sequential/golden_multichannel_serial.log
rtl_sequential/run_multichannel_serial_tb.log
```

Expected baseline untuk index `0`:

```text
true label  = 7
RTL predict = 7
predicted_class = 7
```

File RTL yang dikompilasi:

```text
rtl_sequential/sram16_1024_wrapper.v
rtl_sequential/cnn_param_sram_bank.v
rtl_sequential/cnn_activation_sram_bank.v
rtl_sequential/cnn_top_multichannel_serial.v
rtl_sequential/tb_cnn_top_multichannel_serial.v
```

Catatan: test ini memakai core-level RTL testbench dan `FAST_SRAM_SIM`. Ini baik
untuk validasi fungsional RTL, tetapi bukan pembanding paling setara untuk
post-layout gate netlist.

## 4. RTL Batch Test

Command untuk 10 sample:

```sh
bash rtl_sequential/run_mnist_batch_serial.sh 10
```

Command untuk 100 sample:

```sh
bash rtl_sequential/run_mnist_batch_serial.sh 100
```

Output:

```text
rtl_sequential/batch_results/serial_mnist_batch_results.csv
rtl_sequential/batch_results/serial_mnist_batch_summary.md
rtl_sequential/batch_results/logs/run_idx_<N>.log
```

Tujuan test:

- Mengukur akurasi RTL pada beberapa sample MNIST.
- Menghasilkan tabel `index,true_label,predicted_class,correct,best_score,cycles`.

## 5. OpenLane Full Flow

Top layout:

```text
cnn_top_multichannel_serial_with_param_sram
```

Input OpenLane:

```text
openlane/cnn_top_multichannel_serial/config.yaml
openlane/cnn_top_multichannel_serial/base.sdc
openlane/cnn_top_multichannel_serial/macro_placement.cfg
openlane/cnn_top_multichannel_serial/pdn_sram1024.tcl
openlane/cnn_top_multichannel_serial/pin_order.cfg
```

Command final academic run:

```sh
PATH=/foss/tools/bin:/foss/tools/openroad/bin:/foss/tools/openroad-latest/bin:/foss/tools/magic/bin:/foss/tools/netgen/bin:/foss/tools/verilator/bin:/foss/tools/yosys/bin:/foss/tools/klayout:$PATH \
openlane --condensed --manual-pdk --pdk-root /foss/pdks \
  -p gf180mcuD -s gf180mcu_fd_sc_mcu7t5v0 -j 4 \
  --run-tag wrapper_academic_final \
  openlane/cnn_top_multichannel_serial/config.yaml \
  2>&1 | tee openlane/cnn_top_multichannel_serial/runs/wrapper_academic_final.terminal.log
```

Jika `wrapper_academic_final` sudah ada dan ingin menjaga run lama, gunakan tag
baru:

```sh
PATH=/foss/tools/bin:/foss/tools/openroad/bin:/foss/tools/openroad-latest/bin:/foss/tools/magic/bin:/foss/tools/netgen/bin:/foss/tools/verilator/bin:/foss/tools/yosys/bin:/foss/tools/klayout:$PATH \
openlane --condensed --manual-pdk --pdk-root /foss/pdks \
  -p gf180mcuD -s gf180mcu_fd_sc_mcu7t5v0 -j 4 \
  --run-tag wrapper_academic_final_rerun1 \
  openlane/cnn_top_multichannel_serial/config.yaml \
  2>&1 | tee openlane/cnn_top_multichannel_serial/runs/wrapper_academic_final_rerun1.terminal.log
```

Catatan penting:

- File `*.terminal.log` dari `tee` adalah transcript terminal.
- `runtime.txt` hanya mencatat durasi step, bukan transcript terminal.
- Nomor step OpenLane bisa berubah. Gunakan `find`, jangan hard-code folder
  seperti `76-...` atau `77-...`.

## 6. OpenLane Metrics and Signoff Checks

Ambil `state_out.json` terakhir dari manufacturability step:

```sh
STATE_OUT="$(find openlane/cnn_top_multichannel_serial/runs/wrapper_academic_final \
  -maxdepth 2 -path '*misc-reportmanufacturability/state_out.json' | sort | tail -1)"
echo "$STATE_OUT"
```

Print metrics penting:

```sh
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

File signoff yang perlu dilihat:

```sh
less openlane/cnn_top_multichannel_serial/runs/wrapper_academic_final/flow.log
less openlane/cnn_top_multichannel_serial/runs/wrapper_academic_final/warning.log
less openlane/cnn_top_multichannel_serial/runs/wrapper_academic_final/error.log
find openlane/cnn_top_multichannel_serial/runs/wrapper_academic_final -maxdepth 2 -name 'netgen-lvs.log' -print
find openlane/cnn_top_multichannel_serial/runs/wrapper_academic_final -maxdepth 2 -name 'summary.rpt' -print
find openlane/cnn_top_multichannel_serial/runs/wrapper_academic_final -maxdepth 2 -name 'manufacturability.rpt' -print
```

Expected academic final status dari run `wrapper_academic_final`:

- LVS: `design__lvs_error__count = 0`
- OpenROAD route DRC: `route__drc_errors = 0`
- Setup timing: WNS `0`, TNS `0`
- Power-grid checker: `design__power_grid_violation__count = 0`
- Critical disconnected pins: `0`
- Remaining academic limitations: antenna, hold, max slew, max cap, and
  SRAM/Magic DRC waiver.

Dokumen signoff:

```text
openlane/cnn_top_multichannel_serial/signoff_evidence/signoff_status.md
```

## 7. Post-Layout Gate-Level Smoke Test

Command:

```sh
bash openlane/cnn_top_multichannel_serial/postlayout_gate_sim/run_gate_sdf_smoke.sh
```

Tujuan:

- Compile final gate netlist dari OpenLane.
- Compile GF180 standard-cell functional models.
- Compile SRAM behavioral model.
- Preload parameter SRAM lewat port wrapper `param_wr_*`.
- Membuktikan netlist final bisa elaborasi dan masuk post-reset state.

Output log:

```text
openlane/cnn_top_multichannel_serial/postlayout_gate_sim/build/compile_gate_sdf.log
openlane/cnn_top_multichannel_serial/postlayout_gate_sim/build/run_gate_sdf_smoke.log
openlane/cnn_top_multichannel_serial/postlayout_gate_sim/build/terminal_gate_sdf_smoke.log
```

Expected result:

```text
[PASS] Gate-level SDF smoke reached post-reset state. ready_out=1 valid_out=0 last_out=0
```

Limitasi:

```text
warning: Omitting $sdf_annotate() since specify blocks and interconnects are being omitted.
```

Icarus Verilog tidak mendukung penuh `specify`/SDF GF180. Jadi test ini adalah
gate-level functional smoke, bukan strict SDF timing simulation.

## 8. RTL Wrapper vs Post-Layout Gate Functional Compare

Ini pembanding paling setara untuk final layout netlist karena RTL baseline
memakai wrapper top dan SRAM behavioral model yang sama dengan gate-level run.

Command:

```sh
bash openlane/cnn_top_multichannel_serial/postlayout_gate_sim/compare_rtl_vs_gate_functional.sh 0
```

Yang dilakukan script:

1. Generate MNIST sample index `0`.
2. Run Python golden model.
3. Run RTL wrapper functional baseline.
4. Run post-layout gate-level functional simulation.
5. Extract result lines.
6. Compare RTL wrapper summary vs gate-level summary.

Output penting:

```text
openlane/cnn_top_multichannel_serial/postlayout_gate_sim/build/run_rtl_wrapper_functional.log
openlane/cnn_top_multichannel_serial/postlayout_gate_sim/build/rtl_wrapper_functional.summary
openlane/cnn_top_multichannel_serial/postlayout_gate_sim/build/run_gate_functional_full.log
openlane/cnn_top_multichannel_serial/postlayout_gate_sim/build/gate_functional_full.summary
openlane/cnn_top_multichannel_serial/postlayout_gate_sim/build/rtl_vs_gate_functional.diff
openlane/cnn_top_multichannel_serial/postlayout_gate_sim/build/terminal_rtl_vs_gate_functional.log
```

Interpretasi hasil:

- `PASS Bit-exact`: semua 10 `class_scores`, cycle count, dan predicted class
  sama persis.
- `WARN` lalu `PASS Application-level`: score vector berbeda, tetapi
  `predicted_class` dan cycle count sama.
- `FAIL`: predicted class atau cycle count berbeda.

Untuk memaksa score harus bit-exact:

```sh
STRICT_COMPARE=1 bash openlane/cnn_top_multichannel_serial/postlayout_gate_sim/compare_rtl_vs_gate_functional.sh 0
```

## 9. Post-Layout SPICE Smoke Test

SPICE full-chip dengan 48 SRAM macro sangat berat, jadi flow ini hanya smoke
test untuk membuktikan deck/model/subckt dapat ditemukan.

Generate deck:

```sh
bash openlane/cnn_top_multichannel_serial/postlayout_spice/prepare_postlayout_spice.sh wrapper_academic_final
```

Run ngspice smoke:

```sh
ngspice -b \
  -o openlane/cnn_top_multichannel_serial/postlayout_spice/build/wrapper_academic_final/tb_smoke.log \
  openlane/cnn_top_multichannel_serial/postlayout_spice/build/wrapper_academic_final/tb_smoke.spice
```

Jika ingin diberi batas waktu:

```sh
timeout 30s ngspice -b \
  -o openlane/cnn_top_multichannel_serial/postlayout_spice/build/wrapper_academic_final/tb_smoke.log \
  openlane/cnn_top_multichannel_serial/postlayout_spice/build/wrapper_academic_final/tb_smoke.spice
echo "ngspice_status=$?"
```

Expected untuk project ini:

- GF180 transistor models ditemukan.
- Standard-cell subcircuits ditemukan.
- SRAM subcircuits ditemukan melalui wrapper pin-order.
- Top-level extracted SPICE mulai elaborasi.
- Full transient bisa sangat lama atau timeout; ini normal untuk full-chip
  real-SRAM SPICE.

## 10. File Final Untuk Laporan

### RTL

```text
rtl_sequential/cnn_top_multichannel_serial.v
rtl_sequential/cnn_top_multichannel_serial_with_param_sram.v
rtl_sequential/cnn_param_sram_bank.v
rtl_sequential/cnn_activation_sram_bank.v
rtl_sequential/sram16_1024_wrapper.v
rtl_sequential/tb_cnn_top_multichannel_serial.v
```

### Layout/OpenLane

```text
openlane/cnn_top_multichannel_serial/config.yaml
openlane/cnn_top_multichannel_serial/base.sdc
openlane/cnn_top_multichannel_serial/macro_placement.cfg
openlane/cnn_top_multichannel_serial/pdn_sram1024.tcl
openlane/cnn_top_multichannel_serial/pin_order.cfg
openlane/cnn_top_multichannel_serial/signoff_evidence/signoff_status.md
```

### Post-Layout Simulation

```text
openlane/cnn_top_multichannel_serial/postlayout_gate_sim/tb_cnn_top_multichannel_serial_gate_sdf.v
openlane/cnn_top_multichannel_serial/postlayout_gate_sim/run_gate_sdf_smoke.sh
openlane/cnn_top_multichannel_serial/postlayout_gate_sim/run_rtl_wrapper_functional.sh
openlane/cnn_top_multichannel_serial/postlayout_gate_sim/run_gate_functional_full.sh
openlane/cnn_top_multichannel_serial/postlayout_gate_sim/compare_rtl_vs_gate_functional.sh
openlane/cnn_top_multichannel_serial/postlayout_spice/prepare_postlayout_spice.sh
```

### Generated Final Artifacts

Generated artifacts ada di run OpenLane dan biasanya tidak di-commit:

```text
openlane/cnn_top_multichannel_serial/runs/wrapper_academic_final/final/nl/
openlane/cnn_top_multichannel_serial/runs/wrapper_academic_final/final/gds/
openlane/cnn_top_multichannel_serial/runs/wrapper_academic_final/final/spice/
openlane/cnn_top_multichannel_serial/runs/wrapper_academic_final/final/sdf/
openlane/cnn_top_multichannel_serial/runs/wrapper_academic_final/final/spef/
```

## 11. Suggested Report Wording

Contoh kalimat untuk laporan:

> RTL functional verification was performed using a Q8.8 Python golden model
> and an Icarus Verilog testbench. The final OpenLane layout top was
> `cnn_top_multichannel_serial_with_param_sram`, integrating the sequential CNN
> core with activation and parameter SRAM banks. The academic final OpenLane run
> generated GDS and extracted SPICE, passed Netgen LVS, passed OpenROAD
> detailed-route DRC, passed setup timing, and had zero critical disconnected
> pins. Post-layout functional verification was performed by simulating the
> final gate-level netlist against an RTL-wrapper baseline using the same MNIST
> stimulus and SRAM behavioral model. Strict SDF timing simulation was not used
> because Icarus Verilog does not fully support the GF180 specify/SDF constructs;
> timing evidence is therefore taken from OpenROAD STA reports.

## 12. Cleanup Notes

Generated logs/build files are ignored by Git:

```text
rtl_sequential/batch_results/
openlane/**/runs/
openlane/**/postlayout_gate_sim/build/
openlane/**/postlayout_spice/build/
*.vcd
*.vvp
*.log
```

Commit source, config, scripts, and documentation. Do not commit large run
artifacts unless the supervisor explicitly asks for archived evidence.
