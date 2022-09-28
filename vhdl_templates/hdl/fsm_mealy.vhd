-- ###############################################################################################
-- # << Mealy FSM Template >> #
-- *********************************************************************************************** 
-- Copyright David N. Gussler 2022
-- *********************************************************************************************** 
-- File     : fsm1.vhd
-- Author   : David Gussler - davidnguss@gmail.com 
-- Language : VHDL '08
-- History  :  Date      | Version | Comments 
--            --------------------------------
--            12-18-2021 | 1.0     | Initial 
-- *********************************************************************************************** 
-- Description : 
--     This is a good starting point for a Mealy machine (outputs are a product of current state
--     and current inputs)
--     Although this method is usually fine, I prefer Moore machines where possible for their 
--     greater simplicity to understand and implement in hardware. 
-- Generics
--     * g_GEN1 => This generic controlls a thing
--     * g_GEN2 => This generic controlls another thing
-- ###############################################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.gen_utils_pkg.all;

entity fsm_mealy is 
   generic(
      g_GEN1 : integer range 0 to 9 := 1;
      g_GEN2 : integer range 0 to 9 := 2
   );
   port(
      o_sig2: out std_logic;
      o_dat2: out std_logic_vector(7 downto 0);
      i_sig1: in std_logic;
      i_dat1: in std_logic_vector(7 downto 0);

      i_rst : in std_logic;
      i_clk : in std_logic
      );
end fsm_mealy;

architecture rtl of fsm_mealy is 
   type t_state is (s_IDLE, s_1, s_2);
   signal r_state : t_state := s_IDLE;
   signal nxt_state : t_state;
begin
   -- --------------------------------------------------------------------------------------------
   -- Next State Register
   -- --------------------------------------------------------------------------------------------
   nxt_state_reg : process (i_clk) begin 
      if (rising_edge(i_clk)) then
         if (i_rst = '1') then
            r_state <= s_IDLE;
         else
            r_state <= nxt_state;
         end if;
      end if;   
   end process;

   -- --------------------------------------------------------------------------------------------
   -- Next State and Output Logic
   -- --------------------------------------------------------------------------------------------
   comb_process : process (r_state, i_sig1, i_dat1) begin 
      -- Defualts
      nxt_state <= r_state;
      o_sig2 <= '0';
      o_dat2 <= (others=>'0');

      case r_state is
      when s_IDLE =>
         -- moore outputs 
         o_sig2 <= '0'; 
         o_dat2 <= (others=>'1');
         if (i_sig1 = '1' and i_dat1 = X"71") then
            nxt_state <= s_1; 
            -- mealy outputs here
            --
         end if;
      when s_1 =>
         o_sig2 <= '1';  
         o_dat2 <= (others=>'0');
         if (i_sig1 = '1') then
            nxt_state <= s_2; 
         end if;
      when s_2 =>
         o_sig2 <= '1'; 
         o_dat2 <= (others=>'1');
         if (i_sig1 = '1') then
            nxt_state <= s_IDLE;
         end if;
      end case;
   end process;   
end architecture rtl;



