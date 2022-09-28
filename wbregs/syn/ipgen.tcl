################################################################################
# File   : ipgen.tcl
# Author : David Gussler
# Date   : 08-06-2022
# Description
#     Generates Xilinx IP and IP Integrator Block Diagram output products to be 
#     used in synthesis given
#     Accepts the following filetypes as inputs:
#       * create_block_diagram.tcl 
#       * create_ip.tcl
#       * ip_source.xci  
#     This script is part of the Vivado Makefile toolflow project
#     This script is intended for use with Vivado version 2022.1
################################################################################

# Read env variables
set top_module     $::env(TOP_MODULE)
set target_device  $::env(TARGET_DEVICE)
set target_lang $::env(TARGET_LANG)
set sources_ip     $::env(SOURCES_IP)
set sources_bd     $::env(SOURCES_BD)

# Create in-memory project 
create_project -in_memory
set_part ${target_device}
set_property target_language ${target_lang} [current_project]
set_property default_lib work [current_project]


# Generate Vivado IP Integrator block diagram output products for synthesis
if {$sources_bd != ""} {

    # Recreate BD sources from TCL
    foreach script_file [split $sources_bd " "] {
        source $script_file
    }
    # Associating an elf file w/ a microblaze
    #add_files <file_name>.elf
    #set_property SCOPED_TO_CELLS {microblaze_0} [get_files <file_name>.elf]
    #set_property SCOPED_TO_REF {<bd_instance_name>} [get_files <file_name>.elf]

    # Generate BD output products from sources 
    set_property synth_checkpoint_mode None [get_files [glob ./.srcs/sources_1/bd/*/*.bd]]
    generate_target all [get_files [glob ./.srcs/sources_1/bd/*/*.bd]]
}


# Generate Xilinx IP output products for synthesis
if {$sources_ip != ""} {
    set sources_ip_tcl ""
    set sources_ip_xci ""

    # Split the ip sources list based on file-type
    foreach sources_ip_element [split $sources_ip " "] {
        if {[string match "*.tcl" $sources_ip_element]} {
            append sources_ip_tcl " $sources_ip_element"
        } elseif {[string match "*.xci" $sources_ip_element]} {
            append sources_ip_xci " $sources_ip_element"
        }
    }

    # Recreate IP sources from TCL
    if {$sources_ip_tcl != ""} {
        foreach tcl_file $sources_ip_tcl {
            source $tcl_file
        }
    }

    # Import existing IP sources into the project 
    if {$sources_ip_xci != ""} {
        import_ip ${sources_ip_xci}
    }

    # Generate IP output products from sources 
    set_property generate_synth_checkpoint false [get_files [glob ./.srcs/sources_1/ip/*/*.xci]]
    generate_target all [get_files [glob ./.srcs/sources_1/ip/*/*.xci]]
}
