################################################################################
# File     : build.tcl
# Author   : David Gussler - david.gussler@proton.me
# Language : TCL
# ==============================================================================
# Creates a Vivado project for synthesis
#
################################################################################

# Variables 
set prj_name "examp_regs"
set part_num "xc7a35tcpg236-1"

# Create the project
create_project -force $prj_name ./$prj_name -part $part_num


# Add project source files 
add_files -fileset sources_1 [ glob \
    ./../hdl/reg_bank.vhd \
    ./../examples/axi_examp_regs.vhd \
    ./../examples/examp_regs_pkg.vhd \
    ./../examples/examp_regs.vhd \
    ./../../utils/hdl/gen_utils_pkg.vhd \
    ./../../skid_buff/hdl/skid_buff.vhd \
    ./../../axi/hdl/axil_to_bus.vhd \
    ./../../axi/hdl/axil_pipe.vhd \
]

add_files -fileset constrs_1 timing_constrs.xdc

# Set project properties
set_property target_language VHDL [current_project]
set_property simulator_language Mixed [current_project]
set_property file_type {VHDL 2008} [get_files -filter {FILE_TYPE == VHDL}]

# Update to set top file and compile order
update_compile_order -fileset sources_1
