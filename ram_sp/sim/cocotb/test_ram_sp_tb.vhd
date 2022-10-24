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

use work.gen_utils_pkg.all;

entity test_ram_sp_tb is
   generic(
      G_DAT_N_COL  : integer range 1 to 64 := 4;
      G_DAT_COL_W  : integer range 1 to 64 := 8;
      G_DEPTH      : positive := 1024;
      G_RD_LATENCY : natural range 0 to 16 := 1; 
      G_MEM_STYLE  : string  := "auto";
      G_MEM_INIT   : slv_array_t(G_DEPTH-1 downto 0)(G_DAT_N_COL*G_DAT_COL_W-1 downto 0) := 
         (others=>(others=>'0'));
      G_EN_ASSERT  : boolean := TRUE
   );
   port(
      i_en  : in std_logic;
      i_we  : in std_logic_vector(G_DAT_N_COL-1 downto 0);
      i_adr : in std_logic_vector(clog2(G_DEPTH)-1 downto 0);
      i_dat : in std_logic_vector(G_DAT_N_COL*G_DAT_COL_W-1 downto 0);
      o_dat : out std_logic_vector(G_DAT_N_COL*G_DAT_COL_W-1 downto 0);

      i_clk : in std_logic
      );
end entity test_ram_sp_tb;

architecture bench of test_ram_sp_tb is
   signal tb_blip : std_logic := '0'; 
begin
   ----------------------------------------------------------------------------
   -- Instantiate the DUT 
   ----------------------------------------------------------------------------
   dut : entity work.ram_sp(rtl)
   generic map (
      G_DAT_N_COL  => G_DAT_N_COL,
      G_DAT_COL_W  => G_DAT_COL_W,
      G_DEPTH      => G_DEPTH    ,
      G_RD_LATENCY => G_RD_LATENCY,
      G_MEM_STYLE  => G_MEM_STYLE
   )
   port map (
      i_en  => i_en ,
      i_we  => i_we ,
      i_adr => i_adr,
      i_dat => i_dat,
      o_dat => o_dat,

      i_clk  => i_clk
   );
end architecture bench;
