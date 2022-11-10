################################################################################
#  -<< Vivado Project >>-
# ==============================================================================
# Copyright 2022, David Gusser
# ==============================================================================
# File     : vivado_project.tcl
# Author   : David Gussler - davidnguss@gmail.com 
# Language : TCL
# ==============================================================================
# 1.) Creates a Vivado project from source
# 2.) Builds the created project
#
# Cannot build unless it has already been created 
#
# Call this command from the directory in which this file resides: 
#     vivado -mode batch -source vivado_project.tcl
#
#
################################################################################

# Variables 
set prj_name "rv32_top_prj"
set part_num "xc7a35tcpg236-1"

# Create the project
create_project -force $prj_name ./$prj_name -part $part_num

# Add project source files 
add_files -fileset sources_1 ./../../../hdl/
add_files -fileset sources_1 ./../../../../vhdl_lib/memory_generator/hdl/
add_files -fileset sources_1 ./../../../../vhdl_lib/utils/hdl/gen_utils_pkg.vhd
add_files -fileset constrs_1 ./constrs/timing_constrs.xdc

# Set project properties
set_property target_language VHDL [current_project]
set_property simulator_language Mixed [current_project]
set_property file_type {VHDL 2008} [get_files -filter {FILE_TYPE == VHDL}]

# Update to set top and file compile order
update_compile_order -fileset sources_1
