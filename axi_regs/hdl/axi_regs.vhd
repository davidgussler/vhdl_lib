-- #############################################################################
-- #  << AXI4 Lite Register Bank >>
-- # ===========================================================================
-- # File     : axi_regs.vhd
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
-- #############################################################################

-- AXI Notes:
-- 



library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.gen_utils_pkg.all;

entity axi_regs is 
    generic(
        -- Number of registers in the bank
        G_NUM_REGS : positive := 16;

        -- Number of address bits to allocate for this register bank
        G_NUM_ADR_BITS : positive := 4;

        -- Address offset for each register in the array. 
        G_REG_ADR : slv_array_t(G_NUM_REGS-1 downto 0)(G_NUM_ADR_BITS-1 downto 0);

        -- 0: CTL - Control register (RW)
        -- 1: STS - Status register (RO)
        -- 2: IRQ - Interrupt register (RW1C)
        G_REG_TYPE : int_array_t(G_NUM_REGS-1 downto 0);

        -- Reset value for all of the RW registers. CTL and IRQ registers do not have a 
        -- reset value. 
        G_REG_RST_VAL : slv_array_t(G_NUM_REGS-1 downto 0)(31 downto 0)
    );
    port(
        i_clk : in std_logic;
        i_rst : in std_logic;

        -- AXI4-Lite Slave Interface
        i_s_axi : in  axil_req_t; 
        o_s_axi : out axil_resp_t;

        -- Register Interface
        o_ctl : out slv_array_t(G_NUM_REGS-1 downto 0)(31 downto 0);
        i_sts : in  slv_array_t(G_NUM_REGS-1 downto 0)(31 downto 0);
        i_irq : in  slv_array_t(G_NUM_REGS-1 downto 0)(31 downto 0);

        -- Register R/W Indication Interface
        o_rd_pulse : out std_logic_vector(G_NUM_REGS-1 downto 0);
        o_wr_pulse : out std_logic_vector(G_NUM_REGS-1 downto 0)
    );
end entity;


architecture rtl of axi_regs is 



begin
    o_s_axi.awready <= '1'; 
    wready
    arready


end architecture;