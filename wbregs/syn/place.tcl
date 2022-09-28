################################################################################
# File   : place.tcl
# Author : David Gussler
# Date   : 08-06-2022
# Description
#    Places the synthesized design, saves a design checkpoint, and generates
#    reports
#    This script is part of the Vivado Makefile toolflow project
#    This script is intended for use with Vivado version 2022.1
################################################################################

set reports_dir ./reports
file mkdir $reports_dir

set sources_xdc_impl    $::env(SOURCES_XDC_IMPL)

open_checkpoint post_synth.dcp

if {$sources_xdc_impl != ""} {
    read_xdc ${sources_xdc_impl}
}

opt_design
place_design
phys_opt_design
write_checkpoint -force post_place.dcp
report_timing_summary -file $reports_dir/post_place_timing_summary.rpt
