-- #############################################################################
-- #  << Register Bank >>
-- # ===========================================================================
-- # File     : reg_bank.vhd
-- # Author   : David Gussler - david.gussler@proton.me
-- # Language : VHDL '08
-- # ===========================================================================
-- # BSD 2-Clause License
-- # 
-- # Copyright (c) 2023, David Gussler. All rights reserved.
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
-- # 
-- # Array of registers connected to a generic bus interface. The generic bus 
-- # expects a response the cycle after the request. Supports reads and writes 
-- # at the same time. Data width is always 32 bits, but unused data bits 
-- # in a register can be left disconnected on the user-logic side and will be 
-- # optomized away by the synthesis tool.
-- # This module was designed for simplicity and ease of use. 
-- # 
-- # All registers are of the type RWV (Read Write Volatile)
-- # This is a bit like a RW and RO register combined
-- # Written by software / firmware and read by software / firmware
-- # This means that the value written by software by not necessarilly 
-- # be the same value that is read by software.
-- # Software writes are read by firmware with "o_ctl"
-- # Software reads are written by firmware with "i_sts"
-- # "o_rd" and "o_wr" are pulsed when software reads or writes
-- # To reiterate how this works, if firmware connects "o_ctl" to "i_sts"
-- # then this type of register would act just like a RW register.
-- #
-- # This module can be used standalone, but it is intended to be used with a 
-- # wrapper (preferablly generated by the reggie tool). It is at the level 
-- # of the wrapper where the user decides which registers are RO, RW, RWV
-- # or any other type of register that has not been thought of yet. It is also 
-- # at the wrapper level where the user could rename fields from o_ctl and i_sts
-- # for more user-friendly and understandable names. This is also intended to 
-- # be done by the reggie tool. 
-- # 
-- #############################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.gen_utils_pkg.all;

entity reg_bank is 
    generic(
        -- Number of registers in the bank
        G_NUM_REGS : positive := 16;

        -- Number of address bits to use
        G_ADDR_BITS : positive range 2 to 32 := 8;

        -- Address of each register
        G_ADDRS : slv_array_t(G_NUM_REGS-1 downto 0)(G_ADDR_BITS-1 downto 0);

        -- Register reset values
        G_RST_VALS : slv_array_t(G_NUM_REGS-1 downto 0)(31 downto 0)
    );
    port(
        i_clk : in std_logic;
        i_rst : in std_logic;

        -- Simple Bus Slave Interface
        i_s_bus : in  bus_req_t; 
        o_s_bus : out bus_resp_t;

        -- Register Interface
        o_ctl : out slv_array_t(G_NUM_REGS-1 downto 0)(31 downto 0);
        i_sts : in  slv_array_t(G_NUM_REGS-1 downto 0)(31 downto 0) := (others=>(others=>'0'));

        -- Register R/W Indication Interface
        o_wr : out std_logic_vector(G_NUM_REGS-1 downto 0);
        o_rd : out std_logic_vector(G_NUM_REGS-1 downto 0)
    );
end entity;


architecture rtl of reg_bank is 

    signal bus_wr : std_logic_vector(G_NUM_REGS-1 downto 0);
    signal bus_rd : std_logic_vector(G_NUM_REGS-1 downto 0);

begin

    gen_regs : for i in 0 to G_NUM_REGS-1 generate

        -- Legal write transaction
        bus_wr(i) <= '1' when i_s_bus.wen = '1' and 
            i_s_bus.waddr(G_ADDR_BITS-1 downto 0) = G_ADDRS(i)
            else '0';
                
        -- Legal read transaction
        bus_rd(i) <= '1' when i_s_bus.ren = '1' and 
            i_s_bus.raddr(G_ADDR_BITS-1 downto 0) = G_ADDRS(i) 
            else '0';
        
        -- Bus writes
        process (i_clk) begin
            if rising_edge(i_clk) then
                if i_rst then
                    o_ctl(i) <= G_RST_VALS(i); 
                elsif bus_wr(i) then
                    o_ctl(i) <= i_s_bus.wdata; 
                end if; 
            end if;
        end process;

    end generate;


    -- Bus reads
    process (i_clk) begin
        if rising_edge(i_clk) then
            for i in 0 to G_NUM_REGS-1 loop
                if bus_rd(i) then
                    o_s_bus.rdata <= i_sts(i); 
                end if; 
            end loop;
        end if;
    end process;


    -- Read / write indication pulses
    process (i_clk) begin
        if rising_edge(i_clk) then
            if i_rst then
                o_rd <= (others=>'0');
                o_wr <= (others=>'0');
            else
                o_wr <= bus_wr;
                o_rd <= bus_rd;
            end if; 
        end if;
    end process;

end architecture;
