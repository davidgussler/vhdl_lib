#!/usr/bin/python3
################################################################################
# File: run.py
# Description: Configures the VUnit test runner
################################################################################

from vunit import VUnit

# Create VUnit instance by parsing command line arguments
vu = VUnit.from_argv()

# Add VCs 
vu.add_verification_components()

# Create library 'lib'
lib = vu.add_library("lib")

# Add source files
lib.add_source_files("../hdl/*.vhd")
lib.add_source_files("./*.vhd")
lib.add_source_files("../../utils/hdl/gen_utils_pkg.vhd")

# Run vunit function
vu.main()
