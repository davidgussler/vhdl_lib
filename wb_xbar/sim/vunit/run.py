#!/usr/bin/python3
################################################################################
# File: run.py
# Description: Configures the VUnit test runner
################################################################################

from vunit import VUnit
from os.path import exists
from os import environ


# def generate_tests(obj, data_widths):
#     """ Generate many TB instances by varying generics """
    
#     for data_width in data_widths:
#         # This configuration name is added as a suffix to the test bench name
#         config_name = "data_width=%i" % (data_width)

#         # Add the configuration
#         obj.add_config(
#             name=config_name,
#             generics=dict(data_width=data_width),
#         )


# Use Modelsim
environ["VUNIT_SIMULATOR"] = "modelsim"

# Create VUNit instance from arguments
vu = VUnit.from_argv()
vu.add_verification_components()
vu.add_osvvm()
lib = vu.add_library("lib")

# Add design src files
lib.add_source_files("../../hdl/*.vhd")
lib.add_source_files("../../../utils/gen_utils_pkg.vhd")
lib.add_source_files("*.vhd")


# Don't optomize away unused signals... we want full visibility while debugging
#lib.set_sim_option("modelsim.vsim_flags", ["voptargs=+acc"])

# Add the wave file to the design if it exists
# If this option is uncommented, then Enable Coverage will not run. 
if exists("./wave.do"):
    lib.set_sim_option("modelsim.vsim_flags", ["-do ./../../wave.do"])

# Enable Coverage
# lib.set_compile_option("enable_coverage", True)
# lib.set_compile_option("modelsim.vcom_flags", ["+cover=sbceft"])
# lib.set_sim_option("enable_coverage", True)
# lib.set_sim_option("modelsim.vsim_flags", ["-coverage"])


# Create TB entity object for VUnit
tb = lib.test_bench("wb_xbar_tb")

# Set a generic for all configurations within the test bench
#tb.set_generic("message", "set-for-entity")

# Produce one waveform for all tests rather than reinvoking the simulator each time 
#tb_generated.set_attribute("run_all_in_same_sim", None)

# Get all of the individual VUnit tests defined in the testbench 
# for test in tb.get_tests():
#     # Run all tests with generic in range [2,3]
#     generate_tests(test, range(2, 3))

# Kick off the tests!
vu.main()

