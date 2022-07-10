
import os
import math
from typing import Any, Dict, List

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
from cocotb.types import Range
from random import getrandbits
import logging
import copy

from cocotb_test.simulator import run
import pytest


def int_to_blist(input, n_bits):
    return list(LogicArray(input,Range(n_bits-1,'downto',0)).binstr)

def blist_to_int(input):
    return LogicArray(''.join(input)).integer


def gen_en(num_samples, width):
    for _ in range(num_samples):
        yield getrandbits(width)

def gen_we(num_samples, width):
    for _ in range(num_samples):
        yield  getrandbits(width) 

def gen_adr(num_samples, width):
    for _ in range(num_samples):
        yield getrandbits(width)

def gen_data_in(num_samples, width):
    for _ in range(num_samples):
        yield getrandbits(width)


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

        G_RD_LATENCY = self.dut.G_RD_LATENCY.value.integer
        G_DEPTH = self.dut.G_DEPTH.value.integer

        self._ram = [0 for i in range(G_DEPTH)]
        self._nxt_ram = [0 for i in range(G_DEPTH)]

        if (G_RD_LATENCY > 0):
            self._dout = [0 for i in range(G_RD_LATENCY)]
            self._nxt_dout = [0 for i in range(G_RD_LATENCY)]
        elif(G_RD_LATENCY == 0):
            self._dout = [0]
            self._nxt_dout = [0]
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
        """Model of the RAM Module"""
        
        G_RD_LATENCY = self.dut.G_RD_LATENCY.value.integer
        G_DAT_COL_W = self.dut.G_DAT_COL_W.value.integer
        G_DAT_N_COL = self.dut.G_DAT_N_COL.value.integer

        # Flip Flop Model
        self._ram = copy.copy(self._nxt_ram)
        self._dout = copy.copy(self._nxt_dout)

        # Comb Logic Model
        if (G_RD_LATENCY == 0):
            self._dout[0] = self._ram[adr]

        # Nxt State Logic Model
        if (en == 1): 
            nxt_ram_blist = int_to_blist(self._nxt_ram[adr], G_DAT_COL_W*G_DAT_N_COL)
            dat_in_blist = int_to_blist(dat_in, G_DAT_COL_W*G_DAT_N_COL)
            we_blist = int_to_blist(we,G_DAT_N_COL)

            for j in range(G_DAT_N_COL):
                if (we_blist[j] == '1'):
                    nxt_ram_blist[j*G_DAT_COL_W : j*G_DAT_COL_W+G_DAT_COL_W] = \
                            dat_in_blist[j*G_DAT_COL_W : j*G_DAT_COL_W+G_DAT_COL_W]
            
            
            self._nxt_ram[adr] = blist_to_int(nxt_ram_blist)
            
            if (G_RD_LATENCY > 0):
                for i in range(G_RD_LATENCY-1): 
                    self._nxt_dout[i] = self._dout[i+1]
                self._nxt_dout[G_RD_LATENCY-1] = self._ram[adr]

        return self._dout[0]

    async def _check(self) -> None:
        while True:
            # run the queue get methods on the dictionary values of the queues 
            # get the new value immediatly after it has been added 
            actual_output = await self.output_mon.data_queue.get()
            actual_output = actual_output["DO"].integer
            module_inputs = await self.input_mon.data_queue.get()
            expected_output = self.model(
                en=module_inputs["EN"].integer, 
                we=module_inputs["WE"].integer, 
                adr=module_inputs["AD"].integer,
                dat_in=module_inputs["DI"].integer)

            assert expected_output == actual_output

            self.dut._log.info("en     : " + str(module_inputs["EN"]))
            self.dut._log.info("we     : " + str(module_inputs["WE"]))
            self.dut._log.info("adr    : " + str(module_inputs["AD"].integer))
            self.dut._log.info("dat in : " + str(module_inputs["DI"].integer))
            self.dut._log.info("actual dat out: " + str(actual_output))
            self.dut._log.info("expect dat out: " + str(expected_output))
            self.dut._log.info("")



@cocotb.test()
async def test1(dut):
    """Test RAM output at every cycle."""
    
    G_RD_LATENCY = dut.G_RD_LATENCY.value.integer
    G_DAT_COL_W = dut.G_DAT_COL_W.value.integer
    G_DAT_N_COL = dut.G_DAT_N_COL.value.integer
    G_RD_LATENCY = dut.G_RD_LATENCY.value.integer
    G_DEPTH = dut.G_DEPTH.value.integer
    NUM_SAMPLES  = int(os.environ.get("NUM_SAMPLES", 3000))
    

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
    tester.start()

    dut._log.info("TEST STARTING")
    dut._log.info("Generics Selected:")
    dut._log.info("G_DAT_N_COL : " + str(G_DAT_N_COL))
    dut._log.info("G_DAT_COL_W : " + str(G_DAT_COL_W) )
    dut._log.info("G_DEPTH     : " + str(G_DEPTH))
    dut._log.info("G_RD_LATENCY: " + str(G_RD_LATENCY))
    dut._log.info("")

    # Apply stimulus
    for i, (EN, WE, AD, DI) in enumerate(zip(gen_en(NUM_SAMPLES,1), \
            gen_we(NUM_SAMPLES,G_DAT_N_COL), gen_adr(NUM_SAMPLES,math.floor(math.log2(G_DEPTH))), \
            gen_data_in(NUM_SAMPLES,G_DAT_N_COL*G_DAT_COL_W))):

        await RisingEdge(dut.i_clk)
        dut.i_en.value = EN
        dut.i_we.value = WE
        dut.i_adr.value = AD
        dut.i_dat.value = DI

        if i % 10 == 0:
            dut._log.info(f"{i} / {NUM_SAMPLES}")
        
    await RisingEdge(dut.i_clk)
    await RisingEdge(dut.i_clk)
    await RisingEdge(dut.i_clk)



# cocotb-test

# tests_dir = os.path.dirname(os.path.realpath(__file__))
# rtl_dir = os.path.abspath(os.path.join(tests_dir, '..', '..', 'rtl'))

# @pytest.mark.parametrize(
#         "G_DAT_N_COL, G_DAT_COL_W, G_DEPTH, G_RD_LATENCY", [(4,8,32,1)])
# def test_ram_sp(request, G_DAT_N_COL, G_DAT_COL_W, G_DEPTH, G_RD_LATENCY):
#     module = os.path.splitext(os.path.basename(__file__))[0]
#     toplevel = "ram_sp"
    
#     vhdl_sources = [
#         os.path.join(tests_dir,"..","..","..","..","gen_logic","gen_utils_pkg.vhd"),
#         os.path.join(tests_dir,"..","..","..","mem_utils_pkg.vhd"),
#         os.path.join(rtl_dir, "ram_sp.vhd"),
#     ]

#     parameters = {}  

#     parameters["G_DAT_N_COL"] = G_DAT_N_COL
#     parameters["G_DAT_COL_W"] = G_DAT_COL_W
#     parameters["G_DEPTH"] = G_DEPTH
#     parameters["G_RD_LATENCY"] = G_RD_LATENCY


#     extra_env = {f'PARAM_{k}': str(v) for k, v in parameters.items()}

#     sim_build = os.path.join(tests_dir, "sim_build",
#         request.node.name.replace('[', '-').replace(']', ''))
    
#     run(
#         python_search=[tests_dir],
#         toplevel_lang="vhdl",
#         vhdl_sources=vhdl_sources,
#         toplevel=toplevel,
#         module=module,
#         parameters=parameters,
#         extra_env=extra_env,
#         sim_build=sim_build,
#         seed=123456789,
#         compile_args=["--std=08"],
#     )
#
# SIM=ghdl NUM_SAMPLES=20 pytest -o log_cli=True test_ram_sp_structured.py

