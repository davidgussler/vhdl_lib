################################################################################
# File: run.py
# Description: Configures the VUnit test runner
################################################################################

from vunit import VUnit

# Create VUnit instance by parsing command line arguments
vu = VUnit.from_argv()

# Add Verification Components Library
vu.add_verification_components()

# Add OSVVM Library
vu.add_osvvm()

# Create library 'lib'
lib = vu.add_library("lib")

# Add source files to lib
lib.add_source_files("../../hdl/*.vhd")
lib.add_source_files("../../../utils/gen_utils_pkg.vhd")

# Add testbench files to lib
lib.add_source_files("*.vhd")

# Run vunit function
vu.main()
