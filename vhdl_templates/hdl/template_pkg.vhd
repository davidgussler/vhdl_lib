-- ###############################################################################################
-- # << Template Package >> #
-- *********************************************************************************************** 
-- Copyright David N. Gussler 2022
-- *********************************************************************************************** 
-- File     : template_pkg.vhd
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
use work.gen_utils_pkg.all;

package template_pkg is
   constant C_CONST1 : integer := 1;
   constant C_CONST2 : integer := 2;

   type t_example is array (63 downto 0) of std_logic_vector(3 downto 0);
end package;

package body template_pkg is 
end package body;