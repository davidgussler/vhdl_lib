
import os
import math
from typing import Any, Dict, List
import numpy as np


# Cocotb related imports
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge
from cocotb.triggers import RisingEdge
from cocotb.triggers import Timer
from cocotb.regression import TestFactory
from cocotb.handle import SimHandleBase
from cocotb.queue import Queue
from cocotb.types import LogicArray
from cocotb.types import Array
from cocotb.types import Logic
from cocotb.types import Range
from random import getrandbits
import logging


NUM_SAMPLES = 1000
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

class CycleMonitor:
    """Monitors N signals (organized in a dictionary) every clockcycle"""

    # datas is a dictionary that will hold every dut value at every cycle
    def __init__(self, clk, datas : Dict[str, SimHandleBase]):
        self._clk = clk 
        self._datas = datas
        self.data_queue = Queue[Dict[str, int]]()
        self._coro = None

      
    def start(self) -> None:
        """Start monitor"""
        if self._coro is not None:
            raise RuntimeError("Monitor already started")
        # Set _coro equal to the task so we know are running
        self._coro = cocotb.start_soon(self._run())

    def stop(self) -> None:
        """Stop monitor"""
        if self._coro is None:
            raise RuntimeError("Monitor never started")
        # _run goes forever, so we kill it here when we are done monitoring valid data
        self._coro.kill() 
        # Set _coro equal to None so we know that we are no longer running and
        # are available to restart if desired
        self._coro = None 

    async def _run(self) -> None:
        while True:
            await RisingEdge(self._clk)        
            await FallingEdge(self._clk) 
            self.data_queue.put_nowait(self._sample()) 

    def _sample(self) -> Dict[str, Any]:
        """
        Samples the data signals and builds a transaction object

        Return value is what is stored in queue. Meant to be overriden by the user.
        """
        # Returns a dictionary containing {identifier 1 : value 1, identifier 2 : value 2, etc}
        # return {name: handle.value for name, handle in self._datas.items()}
        
        # This does the same thing as the line above 
        dict_a = {}
        for (name, handle) in self._datas.items():
            dict_a[name] = handle.value
        return dict_a


class RamTester:
    def __init__(self, ram_entity: SimHandleBase):
        self.dut = ram_entity

        self._ram = [list(LogicArray(0, Range(G_DAT_COL_W*G_DAT_N_COL-1, 'downto', 0)).binstr) for i in range(G_DEPTH)]
        self._nxt_ram = [list(LogicArray(0, Range(G_DAT_COL_W*G_DAT_N_COL-1, 'downto', 0)).binstr) for i in range(G_DEPTH)]
        
        if (G_RD_LATENCY > 0):
            self._dout = [list(LogicArray(0, Range(G_DAT_COL_W*G_DAT_N_COL-1, 'downto', 0)).binstr) for i in range(G_RD_LATENCY)]
            self._nxt_dout = [list(LogicArray(0, Range(G_DAT_COL_W*G_DAT_N_COL-1, 'downto', 0)).binstr) for i in range(G_RD_LATENCY)]
        elif(G_RD_LATENCY == 0):
            self._dout = list(LogicArray(0, Range(G_DAT_COL_W*G_DAT_N_COL-1, 'downto', 0)).binstr)
            self._nxt_dout = list(LogicArray(0, Range(G_DAT_COL_W*G_DAT_N_COL-1, 'downto', 0)).binstr)
        else:
            raise Exception("ERROR: G_RD_LATENCY must be >= 0")


        self._checker = None

        # Create the input monitor object with init values from the dut object
        self.input_mon = CycleMonitor(
            clk=self.dut.i_clk,
            datas=dict(EN=self.dut.i_en, WE=self.dut.i_we, AD=self.dut.i_adr, DI=self.dut.i_dat)
        )
        
        # Create the output monitor object with init values from the dut object
        self.output_mon = CycleMonitor(
            clk=self.dut.i_clk,
            datas=dict(DO=self.dut.o_dat)
        )

    def start(self) -> None:
        """Starts monitors, model, and checker coroutine"""
        if self._checker is not None:
            raise RuntimeError("Checker already started")
        self.input_mon.start()
        self.output_mon.start()
        self._checker = cocotb.start_soon(self._check())

    def stop(self) -> None:
        """Stops everything"""
        if self._checker is None:
            raise RuntimeError("Checker never started")
        self.input_mon.stop()
        self.output_mon.stop()
        self._checker.kill()
        self._checker = None

    def model(self, en, we, adr, dat_in) -> LogicArray:

        # Flip Flop Model
        for p in range(G_DEPTH):
            for g in range(G_DAT_COL_W*G_DAT_N_COL):
                self._ram[p][g] = self._nxt_ram[p][g]
        for w in range(G_RD_LATENCY):
            for h in range (G_DAT_COL_W*G_DAT_N_COL):
                self._dout[w][h] = self._nxt_dout[w][h]

        # Comb Logic Model
        if (G_RD_LATENCY == 0):
            self._dout = self._ram[adr][:]

        # Nxt State Logic Model
        if (en[0] == '1'): 
            for j in range(G_DAT_N_COL):
                if (we[j] == '1'):
                    for q in range(j*G_DAT_COL_W, j*G_DAT_COL_W+G_DAT_COL_W):
                        self._nxt_ram[adr][q] = dat_in[q]
            if (G_RD_LATENCY > 0):
                for i in range(G_RD_LATENCY-1): 
                    for h in range (G_DAT_COL_W*G_DAT_N_COL):
                        self._nxt_dout[i][h] = self._dout[i+1][h]
                for h in range (G_DAT_COL_W*G_DAT_N_COL):
                    self._nxt_dout[G_RD_LATENCY-1][h] = self._ram[adr][h]
    
        if (G_RD_LATENCY > 0):
            return self._dout[0]
        else:
            return self._dout

    async def _check(self) -> None:
        while True:
            # run the queue get methods on the dictionary values of the queues 
            # get the new value immediatly after it has been added 
            actual_output = await self.output_mon.data_queue.get()
            slv_actual_output = LogicArray(actual_output["DO"])
            module_inputs = await self.input_mon.data_queue.get()
            #print(LogicArray(module_inputs["AD"]))
            slv_expected_output = self.model(
                en=list(LogicArray(module_inputs["EN"]).binstr), 
                we=list(LogicArray(module_inputs["WE"], Range(G_DAT_N_COL-1, 'downto', 0)).binstr), 
                adr=LogicArray(module_inputs["AD"]).integer,
                dat_in=list(LogicArray(module_inputs["DI"], Range(G_DAT_COL_W*G_DAT_N_COL-1, 'downto', 0)).binstr))

            assert slv_actual_output.binstr == "".join(slv_expected_output)
            print("en     :",module_inputs["EN"])
            print("we     :",module_inputs["WE"])
            print("adr    :",module_inputs["AD"])
            print("dat in :",module_inputs["DI"])
            print()
            print("actual dat out:",slv_actual_output.binstr)
            print("expect dat out:","".join(slv_expected_output))
            # print()
            self.dut.tb_blip.value = 1
            #await Timer(1, units="ns")
            self.dut.tb_blip.value = 0


@cocotb.test()
async def test1(dut):
    """Test RAM output at every cycle."""

    # Initialize the TB class 
    # this just starts the logger and starts the clock 
    tb = TB(dut)

    # Initialize the tester class 
    tester = RamTester(dut)

    dut._log.info("Initialize the module values")

    # Initial values
    dut.i_en.value = 0
    dut.i_we.value = 0
    dut.i_adr.value = 0
    dut.i_dat.value = 0 

    # start tester
    #await RisingEdge(dut.i_clk)
    tester.start()

    dut._log.info("Test starting")

    print(G_DAT_N_COL)
    print(G_DAT_COL_W) 
    print(G_DEPTH)
    print(G_RD_LATENCY)

    # Apply stimulus
    for i, (EN, WE, AD, DI) in enumerate(zip(gen_en(), gen_we(), gen_adr(), gen_data_in())):
        await RisingEdge(dut.i_clk)
        dut.i_en.value = EN
        dut.i_we.value = WE
        dut.i_adr.value = AD
        dut.i_dat.value = DI

        if i % 1 == 0:
            dut._log.info(f"{i} / {NUM_SAMPLES}")
        

    await RisingEdge(dut.i_clk)


# These are generator functions because the use yeild instead of return 
# Generators are iterators, a kind of iterable you can only iterate over once.
# Generators do not store all the values in memory, they generate the values on the fly
# it's handy when you know your function will return a huge set of values that you will 
# only need to read once.

def gen_en(num_samples=NUM_SAMPLES, width=1):
    for _ in range(num_samples):
        yield getrandbits(width)

def gen_we(num_samples=NUM_SAMPLES, width=G_DAT_N_COL):
    for _ in range(num_samples):
        yield getrandbits(width) # LogicArray("1111") #

def gen_adr(num_samples=NUM_SAMPLES, width=math.ceil(math.log2(G_DEPTH))):
    for _ in range(num_samples):
        yield getrandbits(width)

def gen_data_in(num_samples=NUM_SAMPLES, width=G_DAT_N_COL*G_DAT_COL_W):
    for _ in range(num_samples):
        yield getrandbits(width)