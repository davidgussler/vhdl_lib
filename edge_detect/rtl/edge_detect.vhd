-- #############################################################################
-- # File     : edge_detect.vhd
-- # Author   : David Gussler
-- # Language : VHDL '08
-- # ===========================================================================
-- # Edge detector. Pulses for one clockcycle on a positive edge, negative edge, 
-- # or both.
-- # ===========================================================================
-- # Copyright (c) 2023-2024, David Gussler. All rights reserved.
-- # You may use, distribute and modify this code under the
-- # terms of the BSD 2-Clause license. You should have received a copy of the 
-- # license with this file. If not, please message: davndnguss@gmail.com. 
-- #############################################################################

library ieee;
use ieee.std_logic_1164.all;

entity edge_detect is
  port (
    clk_i  : in std_logic;
    srst_i : in std_logic := '0';
    in_i   : in std_logic;
    rise_o : out std_logic;
    fall_o : out std_logic;
    both_o : out std_logic
  );
end entity;

architecture rtl of edge_detect is
  signal in_ff : std_logic;
begin

  prc_ff : process (clk_i)
  begin
    if rising_edge(clk_i) then
      if srst_i then
        in_ff <= '0';
      else
        in_ff <= in_i;
      end if;
    end if;
  end process;

  rise_o <= not in_ff and in_i;
  fall_o <= in_ff and not in_i;
  both_o <= in_ff xor in_i;

end architecture;