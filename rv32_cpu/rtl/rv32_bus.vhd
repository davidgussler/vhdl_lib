-- #############################################################################
-- #  << RISC-V Internal Memory Bus >>
-- # ===========================================================================
-- # File     : rv32_bus.vhd
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
-- # One master to any slave memory bus. Main use case is to delegate memory
-- # transactions between the processor-external wishbone interface and the 
-- # internal one-cycle BRAM. So for this use case, two slave ports would
-- # suffice, but it's simple enough to add N slave ports, so I'm doing that for 
-- # possible future use-cases. 
-- # Uses a shared address bus topology. Very simple combinational intercon.
-- # I'm able to keep this so simple becasue we have a guarentee from our CPU
-- # master that only one outstanding x-action will happen at a time.
-- # This IC has no error checking for illegal addresses. It is assumed that 
-- # in almost all cases, the entire 32-bit address space will be utilized here,
-- # so it is not worth adding in extra error-checking logic. Due to this module's
-- # simplicity and combinationoral nature, it is recommended to use as few 
-- # slaves as necessary. 
-- #
-- #############################################################################


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.gen_utils_pkg.all;
use work.rv32_pkg.all;

entity rv32_bus is
    generic (
        G_NS          : positive range 1 to 8 := 2;
        G_S_BASE_ADR  : slv_array_t(0 to G_NS-1)(31 downto 0) := (x"8000_0000", x"0000_0000");
        G_S_ADR_W     : int_array_t(0 to G_NS-1) := (30, 15)
    );
    port (
        -- Clock & Reset
        i_clk       : in  std_logic; 
        i_rst       : in  std_logic; 

        -- Slave Port
        i_s_ren      : in  std_logic;
        i_s_wen      : in  std_logic;
        i_s_ben      : in  std_logic_vector(3 downto 0); 
        i_s_addr     : in  std_logic_vector(31 downto 0);
        i_s_wdat     : in  std_logic_vector(31 downto 0);
        o_s_rdat     : out std_logic_vector(31 downto 0);
        o_s_ack      : out std_logic; 
        o_s_err      : out std_logic;

        -- Master Ports
        o_m_ren      : out std_logic_vector(G_NS-1 downto 0);
        o_m_wen      : out std_logic_vector(G_NS-1 downto 0);
        o_m_ben      : out std_logic_vector(3 downto 0); 
        o_m_addr     : out std_logic_vector(31 downto 0);
        o_m_wdat     : out std_logic_vector(31 downto 0);
        i_m_rdat     : in  slv_array_t(0 to G_NS-1)(31 downto 0);
        i_m_ack      : in  std_logic_vector(G_NS-1 downto 0);
        i_m_err      : in  std_logic_vector(G_NS-1 downto 0)

    );
end entity;

architecture rtl of rv32_bus is

    constant ADR_DECODE_HI : integer := 32;
    constant ADR_DECODE_LO : integer := find_max(G_S_ADR_W); 
    subtype ADR_DECODE_RANGE is integer range ADR_DECODE_HI-1 downto ADR_DECODE_LO+1;

begin

    -- Request -----------------------------------------------------------------
    -- -------------------------------------------------------------------------
    ap_slave_sel : process (all)
    begin
        o_m_ren <= (others=>'0');
        o_m_wen <= (others=>'0');
        for i in 0 to G_NS-1 loop
            if i_s_addr(ADR_DECODE_RANGE) = G_S_BASE_ADR(i)(ADR_DECODE_RANGE) then
                o_m_ren(i) <= i_s_ren; 
                o_m_wen(i) <= i_s_wen; 
            end if; 
        end loop;
    end process; 

    o_m_ben   <= i_s_ben; 
    o_m_addr  <= i_s_addr; 
    o_m_wdat  <= i_s_wdat; 


    -- Response ----------------------------------------------------------------
    -- -------------------------------------------------------------------------
    o_s_ack  <= or i_m_ack; 
    o_s_err  <= or i_m_err; 

    ap_resp_sel : process (all)
    begin
        o_s_rdat <= (others=>'-'); 
        for i in 0 to G_NS-1 loop
            if (i_m_ack(i) or i_m_err(i)) then
                o_s_rdat <= i_m_rdat(i); 
            end if; 
        end loop;
    end process; 

end architecture;
