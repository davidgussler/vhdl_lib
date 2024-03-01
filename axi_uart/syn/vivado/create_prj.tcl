################################################################################
# File     : create_prj.tcl
# Author   : David Gussler - david.gussler@proton.me
# Language : TCL
# ==============================================================================
# Creates a Vivado project for synthesis
#
################################################################################

# Variables
set prj_name "axi_uart"
set part_num "xc7a35tcpg236-1"

# Create the project
create_project -force $prj_name ./$prj_name -part $part_num

# Add project source files
add_files -fileset sources_1 [ glob \
    ./../hdl/axi_uart.vhd \
    ./../hdl/axi_uart_regs.vhd \
    ./../../utils/hdl/gen_utils_pkg.vhd \
    ./../../uart/hdl/uart.vhd \
    ./../../fifo/hdl/fifo.vhd \
    ./../../glitch_filter/hdl/stable_filter.vhd \
    ./../../sync_bit/hdl/sync_bit.vhd \
    ./../../reg_bank/hdl/reg_bank.vhd \
]

add_files -fileset constrs_1 timing_constrs.xdc

# Set project properties
set_property target_language VHDL [current_project]
set_property simulator_language Mixed [current_project]
set_property file_type {VHDL 2008} [get_files -filter {FILE_TYPE == VHDL}]

# Update to set top file and compile order
update_compile_order -fileset sources_1
