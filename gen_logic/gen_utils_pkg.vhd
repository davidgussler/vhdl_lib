library ieee;
use ieee.std_logic_1164.all;

package gen_utils_pkg is

   -- --------------------------------------------------------------------------------------------
   -- Ceiling of log2
   -- --------------------------------------------------------------------------------------------
   -- Use:      Useful for determining the number of bits necessary to represent an integer
   -- Examples: clog2(1024) = 10
   --           clog2(1023) = 10
   --           clog2(1025) = 11
   -- --------------------------------------------------------------------------------------------
   function clog2(
      x : positive) 
      return natural;

   end package;

package body gen_utils_pkg is

   -- --------------------------------------------------------------------------------------------
   -- Ceiling of log2
   -- --------------------------------------------------------------------------------------------
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
   
end package body;