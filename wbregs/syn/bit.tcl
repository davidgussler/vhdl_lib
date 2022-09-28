################################################################################
# File   : bit.tcl
# Author : David Gussler
# Date   : 08-06-2022
# Description
#     Generates a bitfile from the implemented design. Also generates an xsa file
#     if there is a processor and/or AXI memory mapped interface associated with
#     the design
#     This script is part of the Vivado Makefile toolflow project
#     This script is intended for use with Vivado version 2022.1
################################################################################

set build_dir ./build
file mkdir $build_dir
set top_module    $::env(TOP_MODULE)

open_checkpoint post_route.dcp

# Generate a bitstream
write_bitstream -force $build_dir/${top_module}.bit

# Generate hardware handoff file for Vitis
# write_hw_platform -fixed -force -include_bit -file $build_dir/$top_module.xsa
