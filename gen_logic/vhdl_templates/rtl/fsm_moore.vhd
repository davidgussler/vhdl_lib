-- ###############################################################################################
-- # << Moore FSM Template >> #
-- *********************************************************************************************** 
-- Copyright 2022
-- *********************************************************************************************** 
-- File     : fsm_moore.vhd
-- Author   : David Gussler - davidnguss@gmail.com 
-- Language : VHDL '08
-- History  :  Date      | Version | Comments 
--            --------------------------------
--            12-18-2021 | 1.0     | Initial 
-- *********************************************************************************************** 
-- Description : 
--     This a a template file for a FSM. Although this style of an FSM is more verbose than others
--     it provies numerous advantages:
--     * All of the outputs are registered
--     * It provides the designer more control
--     * Unlike the one process FSM, it closely models a traditional Moore model diagram becasue 
--       outputs are not delayed one cycle from the current state 
--     * the disadvantage of this style is that no combinational outputs are allowed, ie 
--       this is a full fledged moore machine. outputs are only a product of current state
--       They cannot change combinationally with changing inputs. 
-- Generics
--     * g_GEN1 => This generic controlls a thing
--     * g_GEN2 => This generic controlls another thing
-- ###############################################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.gen_utils_pkg.all;

entity fsm_moore is 
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
end fsm_moore;

architecture rtl of fsm_moore is 
   type t_state is (s_IDLE, s_1, s_2);
   signal r_state : t_state := s_IDLE;
   signal nxt_state : t_state;

   signal sig2 : std_logic;
   signal dat2 : std_logic_vector(7 downto 0);
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
   -- Next State
   -- --------------------------------------------------------------------------------------------
   comb_process : process (r_state, i_sig1, i_dat1) begin 
      -- Defualts
      nxt_state <= r_state;

      case r_state is
      when s_IDLE =>
         if (i_sig1 = '1' and i_dat1 = X"71") then
            nxt_state <= s_1; 
         end if;
      when s_1 =>
         if (i_sig1 = '1') then
            nxt_state <= s_2; 
         end if;
      when s_2 =>
         if (i_sig1 = '1') then
            nxt_state <= s_IDLE;
         end if;
      end case;
   end process;   

   -- --------------------------------------------------------------------------------------------
   -- Registered outputs based on next state
   -- --------------------------------------------------------------------------------------------
   outputs : process (i_clk) begin
      if (rising_edge(i_clk)) then
         if (i_rst = '1') then
            sig2 <= '0';
            dat2 <= (others=>'0');
         else
            case nxt_state is
            when s_IDLE =>
               sig2 <= '0'; 
               dat2 <= (others=>'1');
            when s_1 =>
               sig2 <= '1';  
               dat2 <= (others=>'0');
            when s_2 =>
               sig2 <= '1'; 
               dat2 <= (others=>'1');
            end case;
         end if;
      end if; 
   end process;   

   -- --------------------------------------------------------------------------------------------
   -- Assign output ports
   -- --------------------------------------------------------------------------------------------
   o_sig2 <= sig2;
   o_dat2 <= dat2;


end architecture rtl;



