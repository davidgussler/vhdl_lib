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
from cocotb.types import Range
from random import getrandbits
import logging


NUM_SAMPLES = 10
G_DAT_N_COL = int(cocotb.top.G_DAT_N_COL)
G_DAT_COL_W = int(cocotb.top.G_DAT_COL_W)
G_DEPTH = int(cocotb.top.G_DEPTH)
G_RD_LATENCY = int(cocotb.top.G_RD_LATENCY)

class TB(object):

    # The init method of this class can be used to do some setup like logging etc, start the 
    # toggling of the clock and also initialize the internal to their pre-reset vlaue.
    def __init__(self, dut):
        self.dut = dut

        self.log = logging.getLogger("cocotb.tb")
        self.log.setLevel(logging.DEBUG)

        cocotb.start_soon(Clock(dut.i_clk, 10, units="ns").start())


@cocotb.test()
async def test1(dut):
    
    tb = TB(dut)
    data_in = LogicArray(12, Range(G_DAT_COL_W*G_DAT_N_COL-1, 'downto', 0))

    # Apply stimulus
    await RisingEdge(dut.i_clk)
    dut.i_en.value = 1
    dut.i_we.value = 1
    dut.i_adr.value = 1
    dut.i_dat.value = data_in

    await RisingEdge(dut.i_clk)
    await RisingEdge(dut.i_clk)
    await RisingEdge(dut.i_clk)
    await RisingEdge(dut.i_clk)
    data_out = dut.i_dat.value
    
    di = data_in
    do = LogicArray(data_out)

    print()
    print("data in  :", di)
    print("data out :", do)
    print()
    print("data in t :", type(di))
    print("data out t:", type(do))
    print()
    print("data in slice :", di[5:2])
    print("data out slice:", do[5:2])
    print()

    await RisingEdge(dut.i_clk)