#!/usr/bin/python3
################################################################################
# File: run.py
# Description: Configures the VUnit test runner
################################################################################

from vunit import VUnit

# Create VUNit instance from arguments
vu = VUnit.from_argv()

# Add libraries
vu.add_verification_components()
vu.add_osvvm()

# Add files
lib = vu.add_library("lib")
lib.add_source_files("./../../utils/hdl/gen_utils_pkg.vhd")
lib.add_source_files("./../../skid_buff/hdl/skid_buff.vhd")
lib.add_source_files("./../../axi/hdl/axil_to_bus.vhd")
lib.add_source_files("./../../axi/hdl/axil_pipe.vhd")
lib.add_source_files("./../hdl/*.vhd")
lib.add_source_files("./../examples/*.vhd")
lib.add_source_files("./examp_regs_tb.vhd")
lib.add_source_files("./axi_examp_regs_tb.vhd")

# Debugging visibility 
lib.set_compile_option("modelsim.vcom_flags", ["+acc",  "-O0"])

# # Enable Coverage
# lib.set_compile_option("enable_coverage", True)
# lib.set_compile_option("modelsim.vcom_flags", ["+cover=sbceft"])
# lib.set_sim_option("enable_coverage", True)
# lib.set_sim_option("modelsim.vsim_flags", ["-coverage"])

# Start
vu.main()
