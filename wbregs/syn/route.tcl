################################################################################
# File   : route.tcl
# Author : David Gussler
# Date   : 08-06-2022
# Description
#    Routes the placed design, saves a design checkpoint, generates a netlist / 
#    master constraints file, and generates reports
#    This script is part of the Vivado Makefile toolflow project
#    This script is intended for use with Vivado version 2022.1
################################################################################

set reports_dir ./reports
file mkdir $reports_dir
set build_dir ./build
file mkdir $build_dir

set top_module     $::env(TOP_MODULE)

open_checkpoint post_place.dcp

route_design

write_checkpoint -force post_route
report_timing_summary -file $reports_dir/post_route_timing_summary.rpt
report_timing -sort_by group -max_paths 100 -path_type summary -file $reports_dir/post_route_timing.rpt
report_clock_utilization -file $reports_dir/post_route_clock_util.rpt
report_utilization -file $reports_dir/post_route_util.rpt
report_power -file $reports_dir/post_route_power.rpt
report_drc -file $reports_dir/post_route_drc.rpt

write_edif -force $build_dir/${top_module}_netlist.edn
write_xdc -no_fixed_only -force $build_dir/${top_module}_cnstrs.xdc
