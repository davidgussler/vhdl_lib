################################################################################
# File     : rv32_cpu.tcl
# Author   : David Gussler - david.gussler@proton.me
# Language : TCL
# ==============================================================================
# Creates the vivado project for just the CPU
#
# Call this command from the directory in which this file resides: 
#     vivado -mode batch -source rv32_cpu.tcl
#
################################################################################

# Variables 
set prj_name "rv32_cpu"
set part_num "xc7a35tcpg236-1"

# Create the project
create_project -force $prj_name ./$prj_name -part $part_num

# Add project source files 
add_files -fileset sources_1 [ glob           \
    ./../../hdl/rv32_cpu.vhd                  \
    ./../../hdl/rv32_pkg.vhd                  \
    ./../../../utils/hdl/gen_utils_pkg.vhd    \
]

add_files -fileset constrs_1 timing_constrs.xdc

# Set project properties
set_property target_language VHDL [current_project]
set_property simulator_language Mixed [current_project]
set_property file_type {VHDL 2008} [get_files -filter {FILE_TYPE == VHDL}]

# Update to set top file and compile order
update_compile_order -fileset sources_1
