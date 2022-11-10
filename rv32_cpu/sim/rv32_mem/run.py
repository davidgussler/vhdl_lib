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
lib.add_source_files("*.vhd")
lib.add_source_files("../*.vhd")
lib.add_source_files("../../../hdl/rv32_pkg.vhd")

# Run vunit function
vu.main()
