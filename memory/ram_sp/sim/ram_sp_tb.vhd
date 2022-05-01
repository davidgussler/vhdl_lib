-- ###############################################################################################
-- # << Single Port Ram Testbench >> #
-- *********************************************************************************************** 
-- Copyright David N. Gussler 2022
-- *********************************************************************************************** 
-- File     : ram_sp_tb.vhd
-- Author   : David Gussler - davidnguss@gmail.com 
-- Language : VHDL '08
-- History  :  Date      | Version | Comments 
--            --------------------------------
--            12-18-2021 | 1.0     | Initial 
-- *********************************************************************************************** 
-- Description : 
--     Simple Testbench for RAM module 
-- 
-- ###############################################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

use work.mem_utils_pkg.all;

entity ram_sp_tb is
end entity ram_sp_tb;

architecture bench of ram_sp_tb is
   ----------------------------------------------------------------------------
   -- TB level signals 
   ----------------------------------------------------------------------------
   constant CLK_FREQ   : real := 100.0E+6;
   constant CLK_PERIOD : time := (1.0E9 / CLK_FREQ) * 1 NS;
   constant CLK_TO_Q   : time := 1 NS; 

   constant C_DAT_N_COL : integer := 1;
   constant C_DAT_COL_W : integer := 32;
   constant C_DEPTH     : integer := 1024;
   constant C_RD_LATENCY: integer := 1; 
   constant C_RAM_STYLE : string := "auto";
   constant C_INIT_TYPE : string := "generic"; 
   constant C_FILE_NAME : string  := "";
   constant C_MEM_INIT  : t_vector_array (C_DAT_COL_W*C_DAT_N_COL-1 downto 0) (C_DEPTH-1 downto 0) := (others=>(others=>'0'));

   signal i_clk  : std_logic := '0';
   signal i_srst : std_logic := '1';
   
   signal i_en  : std_logic := '0';
   signal i_we  : std_logic_vector(C_DAT_N_COL-1 downto 0) := (others=>'0');
   signal i_adr : std_logic_vector(ceil_log2(C_DEPTH)-1 downto 0);
   signal i_dat : std_logic_vector(C_DAT_N_COL*C_DAT_COL_W-1 downto 0) := (others=>'0');
   signal o_dat : std_logic_vector(C_DAT_N_COL*C_DAT_COL_W-1 downto 0);


begin
   ----------------------------------------------------------------------------
   -- Instantiate the DUT 
   ----------------------------------------------------------------------------
   dut : entity work.ram_sp(rtl)
   generic map (
      G_DAT_N_COL  => C_DAT_N_COL,
      G_DAT_COL_W  => C_DAT_COL_W,
      G_DEPTH      => C_DEPTH    ,
      G_RD_LATENCY => C_RD_LATENCY,
      G_MEM_STYLE  => C_RAM_STYLE
   )
   port map (
      i_en  => i_en ,
      i_we  => i_we ,
      i_adr => i_adr,
      i_dat => i_dat,
      o_dat => o_dat,

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
      -- Define test procedures
      ----------------------------------------------------------------------------
      procedure test_1 is
      begin
         wait until rising_edge(i_clk);
         i_en <= '1'; 
         write_loop : for i in 0 to c_DEPTH-1 loop
            wait until rising_edge(i_clk);
            i_we <= (others=>'1');
            i_adr <= std_logic_vector(to_unsigned(i, ceil_log2(C_DEPTH)));
            i_dat <= std_logic_vector(to_unsigned(i, C_DAT_N_COL*C_DAT_COL_W));
            wait until rising_edge(i_clk);
            i_we  <= (others=>'0');
            i_dat <= (others=>'0');
         end loop;

      end procedure;


   ----------------------------------------------------------------------------
   -- Call test procedures
   ----------------------------------------------------------------------------
   begin
      test_1;

      wait for CLK_PERIOD * 10;
      assert FALSE
         report "Simulation Ended"
         severity failure;
      wait;
   end process;

end architecture bench;
