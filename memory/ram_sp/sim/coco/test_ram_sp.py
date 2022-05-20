# test_ram_sp.py

# Imports for my functions 
import os
import math

# Cocotb related imports
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge
from cocotb.triggers import RisingEdge
from cocotb.triggers import Timer
from cocotb.regression import TestFactory
import random
import logging

G_DAT_N_COL = int(cocotb.top.G_DAT_N_COL)
G_DAT_COL_W = int(cocotb.top.G_DAT_COL_W)
G_DEPTH = int(cocotb.top.G_DEPTH)
G_RD_LATENCY = int(cocotb.top.G_RD_LATENCY)


# Create this TB object in every test so that all the required TB functions can be accessed
class TB(object):

   # The init method of this class can be used to do some setup like logging etc, start the 
   # toggling of the clock and also initialize the internal to their pre-reset vlaue.
   def __init__(self, dut):
      self.dut = dut

      self.log = logging.getLogger("cocotb.tb")
      self.log.setLevel(logging.DEBUG)

      cocotb.start_soon(Clock(dut.i_clk, 10, units="ns").start())

   # Custom TB Level Function definitions go here
   # NOTE: every supporting function you define inside the TB class should have 'self' as an input parameter, otherwise you'll get an number of parameters error.

   # << Function #1 >> 

   # << Function #2 >>

   def truncate(self, number, digits) -> float:
      stepper = 10.0 ** digits
      return math.trunc(stepper * number) / stepper

	# Note the 'async def' keyword here. It means that this is a coroutine that needs to 
	# be awaited.
   async def cycle_reset(self):
      self.dut.i_rst.setimmediatevalue(0)
      await RisingEdge(self.dut.clk)
      await RisingEdge(self.dut.clk)
      self.dut.i_rst.value = 1
      await RisingEdge(self.dut.clk)
      await RisingEdge(self.dut.clk)
      self.dut.i_rst.value = 0
      await RisingEdge(self.dut.clk)
      await RisingEdge(self.dut.clk)


# class ram_model: 
#    """ A class for modeling the read and write process of a single port ram """
#    def __init__(self):
#       self.ram = [0] * G_DEPTH #TODO: this may not match the generic defined initialization
#       self.last_latched_addr = 0 

#    async def ram_wr(self, enable, write_enable, address, data_in, clock):
#       await RisingEdge(clock)
      
#       if (enable): 
#          if (write_enable): 
#             self.ram[address] = data_in

#    async def ram_rd(self, enable, address, data_out, clock):
#       data_out.value = self.ram[address]
      
#       if (G_RD_LATENCY > 0):
#          for i in range(G_RD_LATENCY-1): 
#             print("test")
#             await RisingEdge(clock)

#       data_out.value = self.ram[address]
#       if (enable): 
#          self.last_latched_addr = address 


# Trying a model that takes zero time 
class ram_model: 
   """ A class for modeling the read and write process of a single port ram """
   def __init__(self):
      self.ram = [0] * G_DEPTH #TODO: this may not match the generic defined initialization
      self.last_latched_addr = 0 

   def ram_wr(self, enable, write_enable, address, data_in, clock):
      if (enable): 
         if (write_enable): 
            self.ram[address] = data_in

   def ram_rd(self, enable, address, clock):
      data_out = self.ram[self.last_latched_addr]
      if (enable): 
         self.last_latched_addr = address 
      return data_out

# @cocotb.test()        #decorator indicates that this is a test that needs to be run by cocotb.
# async def test1(dut): #dut is a pointer to the top module. This is built in
#    tb = TB(dut)       #creating a testbench object for this dut. __init__ function is run automatically
#    await Timer(1)     #pauses current function and lets the simulator run for 1 time step.
#                       #duration of each timestep is determined by the parameter COCOTB_HDL_TIMEPRECISION in the makefile
   
#    # tb.dut._log.info('resetting the module') #logging helpful messages
#    # await tb.cycle_reset() #running the cycle_reset corouting defined above
#    # tb.dut._log.info('out of reset')

#    print(G_DAT_N_COL)
#    print(G_DAT_COL_W)
#    print(G_DEPTH)
#    print(G_RD_LATENCY)


#    i_adr_tb = 0
#    data_array = [] 
#    for i in range(10):

#       # Create random stimulus values 
#       # i_en_tb = random.randint(0, 1)
#       # i_we_tb = random.randint(0, 2**4-1)
#       # i_adr_tb = random.randint(0, 2**10-1)
#       # i_dat_tb = random.randint(0, 2**32-1)
     
#       i_en_tb = 1
#       i_we_tb = 1 # 2**4-1
#       i_adr_tb = i_adr_tb + 1
#       i_dat_tb = random.randint(0, 10) + i_adr_tb

#       ## DUT 
#       await RisingEdge(dut.i_clk)
#       await Timer(1, units="ns")
#       dut.i_en.value = i_en_tb 
#       dut.i_we.value = i_we_tb  
#       dut.i_adr.value = i_adr_tb 
#       dut.i_dat.value = i_dat_tb 

#       # Write to the golden model ram 
#       # if (i_en_tb == 1):
#       #    if ()
#       # data_array[i_adr_tb] = i_dat_tb; 

#       # Wait a cycle for the output to become valid
#       await RisingEdge(dut.i_clk)
#       await RisingEdge(dut.i_clk)
#       await RisingEdge(dut.i_clk)
#       await RisingEdge(dut.i_clk)
#       # Wait a half cycle for checking 
#       await FallingEdge(dut.i_clk)

#       # Check and log the oputputs
#       val1 = int(dut.o_dat.value)
#       val2 = int(i_dat_tb)
#       dut._log.info("o_dat is %s", val1)
#       dut._log.info("i_dat is %s", val2)
#       assert (val1 == val2), "output was incorrect on the {}th cycle".format(i)

#    # i_adr_tb = 0 
#    # for i in range(10):
#    #    await RisingEdge(dut.i_clk)
#    #    await Timer(1, units="ns")
      
#    #    # Create random stimulus values 
#    #    #i_en_tb = random.randint(0, 1)
#    #    #i_we_tb = random.randint(0, 2**4-1)
#    #    #i_adr_tb = random.randint(0, 2**10-1)
#    #    #i_dat_tb = random.randint(0, 2**32-1)
#    #    i_en_tb = 1
#    #    i_we_tb = 0
#    #    i_adr_tb = i_adr_tb + 1
#    #    i_dat_tb = 0

      
#    #    ## Write the stimuli to the dut 
#    #    dut.i_en.value = i_en_tb 
#    #    dut.i_we.value = i_we_tb  
#    #    dut.i_adr.value = i_adr_tb 
#    #    dut.i_dat.value = i_dat_tb 

#    #    await RisingEdge(dut.i_clk)
#    #    await Timer(1, units="ns")

#    #    # Check the outputs 
#    #    #assert not dut.o_dat.value == 1, "output was incorrect on the {}th cycle".format(i)


@cocotb.test()      
async def test2(dut):

   print(G_RD_LATENCY)

   tb = TB(dut)
   ram_mdl = ram_model()
   i_adr_tb = 0
   model_data = 1
   
   # Do a bunch of random writes 
   for i in range(15): 
      i_en_tb =  random.randint(0, 1)
      i_we_tb = 1 # 2**4-1
      i_adr_tb = random.randint(0, 10)
      i_dat_tb = random.randint(0, 10) + i_adr_tb

      # Set dut inputs 
      await RisingEdge(dut.i_clk)
      #await Timer(1, units="ns")
      dut.i_en.value = i_en_tb 
      dut.i_we.value = i_we_tb  
      dut.i_adr.value = i_adr_tb 
      dut.i_dat.value = i_dat_tb 

      ram_mdl.ram_wr(enable = i_en_tb, write_enable = i_we_tb, address = i_adr_tb, data_in = i_dat_tb, clock = dut.i_clk))
      model_data = ram_mdl.ram_rd(enable = i_en_tb, address = i_adr_tb, clock = dut.i_clk)

      await FallingEdge(dut.i_clk)

      dut_data = int(dut.o_dat.value)
      
      print (dut_data, model_data)


      # # Set golden model inputs at the same time as dut inputs 
      # 
      
      # # Start the timing for the reading at the same time as the write, wait for it to complete 
      # await (ram_mdl.ram_rd(enable = i_en_tb, address = i_adr_tb, data_out = model_data, clock = dut.i_clk))
      # dut_data = int(dut.o_dat.value)

      # print(model_data, dut_data)