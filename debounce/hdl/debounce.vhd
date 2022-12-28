library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity debounce is
   generic (
      G_N_CLKS  : integer := 100; -- number of clocks to wait before deciding the input is stable
      G_ACT_LVL : std_logic := '1' -- 1 for active high, 0 for active low
   );
   port (
      i_clk : in std_logic;
      i_rst : in std_logic;

      i_in  : in std_logic; 
      o_out : out std_logic
   );
end entity;

architecture rtl of debounce is
   constant RST_LVL : std_logic := not G_ACT_LVL; 
   signal count : integer range 0 to G_N_CLKS-1; 

begin

   sp_debounce : process (i_clk)
   begin
      if rising_edge(i_clk) then
         if (i_rst) then
            count <= 0;
            o_out <= RST_LVL; 
         else
            if (count < G_N_CLKS-1) then
               count <= count + 1; 
            elsif (i_in /= o_out) then
               count <= 0;
               o_out <= i_in; 
            end if; 
         end if;
      end if;
   end process; 
end architecture;