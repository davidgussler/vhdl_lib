-- #############################################################################
-- #  << CPU to Wishbone Interface >>
-- # ===========================================================================
-- # File     : rv32_wb_if.vhd
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
-- # Bridge for CPU memory bus master transactions to wishbone bus master
-- # transactions. This is simplified for this CPU. Since we know that the 
-- # master CPU will only ever initiate one outstanding memory request at a time,
-- # we can ignore the stall signal. This makes life much simpler. 
-- # We must latch the read data to guarentee that it valid till the next 
-- # read data comes in. Since this interface is for external memory, it is okay
-- # to take a few cycles because these are likely slow IO peripherals. 
-- # 
-- #############################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.gen_utils_pkg.all;

entity rv32_wb_if is
    port (
        -- Clock & Reset
        i_clk      : in std_logic;
        i_rst      : in std_logic;

        -- Slave Port (Internal Bus Interface)
        i_s_ren      : in  std_logic;
        i_s_wen      : in  std_logic;
        i_s_ben      : in  std_logic_vector(3 downto 0); 
        i_s_addr     : in  std_logic_vector(31 downto 0);
        i_s_wdat     : in  std_logic_vector(31 downto 0);
        o_s_rdat     : out std_logic_vector(31 downto 0);
        o_s_ack      : out std_logic; 
        o_s_err      : out std_logic;
        
        -- Master Port (Wishbone Interface)
        o_wbm_cyc  : out std_logic;
        o_wbm_stb  : out std_logic;
        o_wbm_adr  : out std_logic_vector(31 downto 0);
        o_wbm_wen  : out std_logic;
        o_wbm_sel  : out std_logic_vector(3 downto 0);
        o_wbm_wdat : out std_logic_vector(31 downto 0);
        i_wbm_stl  : in std_logic; 
        i_wbm_ack  : in std_logic;
        i_wbm_err  : in std_logic;
        i_wbm_rdat : in std_logic_vector(31 downto 0)     
    );
end entity rv32_wb_if;

architecture rtl of rv32_wb_if is

    signal request  : std_logic;
    signal response : std_logic;

begin
    request  <= i_s_ren or i_s_wen; 
    response <= i_wbm_ack or i_wbm_err; 

    -- Request -----------------------------------------------------------------
    -- -------------------------------------------------------------------------
    sp_cyc : process (i_clk) begin
        if rising_edge(i_clk) then
            if (i_rst) then
                o_wbm_cyc <= '0';
            else
                if (request) then
                    o_wbm_cyc  <= '1';
                elsif (response and not o_wbm_stb) then
                    o_wbm_cyc  <= '0';
                end if; 
            end if;
        end if;
    end process;

    sp_stb : process (i_clk) begin
        if rising_edge(i_clk) then
            if (i_rst) then
                o_wbm_stb <= '0';
            else
                if (request) then
                    o_wbm_stb  <= '1';
                elsif (o_wbm_stb and i_wbm_stl) then
                    o_wbm_stb  <= '1';
                else 
                    o_wbm_stb  <= '0';  
                end if; 
            end if;
        end if;
    end process;

    sp_data : process (i_clk) begin
        if rising_edge(i_clk) then
            if (request) then
                o_wbm_wen  <= i_s_wen; 
                o_wbm_adr  <= i_s_addr; 
                o_wbm_sel  <= i_s_ben; 
                o_wbm_wdat <= i_s_wdat; 
            end if;                 
        end if;
    end process;

    
    -- Response ----------------------------------------------------------------
    -- -------------------------------------------------------------------------
    sp_resp : process (i_clk) begin
        if rising_edge(i_clk) then
            if (i_rst) then
                o_s_ack  <= '0';
                o_s_err  <= '0';
                o_s_rdat <= (others=>'-');
            else 
                o_s_ack  <= i_wbm_ack;
                o_s_err  <= i_wbm_err; 
                o_s_rdat <= i_wbm_rdat;
            end if; 
        end if;
    end process;  

end architecture;
