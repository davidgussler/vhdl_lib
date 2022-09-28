################################################################################
# File   : synth.tcl
# Author : David Gussler
# Date   : 08-06-2022
# Description
#    Reads in design sources and synthesizes a netlist using the Xilinx Vivado
#    synthesis engine. Also produces output reports and a design checkpoint file
#    for use in implementation. 
#    This script is part of the Vivado Makefile toolflow project
#    This script is intended for use with Vivado version 2022.1
################################################################################

# Create a directory to store reports
set reports_dir ./reports
file mkdir $reports_dir

# Read env variables that were set in the makefile
set top_module     $::env(TOP_MODULE)
set target_device  $::env(TARGET_DEVICE)
set target_lang    $::env(TARGET_LANG)
set sources_vhdl   $::env(SOURCES_VHDL)
set sources_sv     $::env(SOURCES_SV)
set sources_ip     $::env(SOURCES_IP)
set sources_bd     $::env(SOURCES_BD)
set sources_xdc_synth $::env(SOURCES_XDC_SYNTH)
set generics       $::env(GENERICS)
set synth_args     $::env(SYNTH_ARGS)

# Create an in-memory Vivado project to compile our sources
create_project -in_memory
set_part $target_device
set_property target_language ${target_lang} [current_project]
set_property default_lib work [current_project]

# Read design sources and constraints into the project 
if {$sources_vhdl != ""} {
    read_vhdl -library xil_defaultlib -vhdl2008  $sources_vhdl
}
if {$sources_sv != ""} {
    read_verilog  $sources_sv
}
if {$sources_bd != ""} {
    read_bd [glob .srcs/sources_1/bd/*/*.bd] 
}
if {$sources_ip != ""} {
    read_ip [glob ./.srcs/sources_1/ip/*/*.xci]
}
if {$sources_xdc_synth != ""} {
    read_xdc ${sources_xdc_synth}
}


# Loop thru all the generis and change them from "GEN1=1" to "-generic GEN1=1"
# Also concat all of these strings into a list "-generic GEN1=1 -generic -GEN2=2"
set generics_list_concat ""
foreach a_generic [split  $generics " "] {
    set generics_list_concat "${generics_list_concat} -generic ${a_generic}"
}

# Build and launch the synthesis command
set synth_cmd "synth_design -top ${top_module} -part ${target_device} ${generics_list_concat} ${synth_args}"
eval $synth_cmd

# Save a design checkpoint and generate reports
write_checkpoint -force post_synth.dcp
report_timing_summary -file $reports_dir/post_synth_timing_summary.rpt
report_power -file $reports_dir/post_synth_power.rpt
