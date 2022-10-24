library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity debounce is
   generic (
      N_CLKS : integer := 100; -- number of clocks to wait before declairing the input as stable
      ACT_LVL : std_logic := '1' -- 1 for active high 
   );
   port (
      i_clk   : in std_logic;
      i_srst  : in std_logic;

      i_button : in std_logic; 
      o_debounced : out std_logic; 
   );
end entity;

architecture rtl of debounce is
   constant RST_LVL := not ACT_LVL; 
   signal synced : std_logic;
   signal count : integer range 0 to N_CLKS-1; 
   signal debounced : std_logic := RST_LVL;
begin
   o_debounced <= debounced; 
   
   u_sync_bit : sync_bit 
   generic map (
      N_FLOPS => 2,
      ACT_LVL => ACT_LVL
   )
   port map (
      i_clk  => i_clk,
      i_srst => i_srst,
      i_bit  => i_button,
      o_bit  => synced
   );

   -- debounce process 
   process (i_clk)
   begin
      if rising_edge(i_clk) then
         if (i_srst = '1') then
            count <= 0;
            debounced <= RST_LVL; 
         else
            if (count < N_CLKS-1) then
               count <= count + 1; 
            elsif (synced /= debounced) then
               counter <= 0;
               debounced <= synced; 
            end if; 
         end if;
      end if;
   end process; 
end architecture;