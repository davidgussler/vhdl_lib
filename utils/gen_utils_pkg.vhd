library ieee;
use ieee.std_logic_1164.all;

package gen_utils_pkg is

    -- =========================================================================
    -- Types
    -- =========================================================================
    -- 
    type slv_array_t is array (natural range <>) of std_logic_vector;
    type int_array_t is array (natural range <>) of integer;
    type bool_array_t is array (natural range <>) of boolean;

    type regtype_t is (RW_REG, RO_REG);
    type regtype_array_t is array (natural range <>) of regtype_t;


    -- =========================================================================
    -- Functions
    -- =========================================================================
    -- 
    -- Ceiling of log2 ---------------------------------------------------------
    -- -------------------------------------------------------------------------
    -- Use:      Determine the number of bits necessary to represent an integer
    -- Examples: clog2(1024) = 10
    --           clog2(1023) = 10
    --           clog2(1025) = 11
    -- -------------------------------------------------------------------------
    function clog2(
        x : positive) 
        return natural;

    end package;

    function find_max(
        x : int_array_t)
        return integer;
    
    function find_min(
        x : int_array_t)
        return integer;

package body gen_utils_pkg is

    -- Ceiling of log2 ---------------------------------------------------------
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
    function find_max(
        x : int_array_t)
        return integer
    is
        variable max := x(0);
    begin
        for i in int_array_t'range loop
            if (x(i) > max) then
                max := x(i);
            end if;
        end loop; 
    end function;


    -- Find Min ----------------------------------------------------------------
    -- -------------------------------------------------------------------------
    function find_max(
        x : int_array_t)
        return integer
    is
        variable max := x(0);
    begin
        for i in int_array_t'range loop
            if (x(i) > max) then
                max := x(i);
            end if;
        end loop; 
    end function;
   
end package body;