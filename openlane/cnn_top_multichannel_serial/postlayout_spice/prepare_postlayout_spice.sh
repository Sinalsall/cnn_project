#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
DESIGN_DIR="${ROOT_DIR}/openlane/cnn_top_multichannel_serial"
RUN_TAG="${1:-wrapper_academic_final}"
RUN_DIR="${DESIGN_DIR}/runs/${RUN_TAG}"
DESIGN="cnn_top_multichannel_serial_with_param_sram"
BUILD_DIR="${DESIGN_DIR}/postlayout_spice/build/${RUN_TAG}"

FINAL_SPICE="${RUN_DIR}/final/spice/${DESIGN}.spice"
PDK_NGSPICE="/foss/pdks/gf180mcuD/libs.tech/ngspice"
GF180_MODELS="${PDK_NGSPICE}/sm141064.ngspice"
GF180_GLOBALS="${PDK_NGSPICE}/design.ngspice"
STD_CELL_SPICE="/foss/pdks/gf180mcuD/libs.ref/gf180mcu_fd_sc_mcu7t5v0/spice/gf180mcu_fd_sc_mcu7t5v0.spice"
SRAM_SPICE="${ROOT_DIR}/third_party/gf180mcu_ocd_ip_sram/sram1024x8m8wm1/gf180mcu_ocd_ip_sram__sram1024x8m8wm1.spice"

TOP_ONLY="${BUILD_DIR}/${DESIGN}.top_only.spice"
SRAM_CORE="${BUILD_DIR}/sram1024_core_renamed.spice"
SRAM_WRAPPER="${BUILD_DIR}/sram1024_openlane_pin_wrapper.spice"
STIMULUS="${BUILD_DIR}/tb_smoke_stimulus.spice"
TOP_INSTANCE="${BUILD_DIR}/top_instance.spice"
TOP_PINS="${BUILD_DIR}/top_pins.txt"
TB_DECK="${BUILD_DIR}/tb_smoke.spice"

require_file() {
    local path="$1"
    if [ ! -f "$path" ]; then
        echo "Missing required file: $path" >&2
        exit 1
    fi
}

require_file "$FINAL_SPICE"
require_file "$GF180_GLOBALS"
require_file "$GF180_MODELS"
require_file "$STD_CELL_SPICE"
require_file "$SRAM_SPICE"

if ! grep -q '^[[:space:]]*\.subckt[[:space:]]\+nfet_06v0[[:space:]]' "$GF180_MODELS"; then
    echo "GF180 ngspice model file does not define nfet_06v0: $GF180_MODELS" >&2
    exit 1
fi

if ! grep -q '^[[:space:]]*\.subckt[[:space:]]\+pfet_06v0[[:space:]]' "$GF180_MODELS"; then
    echo "GF180 ngspice model file does not define pfet_06v0: $GF180_MODELS" >&2
    exit 1
fi

mkdir -p "$BUILD_DIR"

awk -v top="$DESIGN" '
    BEGIN { emit = 0 }
    $0 ~ "^\\.subckt[[:space:]]+" top "([[:space:]]|$)" { emit = 1 }
    emit { print }
' "$FINAL_SPICE" > "$TOP_ONLY"

awk '
    BEGIN { renamed = 0 }
    !renamed && /^\.subckt gf180mcu_ocd_ip_sram__sram1024x8m8wm1[[:space:]]/ {
        sub("gf180mcu_ocd_ip_sram__sram1024x8m8wm1", "gf180mcu_ocd_ip_sram__sram1024x8m8wm1_core")
        renamed = 1
    }
    { print }
' "$SRAM_SPICE" > "$SRAM_CORE"

cat > "$SRAM_WRAPPER" <<'SPICE'
* Pin-order adapter from OpenLane/Magic extracted SRAM order to the
* third_party SRAM SPICE order.

.subckt gf180mcu_ocd_ip_sram__sram1024x8m8wm1 A[8] A[7] A[6] A[5] A[4] A[3] A[2] A[1]
+ A[0] CEN CLK D[7] D[6] D[5] D[4] D[3] D[2] D[1] D[0] GWEN Q[7] Q[6] Q[5] Q[4] Q[3]
+ Q[2] Q[1] Q[0] VDD VSS WEN[7] WEN[6] WEN[5] WEN[4] WEN[3] WEN[2] WEN[1] WEN[0] A[9]

Xsram_core VSS VDD A[9] A[8] A[7] A[6] A[5] A[4] A[3] A[2] A[1] A[0] CLK GWEN
+ Q[7] Q[6] Q[5] Q[4] Q[3] Q[2] Q[1] Q[0]
+ WEN[7] WEN[6] WEN[5] WEN[4] WEN[3] WEN[2] WEN[1] WEN[0]
+ D[7] D[6] D[5] D[4] D[3] D[2] D[1] D[0] CEN
+ gf180mcu_ocd_ip_sram__sram1024x8m8wm1_core

.ends gf180mcu_ocd_ip_sram__sram1024x8m8wm1
SPICE

awk -v top="$DESIGN" '
    BEGIN { collect = 0; line = "" }
    $0 ~ "^\\.subckt[[:space:]]+" top "([[:space:]]|$)" {
        collect = 1
        line = $0
        next
    }
    collect && /^\+/ {
        line = line " " substr($0, 2)
        next
    }
    collect {
        collect = 0
    }
    END {
        gsub(/[[:space:]]+/, " ", line)
        sub("^\\.subckt " top " ", "", line)
        n = split(line, pins, " ")
        for (i = 1; i <= n; i++) {
            if (pins[i] != "") print pins[i]
        }
    }
' "$TOP_ONLY" > "$TOP_PINS"

{
    echo "* Generated top-level instance using the extracted SPICE pin order."
    printf "Xdut"
    awk '{ printf " %s", $0 }' "$TOP_PINS"
    printf " %s\n" "$DESIGN"
} > "$TOP_INSTANCE"

{
    echo "* Minimal post-layout SPICE smoke stimulus."
    echo "Vvdd VDD 0 5.0"
    echo "Vvss VSS 0 0"
    echo "Vclk clk 0 PULSE(0 5.0 20n 100p 100p 50n 100n)"
    echo "Vrst rst_n 0 PULSE(0 5.0 250n 100p 100p 1u 2u)"
    echo "Vvalid valid_in 0 0"
    echo "Vlast last_in 0 0"
    echo "Vparam_we param_wr_en 0 0"
    for i in $(seq 0 15); do
        echo "Vparam_addr_${i} param_wr_addr[${i}] 0 0"
    done
    for i in $(seq 0 15); do
        echo "Vparam_data_${i} param_wr_data[${i}] 0 0"
    done
    for i in $(seq 0 15); do
        echo "Vpixel_${i} pixel_in[${i}] 0 0"
    done
} > "$STIMULUS"

cat > "$TB_DECK" <<SPICE
* Smoke-test deck for ${DESIGN}, generated from ${RUN_TAG}.
* This is intended to prove model/subckt completeness and basic transient
* startup, not to run the full CNN workload.

.option ngbehavior=ps
.option method=gear
.temp 25

.include "${GF180_GLOBALS}"
.lib "${GF180_MODELS}" nfet_03v3_t
.lib "${GF180_MODELS}" pfet_03v3_t
.lib "${GF180_MODELS}" nfet_06v0_t
.lib "${GF180_MODELS}" pfet_06v0_t
.lib "${GF180_MODELS}" nfet_06v0_nvt_t
.lib "${GF180_MODELS}" fets_mm
.lib "${GF180_MODELS}" dio

.include "${STD_CELL_SPICE}"
.include "${SRAM_CORE}"
.include "${SRAM_WRAPPER}"
.include "${TOP_ONLY}"
.include "${STIMULUS}"
.include "${TOP_INSTANCE}"

.control
set filetype=ascii
tran 1n 400n
write "${BUILD_DIR}/tb_smoke.raw" v(clk) v(rst_n) v(ready_out) v(valid_out)
quit
.endc

.end
SPICE

cat <<EOF
Prepared post-layout SPICE files in:
  ${BUILD_DIR}

Main deck:
  ${TB_DECK}

Run a short smoke simulation with:
  ngspice -b -o "${BUILD_DIR}/tb_smoke.log" "${TB_DECK}"

Note: this uses real GF180 ngspice model sections and the real SRAM SPICE
wrapper. It is a smoke test, not the full CNN functional workload.
EOF
