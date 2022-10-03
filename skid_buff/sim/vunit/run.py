from vunit import VUnit

# Create VUnit instance by parsing command line arguments
vu = VUnit.from_argv()

# Add VCs 
vu.add_verification_components()

# Create library 'lib'
lib = vu.add_library("lib")

# Add all files ending in .vhd in current working directory to library
lib.add_source_files("../../hdl/*.vhd")
lib.add_source_files("../../tb/*.vhd")

# Run vunit function
vu.main()