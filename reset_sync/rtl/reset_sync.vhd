-- #############################################################################
-- # File     : reset_sync.vhd
-- # Author   : David Gussler
-- # Language : VHDL '08
-- # ===========================================================================
-- # Reset synchronizer
-- # ===========================================================================
-- # Copyright (c) 2023-2024, David Gussler. All rights reserved.
-- #
-- # You may use, distribute and modify this code under the
-- # terms of the BSD 2-Clause license. You should have received a copy of the 
-- # license with this file. If not, please message: davndnguss@gmail.com. 
-- #############################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity reset_sync is
  generic (
    G_SYNC_LEN : positive  := 1;
    G_ARST_LVL : std_logic := '1';
    G_SRST_LVL : std_logic := '1'
  );
  port (
    clk_i  : in std_logic;
    arst_i : in std_logic;
    srst_o : out std_logic
  );
end entity;

architecture rtl of reset_sync is

  signal sr : std_logic_vector(G_SYNC_LEN downto 0) := (others => G_SRST_LVL);

  attribute ASYNC_REG       : string;
  attribute ASYNC_REG of sr : signal is "TRUE";

  attribute SHREG_EXTRACT       : string;
  attribute SHREG_EXTRACT of sr : signal is "NO";

begin

  prc_reset_sync : process (clk_i, arst_i)
  begin
    if arst_i = G_ARST_LVL then
      sr <= (others => G_SRST_LVL);
    elsif rising_edge(clk_i) then
      sr <= sr(G_SYNC_LEN - 1 downto 0) & not G_SRST_LVL;
    end if;
  end process;

  srst_o <= sr(G_SYNC_LEN);

end architecture;