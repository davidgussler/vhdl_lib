################################################################################
# Makefile for Xilinx Vivado Build Toolchain
################################################################################
# File   : Makefile
# Author : David Gussler
# Date   : 08-06-2022
# Description
#     The goal of this project was to make a flexible CLI based method for
#     interacting with Xilinx Vivado FPGA Synthesis and Implementation tools.
#     You can add as many Xilinx IPs and Block diagrams to a project as you want!
#     You just have to specify the path to the source files. This build system
#     accepts block diagram tcl files, IP tcl files, and IP xci files as source,
#     (along with vhdl and verilog files, of course)
#     Run "make bit" from the command line to go from source to bitstream, or 
#     alternateivly, run intermediate make commands to manually step thru each
#     phase of the build process.
#
#     This makefile calls a multitude of tcl scripts that perform all the build 
#     stages of FPGA development, from source to bitstream.
#     This build flow system uses Vivado Non-Project mode, which gives the user
#     greater control over their environment. The only real drawback is the
#     lack of OOC synthesis support, which means that IPI-BD and IP synthesis 
#     results are not stored between runs, leading to longer synthesis run times. 
#
################################################################################

# TODO: Add conditional xsa generation in the bitfile phase if cpu(s)  detected
# TODO: Add code to associate an elf with a cpu 
# TODO: (Possibly) add user controlls for adding extra options to implementation
# TODO: Add method to program the QSPI configuration flash from the CLI

################################################################################
# START USER EDIT REGION
################################################################################
# ==== Top Level Synthesis Information ==== #
TOP_MODULE    := wbregs_example
TARGET_DEVICE := xc7a35tcpg236-1
TARGET_LANG   := VHDL

# ==== Source Files ==== #
# VHDL source files (*.vhd, *.vhdl); Accepts vhdl 2008 files as well
SOURCES_VHDL := ../../utils/gen_utils_pkg.vhd \
                ../hdl/wbregs.vhd  \
                ../hdl/wbregs_example.vhd

# Verilog and SystemVerilog files (*.v, *.vh, *.sv, *.svh)
SOURCES_SV   := 

# Xilinx IP source files and IP generation files(*.xci, *.tcl)
SOURCES_IP   := 

# Xilinx IP-Integrator Block Diagram (IPI-BD) generation files(*.tcl)
SOURCES_BD   :=	

# Constraints files (*.xdc) to be used in synthesis AND implementation
# Typically timing and clock related constraints
SOURCES_XDC_SYNTH := timing_cnstrs.xdc

# Constraints files (*.xdc) to be used in implementaiton ONLY
# Typically physical and device configuration constraints
SOURCES_XDC_IMPL  := ../../src/xdc/config_cnstrs.xdc \
                     ../../src/xdc/physical_cnstrs.xdc


# == Top Level Parameters / Generics == #
GENERICS += 


# ==== Extra Synthesis Arguments ==== #
SYNTH_ARGS += 


################################################################################
# END USER EDIT REGION - Do not modify below this line
################################################################################


# ==== Export to environment for use in tcl files ==== #
export TOP_MODULE
export TARGET_DEVICE
export TARGET_LANG
export SOURCES_VHDL
export SOURCES_SV
export SOURCES_IP
export SOURCES_BD
export SOURCES_XDC_SYNTH
export SOURCES_XDC_IMPL
export GENERICS
export SYNTH_ARGS

# Make Rules
# ==== Help ==== #
.PHONY : help
help : 
	@echo "=== Vivado Build Flow Make Interface ==="
	@echo "-- Build Flow Options ---------------------------------------------------------"
	@echo "     make bit       - Generate the final bitstream"
	@echo "     make route_gui - Open the routed design in the Vivado GUI"
	@echo "     make route     - Route design"
	@echo "     make place_gui - Open the placed design in the Vivado GUI"
	@echo "     make place     - Place design"
	@echo "     make synth_gui - Open the synthesized design in the Vivado GUI"
	@echo "     make synth     - Synthesize design"
	@echo "     make ipgen     - Generate all Xilinx IP and Xilinx IPI-BD output products"
	@echo "-- Device Programming ----------------------------------------------------------"
	@echo "     make prog_fpga  - Program the FPGA with the bitfile over JTAG"
	@echo "     !TBD! make debug_fpga - Open the Vivado debugger GUI"	
	@echo "     !TBD! make prog_sram  - Program the the on-board SRAM "
	@echo "     !TBD! make mem_cfg    - Generate an SRAM FPGA configuration file"
	@echo "-- Utilities --------------------------------------------------------------------"
	@echo "     make help      - You're here right now!"
	@echo "     make clean     - Delete generated files"


# ==== Program ==== #
prog_fpga : ./build/$(TOP_MODULE).bit
	@echo
	@echo "### PROGRAMMING DEVICE ###"
	vivado -mode batch -source prog_fpga.tcl


# ==== Bitstream ==== #
.PHONY : bit
bit : build/$(TOP_MODULE).bit

build/$(TOP_MODULE).bit : post_route.dcp
	@echo
	@echo "### GENERATING BITSTREAM FILE ###"
	vivado -mode batch -source bit.tcl


# ==== Route ==== #
.PHONY : route
route : post_route.dcp

.PHONY : route_gui
route_gui : post_route.dcp
	@echo
	@echo "### OPENING ROUTED DESIGN ###"
	vivado -mode gui -source post_route.dcp &

post_route.dcp : post_place.dcp
	@echo
	@echo "### ROUTING DESIGN ###"
	vivado -mode batch -source route.tcl


# ==== Place ==== #
.PHONY : place
place : post_place.dcp

.PHONY : place_gui
place_gui : post_place.dcp
	@echo
	@echo "### OPENING PLACED DESIGN ###"
	vivado -mode gui -source post_place.dcp &

post_place.dcp : post_synth.dcp $(SOURCES_XDC_IMPL)
	@echo
	@echo "### PLACING DESIGN ###"
	vivado -mode batch -source place.tcl


# ==== Synthesize ==== #
.PHONY : synth
synth : post_synth.dcp

.PHONY : synth_gui
synth_gui : post_synth.dcp
	@echo
	@echo "### OPENING SYNTHESIZED DESIGN ###"
	vivado -mode gui -source post_synth.dcp &

post_synth.dcp : .ipgen.timestamp $(SOURCES_VHDL) $(SOURCES_SV) $(SOURCES_XDC_SYNTH)
	@echo
	@echo "### SYNTHESIZING DESIGN ###"
	vivado -mode batch -source synth.tcl


# ==== Generate IPs and BDs from source (if they exist) ==== #
.PHONY : ipgen
ipgen : .ipgen.timestamp

.ipgen.timestamp : $(SOURCES_IP) $(SOURCES_BD)
ifeq ($(SOURCES_IP)$(SOURCES_BD),)
	@echo
	@echo "### NO XILINX BLOCK DIAGRAM OR IP SOURCES PRESENT ###"
	@echo "### SKIPPING XILINX OUTPUT PRODUCT GENERATION ###"
	touch .ipgen.timestamp
else
	@echo
	@echo "### GENERATING XILINX OUTPUT PRODUCTS ###"
	vivado -mode batch -source ipgen.tcl
	touch .ipgen.timestamp
endif


# ==== Clean ==== #
.PHONY : clean
clean :
	@rm -rf .*.timestamp
	@rm -rf *.jou *.log *.pb *.wdb xsim.dir .Xil *.str # Deletes all files generated by Vivado
	@rm -rf .gen .srcs                     # Deletes block diagram and IP generated by TCL
	@rm -rf *.dcp                          # Deletes all our design checkpoints
	@rm -rf build reports                  # Deletes output folders generated by tcl scripts
	@echo
	@echo "### CLEANED WORKSPACE ###"
	@echo
