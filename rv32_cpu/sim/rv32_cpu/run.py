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

neorv32 = vu.add_library("neorv32")
neorv32.add_source_files("./../golden_model/neorv32/rtl/core/neorv32_package.vhd")
neorv32.add_source_files("./../golden_model/neorv32/rtl/core/neorv32_cpu_*.vhd")

lib = vu.add_library("lib")
lib.add_source_files("./../../../utils/hdl/gen_utils_pkg.vhd")
lib.add_source_files("./*.vhd")
lib.add_source_files("./../rv32_testbench_pkg/*.vhd")
lib.add_source_files("./../../hdl/rv32_pkg.vhd")
lib.add_source_files("./../../hdl/rv32_cpu.vhd")





# lib.set_sim_option("modelsim.vsim_flags", ["voptargs=+acc"])

# # Enable Coverage
# lib.set_compile_option("enable_coverage", True)
# lib.set_compile_option("modelsim.vcom_flags", ["+cover=sbceft"])
# lib.set_sim_option("enable_coverage", True)
# lib.set_sim_option("modelsim.vsim_flags", ["-coverage"])




# Run vunit function
vu.main()
