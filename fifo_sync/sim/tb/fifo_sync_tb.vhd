-- ###############################################################################################
-- # << FIFO Testbench >> #
-- *********************************************************************************************** 
-- Copyright David N. Gussler 2022
-- *********************************************************************************************** 
-- File     : ram_sp_tb.vhd
-- Author   : David Gussler - davidnguss@gmail.com 
-- Language : VHDL '08
-- History  :  Date      | Version | Comments 
--            --------------------------------
--            07-05-2022 | 1.0     | Initial 
-- *********************************************************************************************** 
-- Description : 
--     Simple Testbench for FIFO module 
-- 
-- ###############################################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

entity fifo_sync_tb is
end entity fifo_sync_tb;

architecture bench of fifo_sync_tb is
   ----------------------------------------------------------------------------
   -- TB level signals 
   ----------------------------------------------------------------------------
   constant CLK_FREQ   : real := 100.0E+6;
   constant CLK_PERIOD : time := (1.0E9 / CLK_FREQ) * 1 NS;
   constant CLK_TO_Q   : time := 1 NS; 

   constant C_WIDTH        : integer := 32; 
   constant C_DEPTH_LOG2   : integer := 4; 
   constant C_ALMOST_FULL  : integer := 2; 
   constant C_ALMOST_EMPTY : integer := 2; 
   constant C_MEM_STYLE    : string := ""; 
   
   signal i_wr           : std_logic := '0';
   signal i_dat          : std_logic_vector(C_WIDTH-1 downto 0) := (others=>'0'); 
   signal o_almost_full  : std_logic;
   signal o_full         : std_logic;
   signal i_rd           : std_logic := '0';
   signal o_dat          : std_logic_vector(C_WIDTH-1 downto 0) := (others=>'0'); 
   signal o_almost_empty : std_logic;
   signal o_empty        : std_logic;

   signal i_clk  : std_logic := '0';

begin
   ----------------------------------------------------------------------------
   -- Instantiate the DUT 
   ----------------------------------------------------------------------------
   dut : entity work.fifo_sync(rtl)
   generic map (
      G_WIDTH        =>  C_WIDTH       ,
      G_DEPTH_LOG2   =>  C_DEPTH_LOG2  ,
      G_ALMOST_FULL  =>  C_ALMOST_FULL ,
      G_ALMOST_EMPTY =>  C_ALMOST_EMPTY,
      G_MEM_STYLE    =>  C_MEM_STYLE
   )
   port map (
         -- Write Port
         i_wr           => i_wr,         
         i_dat          => i_dat,        
         o_almost_full  => o_almost_full,
         o_full         => o_full,      
   
         -- Read Port
         i_rd           => i_rd,          
         o_dat          => o_dat,         
         o_almost_empty => o_almost_empty,
         o_empty        => o_empty,       
   
         i_clk   => i_clk
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
      -- Fill and empty the fifo. also try writing to full and reading from empty
      procedure test_1 is
      begin

         write_loop : for i in 0 to (2 ** C_DEPTH_LOG2) + 5 loop
            wait until rising_edge(i_clk);
            i_wr <= '1'; 
            i_rd <= '0'; 
            i_dat <= std_logic_vector(to_unsigned(i, C_WIDTH));

            wait until rising_edge(i_clk);
            i_wr <= '0'; 
            i_rd <= '0'; 
            i_dat <= (others=>'X');
         end loop;

         read_loop : for i in 0 to (2 ** C_DEPTH_LOG2) + 5 loop
            wait until rising_edge(i_clk);
            i_wr <= '0'; 
            i_rd <= '1'; 
            i_dat <= (others=>'X');
            
            wait until rising_edge(i_clk);
            i_wr <= '0'; 
            i_rd <= '0'; 
            i_dat <= (others=>'X');
         end loop;
         
         wait until rising_edge(i_clk);
         wait until rising_edge(i_clk);
         wait until rising_edge(i_clk);
         wait until rising_edge(i_clk);
         wait until rising_edge(i_clk);

      end procedure;
      
      -- Read and write at the same time 
      procedure test_2 is
      begin
         
         -- Fill it up half way 
         write_loop : for i in 0 to (((2 ** C_DEPTH_LOG2) / 2) - 1) loop
            wait until rising_edge(i_clk);
            i_wr <= '1'; 
            i_rd <= '0'; 
            i_dat <= std_logic_vector(to_unsigned(i, C_WIDTH));
         end loop;

         wait until rising_edge(i_clk);
         i_wr <= '1'; 
         i_rd <= '1'; 
         i_dat <= (others=>'1');
         
         wait until rising_edge(i_clk);
         i_wr <= '0'; 
         i_rd <= '0'; 
         i_dat <= (others=>'X');   

         wait until rising_edge(i_clk);
         wait until rising_edge(i_clk);
         wait until rising_edge(i_clk);
         wait until rising_edge(i_clk);
         wait until rising_edge(i_clk);

      end procedure;


   ----------------------------------------------------------------------------
   -- Call test procedures
   ----------------------------------------------------------------------------
   begin
      test_1;
      test_2;

      wait for CLK_PERIOD * 10;
      assert FALSE
         report "Simulation Ended"
         severity failure;
      wait;
   end process;

end architecture bench;
