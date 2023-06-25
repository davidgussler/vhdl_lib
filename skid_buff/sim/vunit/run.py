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

# Add all files ending in .vhd in current working directory to library
lib.add_source_files("../../hdl/*.vhd")
lib.add_source_files("./*.vhd")

# Debugging visibility 
lib.set_compile_option("modelsim.vcom_flags", ["+acc",  "-O0"])

# Start
vu.main()