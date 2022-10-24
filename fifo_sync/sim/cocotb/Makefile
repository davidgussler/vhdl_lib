# Makefile

# NOTE: Watch out for trailing whitespace! 

# Top level language 
TOPLEVEL_LANG ?= vhdl
# Simulator choice 
#SIM ?= questa
SIM ?= ghdl


# Number of samples to feed into the simulation
export NUM_SAMPLES      ?= 500

# Generics 
export GEN_WIDTH          ?= 16
export GEN_DEPTH_LOG2     ?= 10
export GEN_ALMOST_FULL    ?= 2
export GEN_ALMOST_EMPTY   ?= 2


ifeq ($(TOPLEVEL_LANG),vhdl)
   # Set Sources
	VHDL_SOURCES += $(PWD)/../../hdl/fifo_sync.vhd

   # Set Generics 
   ifneq ($(filter $(SIM),ghdl questa modelsim riviera activehdl),)
      # ghdl, questa, and aldec all use SIM_ARGS with '-g' for setting generics
      #SIM_ARGS += -gG_WIDTH        =$(GEN_WIDTH       )
      #SIM_ARGS += -gG_DEPTH_LOG2   =$(GEN_DEPTH_LOG2  )
      #SIM_ARGS += -gG_ALMOST_FULL  =$(GEN_ALMOST_FULL )
      #SIM_ARGS += -gG_ALMOST_EMPTY =$(GEN_ALMOST_EMPTY)
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
TOPLEVEL = fifo_sync
# Coco TB python file name  
MODULE = test_fifo_sync
COVERAGE=1
# include cocotb's make rules to take care of the simulator setup
include $(shell cocotb-config --makefiles)/Makefile.sim