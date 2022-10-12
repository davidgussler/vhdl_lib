-- #############################################################################
-- # << General VHDL Utilities >> #
-- *****************************************************************************
-- Copyright David N. Gussler 2022
-- *****************************************************************************
-- File     : wbregs.vhd
-- Author   : David Gussler - davidnguss@gmail.com 
-- Language : VHDL '08
-- History  :  Date      | Version | Comments 
--            --------------------------------
--            09-23-2022 | 1.0     | Initial 
-- *****************************************************************************
-- Description : 
--    VHDL utility functions. These should not be directly synthesized, but can 
--    be used for creating arrays, determining bounds, etc at compile time. 
--    TODO: Make some basic testbenches for these functions 

-- #############################################################################

library ieee;
use ieee.std_logic_1164.all;

package gen_utils_pkg is

    -- =========================================================================
    -- Types
    -- =========================================================================
    type slv_array_t is array (natural range <>) of std_logic_vector;
    type int_array_t is array (natural range <>) of integer;
    type bool_array_t is array (natural range <>) of boolean;

    type regtype_t is (RW_REG, RO_REG);
    type regtype_array_t is array (natural range <>) of regtype_t;


    -- =========================================================================
    -- Functions
    -- =========================================================================
    function clog2(
        x : positive) 
        return natural;

    function find_max(
        x : int_array_t)
        return integer;
    
    function find_min(
        x : int_array_t)
        return integer;

end package;

package body gen_utils_pkg is

    -- Ceiling of log2 ---------------------------------------------------------
    -- -------------------------------------------------------------------------
    -- Use:      Determine the number of bits necessary to represent an integer
    -- Examples: clog2(1024) = 10
    --           clog2(1023) = 10
    --           clog2(1025) = 11
    -- -------------------------------------------------------------------------
    function clog2 (
        x : positive) 
        return natural 
    is
        variable i : natural;
    begin
        i := 0;  
        while (2**i < x) and i < 31 loop
            i := i + 1;
        end loop;
        return i;
    end function;

    
    -- Find Max ----------------------------------------------------------------
    -- -------------------------------------------------------------------------
    -- Use:      
    -- Examples: 
    -- -------------------------------------------------------------------------
    function find_max(
        x : int_array_t)
        return integer
    is
        variable max : integer := x(0);
    begin
        for i in x'range loop
            if (x(i) > max) then
                max := x(i);
            end if;
        end loop; 
        return max; 
    end function;


    -- Find Min ----------------------------------------------------------------
    -- -------------------------------------------------------------------------
    -- Use: 
    -- Examples: 
    -- -------------------------------------------------------------------------
    function find_min(
        x : int_array_t)
        return integer
    is
        variable min : integer := x(0);
    begin
        for i in x'range loop
            if (x(i) < min) then
                min := x(i);
            end if;
        end loop; 
        return min;
    end function;
   
end package body;