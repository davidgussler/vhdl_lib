#!/usr/bin/python3
################################################################################
# File: run.py
# Description: Configures the VUnit test runner
################################################################################

from vunit import VUnit

# Create VUNit instance from arguments
vu = VUnit.from_argv()

lib = vu.add_library("lib")

# Add design src files
lib.add_source_files("../../../utils/gen_utils_pkg.vhd")
lib.add_source_files("../../hdl/*.vhd")
lib.add_source_files("../../examples/mem_gen_example_tdp.vhd")
lib.add_source_files("mem_gen_example_tdp_tb.vhd")

# Don't optomize away unused signals... we want full visibility while debugging
lib.set_sim_option("modelsim.vsim_flags", ["voptargs=+acc"])

lib.set_compile_option("modelsim.vcom_flags", ["+cover=sbceft"])
lib.set_sim_option("modelsim.vsim_flags", ["-coverage"])

# Run vunit function
vu.main()
