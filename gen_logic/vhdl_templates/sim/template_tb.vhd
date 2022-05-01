-- ###############################################################################################
-- # << Template Testbench >> #
-- *********************************************************************************************** 
-- Copyright 2022
-- *********************************************************************************************** 
-- File     : template_tb.vhd
-- Author   : David Gussler - davidnguss@gmail.com 
-- Language : VHDL '08
-- History  :  Date      | Version | Comments 
--            --------------------------------
--            12-18-2021 | 1.0     | Initial 
-- *********************************************************************************************** 
-- Description : 
--     Useful description describing the description to describe the module
-- ###############################################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library std;
use std.textio.all;

entity template_tb is
end entity template_tb;

architecture bench of template_tb is
   ----------------------------------------------------------------------------
   -- TB level signals 
   ----------------------------------------------------------------------------
   constant CLK_FREQ   : real := 100.0E+6;
   constant CLK_PERIOD : time := (1.0E9 / CLK_FREQ) * 1 NS;
   constant CLK_TO_Q   : time := 1 NS; 

   signal i_clk  : std_logic := '0';
   signal i_rst : std_logic := '1';

   signal i_sig1 : std_logic;
   signal o_sig2 : std_logic;
   signal i_dat1 : std_logic_vector(7 downto 0);
   signal o_dat2 : std_logic_vector(7 downto 0);

begin
   ----------------------------------------------------------------------------
   -- Instantiate the DUT 
   ----------------------------------------------------------------------------
   dut : entity work.template(rtl)
   port map (
      i_sig1 => i_sig1,
      o_sig2 => o_sig2,
      i_dat1 => i_dat1,
      o_dat2 => o_dat2,

      i_rst => i_rst, 
      i_clk  => i_clk
   );

   ----------------------------------------------------------------------------
   -- Generate the clock
   ----------------------------------------------------------------------------
   clk_process : process 
   begin
      i_clk <= '1';
      wait for CLK_PERIOD / 2;
      i_clk <= '0';
      wait for CLK_PERIOD / 2;
   end process;


   stim_process: process
      ----------------------------------------------------------------------------
      -- Reset procedure
      ----------------------------------------------------------------------------
      procedure reset_procedure is
      begin
         wait until falling_edge(i_clk);
         i_rst <= '1';
         wait for CLK_PERIOD * 10;
         i_rst <= '0';
      end procedure;

      ----------------------------------------------------------------------------
      -- Define test procedures
      ----------------------------------------------------------------------------
      procedure test_1 is
      begin
         wait until rising_edge(i_clk);
         wait for CLK_TO_Q; 
         i_dat1 <= "10101010";
         i_sig1 <= '1';
      end procedure;


   ----------------------------------------------------------------------------
   -- Call test procedures
   ----------------------------------------------------------------------------
   begin

      reset_procedure;
      test_1;

      wait for CLK_PERIOD * 10;
      assert FALSE
         report "Simulation Ended"
         severity failure;
      wait;
   end process;

end architecture bench;
