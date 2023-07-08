-- #############################################################################
-- #  << General VHDL Utilities >>
-- # ===========================================================================
-- # File     : gen_utils_pkg.vhd
-- # Author   : David Gussler - david.gussler@proton.me
-- # Language : VHDL '08
-- # ===========================================================================
-- # BSD 2-Clause License
-- # 
-- # Copyright (c) 2022, David Gussler. All rights reserved.
-- # 
-- # Redistribution and use in source and binary forms, with or without
-- # modification, are permitted provided that the following conditions are met:
-- # 
-- # 1. Redistributions of source code must retain the above copyright notice,
-- #     this list of conditions and the following disclaimer.
-- # 
-- # 2. Redistributions in binary form must reproduce the above copyright 
-- #    notice, this list of conditions and the following disclaimer in the 
-- #    documentation and/or other materials provided with the distribution.
-- # 
-- # THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
-- # AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
-- # IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE 
-- # ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE 
-- # LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
-- # CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF 
-- # SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS 
-- # INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN 
-- # CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) 
-- # ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
-- #  POSSIBILITY OF SUCH DAMAGE.
-- # ===========================================================================
-- # VHDL utility functions and types common accross most modules in vhdl_lib.
-- #
-- #############################################################################

library ieee;
use ieee.std_logic_1164.all;

package gen_utils_pkg is

    -- Types ===================================================================
    -- =========================================================================
    type slv_array_t is array (natural range <>) of std_logic_vector;
    type int_array_t is array (natural range <>) of integer;
    type bool_array_t is array (natural range <>) of boolean;

    type regtype_t is (RW_REG, RO_REG);
    type regtype_array_t is array (natural range <>) of regtype_t;

    type uart_parity_t is (NO_PARITY, EVEN_PARITY, ODD_PARITY); 

    -- Interfaces ==============================================================
    -- =========================================================================
    type axil_req_t is record 
        awvalid : std_logic;
        awaddr  : std_logic_vector(31 downto 0);
        awprot  : std_logic_vector(2 downto 0);
        wvalid  : std_logic;
        wdata   : std_logic_vector(31 downto 0);
        wstrb   : std_logic_vector(3 downto 0);
        bready  : std_logic;
        arvalid : std_logic;
        araddr  : std_logic_vector(31 downto 0);
        arprot  : std_logic_vector(2 downto 0);
        rready  : std_logic;
    end record;

    type axil_resp_t is record 
        awready : std_logic;
        wready  : std_logic;
        bvalid  : std_logic;
        bresp   : std_logic_vector(1 downto 0);
        arready : std_logic;
        rvalid  : std_logic;
        rdata   : std_logic_vector(31 downto 0);
        rresp   : std_logic_vector(1 downto 0);
    end record;

    type axil_req_array_t is array (natural range <>) of axil_req_t;
    type axil_resp_array_t is array (natural range <>) of axil_resp_t;

    constant AXI_RESP_OKAY   : std_logic_vector(1 downto 0) := b"00";
    constant AXI_RESP_EXOKAY : std_logic_vector(1 downto 0) := b"01";
    constant AXI_RESP_SLVERR : std_logic_vector(1 downto 0) := b"10";
    constant AXI_RESP_DECERR : std_logic_vector(1 downto 0) := b"11";

    -- This is a dead-simple bus interface for basic components that don't need 
    -- most of the features offered by busses like axi and wishbone.
    -- Read and write channels can operate independently.
    -- Slave is expected to always respond on the cycle following the request.
    -- No errors, wait states, or write strobes. 
    -- Full duplex communication at 1 transfer per cycle for maximum bandwidth.
    -- Recommended to use this for user logic and connect to an axi adaptor for 
    -- external pipelining and interconnect logic.
    type bus_req_t is record 
        ren   : std_logic;
        raddr : std_logic_vector(31 downto 0);
        wen   : std_logic;
        waddr : std_logic_vector(31 downto 0);
        wdata : std_logic_vector(31 downto 0);
    end record;

    type bus_resp_t is record 
        rdata : std_logic_vector(31 downto 0);
    end record;


    -- Functions ===============================================================
    -- =========================================================================
    function clog2(
        x : positive) 
        return natural;

    function find_max(
        x : int_array_t)
        return integer;
    
    function find_min(
        x : int_array_t)
        return integer;

end package;

package body gen_utils_pkg is

    -- Ceiling of log2 ---------------------------------------------------------
    -- -------------------------------------------------------------------------
    -- Use:      Determine the number of bits necessary to represent an integer
    -- Examples: clog2(1024) = 10
    --           clog2(1023) = 10
    --           clog2(1025) = 11
    -- -------------------------------------------------------------------------
    function clog2 (
        x : positive) 
        return natural 
    is
        variable i : natural;
    begin
        i := 0;  
        while (2**i < x) and i < 31 loop
            i := i + 1;
        end loop;
        return i;
    end function;

    
    -- Find Max ----------------------------------------------------------------
    -- -------------------------------------------------------------------------
    -- Use:      
    -- Examples: 
    -- -------------------------------------------------------------------------
    function find_max(
        x : int_array_t)
        return integer
    is
        variable max : integer := x(0);
    begin
        for i in x'range loop
            if (x(i) > max) then
                max := x(i);
            end if;
        end loop; 
        return max; 
    end function;


    -- Find Min ----------------------------------------------------------------
    -- -------------------------------------------------------------------------
    -- Use: 
    -- Examples: 
    -- -------------------------------------------------------------------------
    function find_min(
        x : int_array_t)
        return integer
    is
        variable min : integer := x(0);
    begin
        for i in x'range loop
            if (x(i) < min) then
                min := x(i);
            end if;
        end loop; 
        return min;
    end function;
   
end package body;
