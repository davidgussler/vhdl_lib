-- #############################################################################
-- # File     : bit_sync.vhd
-- # Author   : David Gussler
-- # Language : VHDL '08
-- # ===========================================================================
-- # Simple bit synchronizer. This can also be used to sync one bit or several 
-- # unrelated bits to a common clock.  
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

use work.gen_types_pkg.all;

entity bit_sync is
  generic (
    G_SYNC_LEN : positive                               := 1;
    G_WIDTH    : positive                               := 1;
    G_RST_VAL  : std_logic_vector(G_WIDTH - 1 downto 0) := (others => '0')
  );
  port (
    clk_i   : in std_logic;
    srst_i  : in std_logic := '0';
    async_i : in std_logic_vector(G_WIDTH - 1 downto 0);
    sync_o  : out std_logic_vector(G_WIDTH - 1 downto 0)
  );
end entity;

architecture rtl of bit_sync is

  type sr_t is array (natural range 0 to G_SYNC_LEN) of
  std_logic_vector(async_i'length - 1 downto 0);
  signal sr : sr_t := (others => G_RST_VAL);

  -- Xilinx Attributes
  attribute ASYNC_REG       : string;
  attribute ASYNC_REG of sr : signal is "TRUE";

  attribute SHREG_EXTRACT       : string;
  attribute SHREG_EXTRACT of sr : signal is "NO";

begin

  prc_bit_sync : process (clk_i)
  begin
    if rising_edge(clk_i) then
      sr(0) <= async_i; 
      for i in 1 to G_SYNC_LEN loop
        sr(i) <= sr(i-1);
      end loop;
      
      if srst_i then
        sr <= (others => G_RST_VAL);
      end if;
    end if;
  end process;

  sync_o <= sr(G_SYNC_LEN);

end architecture;