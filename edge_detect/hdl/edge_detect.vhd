-- #############################################################################
-- #  << Edge Detect >>
-- # ===========================================================================
-- # File     : edge_detect.vhd
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
-- # Simple edge detector. Pulses on a positive edge, negative edge, or both.
-- #############################################################################

library ieee;
use ieee.std_logic_1164.all;

entity edge_detect is 
    generic(
        -- 0 pulses on negative edge
        -- 1 pulses on positive edge
        -- 2 pulses on negative and positive edges 
        G_POLARITY : integer range 0 to 2 := 1; 
    );
    port(
        i_clk : in std_logic;
        i_rst : in std_logic;

        i_in : in std_logic;
        o_out : out std_logic
    );
end entity;


architecture rtl of edge_detect is

    signal in_ff : std_logic; 

begin

    prc_ff : process (i_clk)
    begin
        if rising_edge(i_clk) then
            if i_rst then
                in_ff <= '0';
            else
                in_ff <= i_in;
            end if;
        end if;
    end process;

    gen_polarity : if 0 generate
        o_out <= in_ff and not i_in; 
    elsif 1 generate 
        o_out <= not in_ff and i_in; 
    else generate
        o_out <= in_ff xor i_in; 
    end generate;

end architecture;
