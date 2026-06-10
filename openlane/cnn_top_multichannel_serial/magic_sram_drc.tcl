if {![info exists ::env(SRAM_GDS)]} {
    puts stderr "SRAM_GDS is required"
    exit 1
}

if {![info exists ::env(SRAM_DRC_RPT)]} {
    puts stderr "SRAM_DRC_RPT is required"
    exit 1
}

gds read $::env(SRAM_GDS)
load gf180mcu_ocd_ip_sram__sram1024x8m8wm1
select top cell
drc euclidean on
drc style drc(full)
drc check

set oscale [cif scale out]
set drcresult [drc listall why]
set fout [open $::env(SRAM_DRC_RPT) w]
set count 0

puts $fout "gf180mcu_ocd_ip_sram__sram1024x8m8wm1"
puts $fout "----------------------------------------"
foreach {errtype coordlist} $drcresult {
    puts $fout $errtype
    puts $fout "----------------------------------------"
    foreach coord $coordlist {
        set bllx [expr {$oscale * [lindex $coord 0]}]
        set blly [expr {$oscale * [lindex $coord 1]}]
        set burx [expr {$oscale * [lindex $coord 2]}]
        set bury [expr {$oscale * [lindex $coord 3]}]
        puts $fout [format " %.3fum %.3fum %.3fum %.3fum" $bllx $blly $burx $bury]
        set count [expr {$count + 1}]
    }
    puts $fout "----------------------------------------"
}
puts $fout "\[INFO\] COUNT: $count"
close $fout

puts stdout "\[INFO\] SRAM Magic DRC count: $count"
exit 0
