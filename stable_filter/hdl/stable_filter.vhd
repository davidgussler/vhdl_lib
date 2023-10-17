-- #############################################################################
-- #  << Stable Filter >>
-- # ===========================================================================
-- # File     : stable_filter.vhd
-- # Author   : David Gussler - davidnguss@gmail.com
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
-- # Ensures that an input is stable for a given number of clockcycles before
-- # transitioning the filtered output.
-- #############################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity stable_filter is
    generic (
        G_RST_VAL : std_logic := '0'; 
        G_COUNT : positive := 16
    );
    port (
        i_clk : in std_logic;
        i_rst : in std_logic;
        
        i_in : in std_logic;
        o_out : out std_logic
    );
end entity;

architecture rtl of stable_filter is

    signal samples : std_logic_vector(1 downto 0);
    signal cnt : integer range 0 to G_COUNT - 1; 

begin
    process (i_clk) is 
    begin
        if rising_edge(i_clk) then
            if (i_rst) then
                o_out <= G_RST_VAL;
                cnt <= 0;
            else
                samples <= i_in & samples(1);
                if (xor samples) then 
                    cnt <= 0;
                elsif (cnt < G_COUNT-1) then
                    cnt <= cnt + 1;
                else 
                    o_out <= samples(0);
                end if; 
            end if;
        end if;
    end process;
end architecture;