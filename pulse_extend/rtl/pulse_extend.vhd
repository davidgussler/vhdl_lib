-- #############################################################################
-- #  << Pulse Extend >>
-- # ===========================================================================
-- # File     : pulse_extend.vhd
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
-- # Simple pulse extender. Could also be used to filter a glitchy input, but 
-- # this is different from glitch_filter.vhd because this module would 
-- # immediatly transition the output, whereas glitch_filter would only change 
-- # the output after a given number of stable clocks.
-- #############################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pulse_extend is 
  generic(
        -- '1' -> '1' as input pulse, '1' as output pulse, output resets to '0' 
        -- '0' -> '0' as input pulse, '0' as output pulse, output resets to '1'
           G_POLARITY : std_logic := '1';

        -- Length of the output pulse in clockcycles
           G_COUNT : positive := 4
         );
  port(
        i_clk : in std_logic;
        i_rst : in std_logic;

        i_in : in std_logic;
        o_out : out std_logic
      );
end entity;

architecture rtl of pulse_extend is
  signal cnt : integer range 0 to G_COUNT-1;
begin
  process (i_clk)
  begin
    if rising_edge(i_clk) then
      if i_rst then
        cnt <= 0; 
        o_out <= not G_POLARITY;
      else
        if i_in = G_POLARITY then 
          cnt <= G_COUNT-1; 
          o_out <= G_POLARITY;
        elsif cnt = 0 then
          cnt <= 0;
          o_out <= not G_POLARITY;
        else 
          cnt <= cnt - 1; 
          o_out <= G_POLARITY;
        end if; 
      end if;
    end if;
  end process;
end architecture;
