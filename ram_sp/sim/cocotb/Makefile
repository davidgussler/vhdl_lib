# Makefile

# NOTE: Watch out for trailing whitespace! 

# Top level language 
TOPLEVEL_LANG ?= vhdl
# Simulator choice 
SIM ?= ghdl#questa

# Generics 
export NUM_SAMPLES        ?= 5000
export GENERIC_DAT_N_COL  ?= 4
export GENERIC_DAT_COL_W  ?= 8
export GENERIC_DEPTH      ?= 2
export GENERIC_RD_LATENCY ?= 1


ifeq ($(TOPLEVEL_LANG),vhdl)
   # Set Sources
	VHDL_SOURCES += $(PWD)/../../../utils/gen_utils_pkg.vhd
	VHDL_SOURCES += $(PWD)/../../hdl/ram_sp.vhd
   VHDL_SOURCES += $(PWD)/test_ram_sp_tb.vhd

   # Set Generics 
   ifneq ($(filter $(SIM),ghdl questa modelsim riviera activehdl),)
      # ghdl, questa, and aldec all use SIM_ARGS with '-g' for setting generics
      SIM_ARGS += -gG_DAT_N_COL=$(GENERIC_DAT_N_COL)
      SIM_ARGS += -gG_DAT_COL_W=$(GENERIC_DAT_COL_W)
      SIM_ARGS += -gG_DEPTH=$(GENERIC_DEPTH)
      SIM_ARGS += -gG_RD_LATENCY=$(GENERIC_RD_LATENCY)
   else
      $(error "A valid value simulator was not provided for SIM=$(SIM)")
   endif

# Set Simulator Settings
   ifeq ($(SIM),ghdl)
      EXTRA_ARGS += --std=08
      EXTRA_ARGS += --ieee=standard
      SIM_ARGS   += --vcd=wave.vcd
   else ifneq ($(filter $(SIM),questa modelsim riviera activehdl),)
      COMPILE_ARGS += -floatgenerics
      COMPILE_ARGS += -2008
      COMPILE_ARGS += +cover=sbceft
      SIM_ARGS += -coverage
      #SIM_ARGS += -ucdbfile cov_file
      SIM_ARGS += -testname coverage
      SIM_ARGS += -coverstore $(PWD)
   endif
else
    $(error "A valid value (vhdl) was not provided for TOPLEVEL_LANG=$(TOPLEVEL_LANG)")
endif

COCOTB_HDL_TIMEPRECISION := ns
# Fix the seed to ensure deterministic tests
export RANDOM_SEED := 123456789
# Top level HDL module 
TOPLEVEL = test_ram_sp_tb
# Coco TB python file name  
#MODULE = test_types 
MODULE = test_ram_sp_structured
COVERAGE=1
# include cocotb's make rules to take care of the simulator setup
include $(shell cocotb-config --makefiles)/Makefile.sim