-- #############################################################################
-- #  -<< Memory Init Package >>-
-- # ===========================================================================
-- # Copyright 2022, David Gusser
-- # ===========================================================================
-- # File     : meminit.vhd
-- # Language : VHDL '08
-- # ===========================================================================
-- # This file was generated using the tool: ./create_meminit.sh
-- # Generated on: Sat Dec  3 02:10:10 PM EST 2022
-- #
-- #############################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.gen_utils_pkg.all;

package meminit_pkg is 

constant C_REG_ADR : slv_array_t(0 to 3-1)(31 downto 0) := (
    x"12345678",
    x"01010101",
    x"FFFFFFFF"
);
end package;
