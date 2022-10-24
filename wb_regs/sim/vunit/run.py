#!/usr/bin/python3
################################################################################
# File: run.py
# Description: Configures the VUnit test runner
################################################################################

from vunit import VUnit
from os.path import exists

# Create VUNit instance from arguments
vu = VUnit.from_argv()

vu.add_verification_components()

vu.add_osvvm()

lib = vu.add_library("lib")

# Add design src files
lib.add_source_files("../../hdl/*.vhd")
lib.add_source_files("../../../utils/gen_utils_pkg.vhd")
lib.add_source_files("*.vhd")
#lib.add_source_files_from_csv("csv_path")

# Set top level generics
#lib.set_generic("g_name", "800")

# Dont optomize away unused signals... we want full visibility while debugging
lib.set_sim_option("modelsim.vsim_flags", ["voptargs=+acc"])

# Add the wave file to the design if it exists
# If this option is uncommented, then Enable Coverage will not run. 
# if exists("./wave.do"):
#     lib.set_sim_option("modelsim.vsim_flags", ["-do ./../../wave.do"])

# Enable Coverage
lib.set_compile_option("modelsim.vcom_flags", ["+cover=sbceft"])
lib.set_sim_option("modelsim.vsim_flags", ["-coverage"])

# Run vunit function
vu.main()
