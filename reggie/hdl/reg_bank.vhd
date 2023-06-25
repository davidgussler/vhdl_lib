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
-- # Three types of registers are supported. 
-- #   * RW (Read / Write)
-- #       Written (or read) by software, read by firmware
-- #       Read by firmware with "o_ctl"
-- #       "o_rd" and "o_wr" are pulsed when software reads or writes
-- #   * RO (Read Only)
-- #       Read by software, written by firmware
-- #       Written by firmware with "i_sts"
-- #       "o_rd" is pulsed on a software read
-- #       "o_wr" is never pulsed
-- #   * RWV (Read Write Volatile)
-- #       This is a bit like a RW and RO register combined
-- #       Written by software / firmware and read by software / firmware
-- #       This means that the value written by software by not necessarilly 
-- #       be the same value that is read by software (the RW register
-- #       guarentees that FW will not modify the value written by SW, the RWV
-- #       does not guarentee this)
-- #       Software writes are read by firmware with "o_ctl"
-- #       Software reads are written by firmware with "i_sts"
-- #       "o_rd" and "o_wr" are pulsed when software reads or writes
-- #       To reiterate how this works, if firmware connects "o_ctl" to "i_sts"
-- #       then this type of register would act just like a RW register.
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
        G_ADR_BITS : positive range 2 to 32 := 8;

        -- Address of each register
        G_REG_ADR : slv_array_t(G_NUM_REGS-1 downto 0)(G_ADR_BITS-1 downto 0);

        -- TODO: Get rid of RW and RO... Make ALL registers RWV...
        -- Then the user can decide which type of register to use with external logic
        -- Will simplify this design and allow more upstream flexibility.
        -- 0: RW  (Read Write)          - Control register
        -- 1: RO  (Read Only)           - Status register
        -- 2: RWV (Read Write Volatile) - Control / Status register
        G_REG_TYPE : int_array_t(G_NUM_REGS-1 downto 0);

        -- Reset value for all of the RW and RWV registers. STS registers do not 
        -- have a reset value becasue they are dependent on user logic and IRQ 
        -- registers always reset to 0. 
        G_REG_RST_VAL : slv_array_t(G_NUM_REGS-1 downto 0)(31 downto 0)
    );
    port(
        i_clk : in std_logic;
        i_rst : in std_logic;

        -- Simple Bus Slave Interface
        i_s_bus : in  bus_req_t; 
        o_s_bus : out bus_resp_t;

        -- Register Interface
        o_ctl : out slv_array_t(G_NUM_REGS-1 downto 0)(31 downto 0);
        i_sts : in  slv_array_t(G_NUM_REGS-1 downto 0)(31 downto 0);

        -- Register R/W Indication Interface
        o_wr : out std_logic_vector(G_NUM_REGS-1 downto 0);
        o_rd : out std_logic_vector(G_NUM_REGS-1 downto 0)
    );
end entity;


architecture rtl of reg_bank is 
    constant RW_REG : integer := 0;
    constant RO_REG : integer := 1;

    signal bus_wr : std_logic_vector(G_NUM_REGS-1 downto 0);
    signal bus_rd : std_logic_vector(G_NUM_REGS-1 downto 0);

begin

    gen_regs : for i in 0 to G_NUM_REGS-1 generate

        -- Legal write transaction
        bus_wr(i) <= '1' when i_s_bus.wen = '1' and 
            i_s_bus.waddr(G_ADR_BITS-1 downto 0) = G_REG_ADR(i) and 
            G_REG_TYPE(i) = RW_REG 
            else '0';
                
        -- Legal read transaction
        bus_rd(i) <= '1' when i_s_bus.ren = '1' and 
            i_s_bus.raddr(G_ADR_BITS-1 downto 0) = G_REG_ADR(i) 
            else '0';
        
        -- Read / write indication pulses
        process (i_clk) begin
            if rising_edge(i_clk) then
                if i_rst then
                    o_rd(i) <= '0';
                    o_wr(i) <= '0';
                else
                    if bus_wr(i) then
                        o_wr(i) <= '1';
                    else 
                        o_wr(i) <= '0';
                    end if; 

                    if bus_rd(i) then
                        o_rd(i) <= '1';
                    else
                        o_rd(i) <= '0';
                    end if; 
                end if; 
            end if;
        end process;
        
        -- Bus writes
        process (i_clk) begin
            if rising_edge(i_clk) then
                if i_rst then
                    o_ctl(i) <= G_REG_RST_VAL(i); 
                else
                    if bus_wr(i) then
                        o_ctl(i) <= i_s_bus.wdata; 
                    end if; 
                end if; 
            end if;
        end process;
    end generate;


    -- Bus reads
    process (i_clk) begin
        if rising_edge(i_clk) then
            for i in 0 to G_NUM_REGS-1 loop
                if bus_rd(i) then
                    if G_REG_TYPE(i) = RW_REG then
                        o_s_bus.rdata <= o_ctl(i);
                    else 
                        o_s_bus.rdata <= i_sts(i); 
                    end if;
                end if; 
            end loop;
        end if;
    end process;

end architecture;