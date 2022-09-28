
import math
from typing import Any, Dict, List
import copy 


# Cocotb related imports
import cocotb

from cocotb.types import LogicArray

from cocotb.types import Range
from random import getrandbits



NUM_SAMPLES = 10
G_DAT_N_COL = 4
G_DAT_COL_W = 4
G_DEPTH = 8
G_RD_LATENCY = 0

def int_to_blist(input, n_bits):
    return list(LogicArray(input,Range(n_bits-1,'downto',0)).binstr)

def blist_to_int(input):
    return LogicArray(''.join(input)).integer

class RamTester:
    def __init__(self):

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

    def model(self, en, we, adr, dat_in) -> LogicArray:
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
                    nxt_ram_blist[j*G_DAT_COL_W : j*G_DAT_COL_W+G_DAT_COL_W-1] = dat_in_blist[j*G_DAT_COL_W : j*G_DAT_COL_W+G_DAT_COL_W-1]
            self._nxt_ram[adr] = blist_to_int(nxt_ram_blist)
            
            if (G_RD_LATENCY > 0):
                for i in range(G_RD_LATENCY-1): 
                    self._nxt_dout[i] = self._dout[i+1]
                self._nxt_dout[G_RD_LATENCY-1] = self._ram[adr]

        return self._dout[0]


def gen_en(num_samples=NUM_SAMPLES, width=1):
    for _ in range(num_samples):
        yield 1 # getrandbits(width)

def gen_we(num_samples=NUM_SAMPLES, width=G_DAT_N_COL):
    for _ in range(num_samples):
        yield getrandbits(width) # LogicArray("1111") #

def gen_adr(num_samples=NUM_SAMPLES, width=math.ceil(math.log2(G_DEPTH))):
    for _ in range(num_samples):
        yield 1 # getrandbits(width)

def gen_data_in(num_samples=NUM_SAMPLES, width=G_DAT_N_COL*G_DAT_COL_W):
    for _ in range(num_samples):
        yield getrandbits(width)


ram_handle = RamTester()
ram_model = ram_handle.model

data_out = 0


# Apply stimulus
for i, (EN, WE, AD, DI) in enumerate(zip(gen_en(), gen_we(), gen_adr(), gen_data_in())):

    data_out = ram_model(
        en=EN, 
        we=WE,
        adr=AD,
        dat_in=DI)

    print(i, ":   Data Out : ", data_out)
    
