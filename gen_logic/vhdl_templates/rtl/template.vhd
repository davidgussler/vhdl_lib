-- ###############################################################################################
-- # << Template >> #
-- *********************************************************************************************** 
-- Copyright 2022
-- *********************************************************************************************** 
-- File     : template.vhd
-- Author   : David Gussler - davidnguss@gmail.com 
-- Language : VHDL '08
-- History  :  Date      | Version | Comments 
--            --------------------------------
--            12-18-2021 | 1.0     | Initial 
-- *********************************************************************************************** 
-- Description : 
--     Useful description describing the description to describe the module
-- Generics
--     * g_GEN1 => This generic controlls a thing
--     * g_GEN2 => This generic controlls another thing
-- ###############################################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.gen_utils_pkg.all;

entity template is 
   generic(
      GEN1 : integer := 1;
      GEN2 : integer := 2
   );
   port(
      o_sig2: out std_logic;
      o_dat2: out std_logic_vector(7 downto 0);
      i_sig1: in std_logic;
      i_dat1: in std_logic_vector(7 downto 0);

      i_rst : in std_logic;
      i_clk : in std_logic
      );
end template;

architecture rtl of template is 
   type t_array is array(GEN1 downto 0) of std_logic_vector(7 downto 0);
   signal arr : t_array;
begin
   -- --------------------------------------------------------------------------------------------
   -- Combinational Logic
   -- --------------------------------------------------------------------------------------------
   o_dat2 <= std_logic_vector(signed(i_dat1) + signed(i_dat1)) when (GEN2 = 1) else
             std_logic_vector(signed(i_dat1) - signed(i_dat1)) when (GEN2 = 1) else
             (others=>'0'); 

   -- --------------------------------------------------------------------------------------------
   -- Sequential Logic
   -- --------------------------------------------------------------------------------------------
   Proc_seq : process (i_clk) begin
      if (rising_edge(i_clk)) then
         if (i_rst = '1') then
            o_sig2 <= '0';
         else
            o_sig2 <= i_sig1;
         end if;
      end if;   
   end process;
end rtl;