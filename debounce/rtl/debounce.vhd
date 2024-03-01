-- #############################################################################
-- #  << Debounce >>
-- # ===========================================================================
-- # File     : debounce.vhd
-- # Author   : David Gussler
-- # Language : VHDL '08
-- # ===========================================================================
-- # BSD 2-Clause License
-- # 
-- # Copyright (c) 2023-2024, David Gussler. All rights reserved.
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
-- # Ensures that an input is stable for COUNT_G clockcycles before
-- # transitioning the output. 
-- #############################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity debounce is
  generic (
    G_RST_VAL : std_logic := '0'; 
    G_COUNT : positive := 16
  );
  port (
    clk_i : in std_logic;
    srst_i : in std_logic;
    in_i : in std_logic;
    out_o : out std_logic
  );
end entity;

architecture rtl of debounce is
  signal samples : std_logic_vector(1 downto 0);
  signal cnt : integer range 0 to G_COUNT-1; 
begin
  prc_debounce : process (clk_i)
  begin
    if rising_edge(clk_i) then
      samples <= samples(0) & in_i;
      if xor samples then 
        cnt <= 0;
      elsif cnt < G_COUNT-1 then
        cnt <= cnt + 1;
      else 
        out_o <= samples(0);
      end if; 
      if srst_i then
        out_o <= G_RST_VAL;
        cnt <= 0;
      end if; 
    end if;
  end process;
end architecture;
