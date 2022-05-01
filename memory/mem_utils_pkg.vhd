-- ###############################################################################################
-- # << Memory Utilities Package >> 
-- *********************************************************************************************** 
-- Copyright 2022
-- *********************************************************************************************** 
-- File     : mem_utils_pkg.vhd
-- Author   : David Gussler
-- Created  : 12/12/2021
-- Language : VHDL '08
-- History  :  Date      | Version | Comments 
--            --------------------------------
--            12-18-2021 | 1.0     | Initial 
-- *********************************************************************************************** 
-- Description
--    A collection of types and functions for memory initialization
-- 
-- ###############################################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_textio.all; 
use std.textio.all;

package mem_utils_pkg is
   -- ============================================================================================
   -- Common Types
   -- ============================================================================================
   type t_vector_array  is array (natural range <>) of std_logic_vector; 
   

   -- ============================================================================================
   -- Memory Initialization Function Declariations
   -- ============================================================================================

   -- --------------------------------------------------------------------------------------------
   -- Initialize a RAM or ROM from a hex file
   -- --------------------------------------------------------------------------------------------
   function init_mem_hex(
      filename  : string;  
      MEM_DEPTH : integer;
      MEM_WIDTH : integer)
      return t_vector_array;

   -- --------------------------------------------------------------------------------------------
   -- Initialize a RAM or ROM from a binary file
   -- --------------------------------------------------------------------------------------------  
   function init_mem_bin(
      filename  : in string;
      MEM_DEPTH : in integer;
      MEM_WIDTH : in integer)
      return t_vector_array;
   
   -- --------------------------------------------------------------------------------------------
   -- General RAM/ROM initialization function
   -- --------------------------------------------------------------------------------------------
   function init_mem(
      INIT_TYPE : in string;
      filename  : in string;
      MEM_INIT  : in t_vector_array;
      MEM_DEPTH : in integer;
      MEM_WIDTH : in integer)
      return t_vector_array; 
      
end package;

package body mem_utils_pkg is
   -- ============================================================================================
   -- Memory Initialization Functions
   -- ============================================================================================
   
   function init_mem_hex(
      filename  : string;
      MEM_DEPTH : integer;
      MEM_WIDTH : integer)
      return t_vector_array
   is 
      --file mem_file : text open read_mode is filename;
      file mem_file : text is in filename;
      variable mem_file_line  : line;
      variable ram_content    : t_vector_array(MEM_DEPTH-1 downto 0)(MEM_WIDTH-1 downto 0);
      variable early_eof_flag : boolean := FALSE; 
   begin
      for i in 0 to MEM_DEPTH-1 loop
         if early_eof_flag = TRUE then 
            ram_content(i) := (others=>'0');
         else 
            readline(mem_file, mem_file_line);
            hread(mem_file_line, ram_content(i));
         end if; 
         if endfile(mem_file) then
            early_eof_flag := TRUE; 
         end if; 
      end loop;
      --file_close(mem_file);
      return ram_content;
   end function;

   function init_mem_bin(
      filename   : in string;
      MEM_DEPTH  : in integer;
      MEM_WIDTH  : in integer)  
      return t_vector_array
   is 
      file mem_file : text is in filename;
      variable mem_file_line  : line;
      variable ram_content    : t_vector_array(MEM_DEPTH-1 downto 0)(MEM_WIDTH-1 downto 0);
      variable early_eof_flag : boolean := FALSE; 
   begin
      for i in 0 to MEM_DEPTH-1 loop
         if early_eof_flag = TRUE then 
            ram_content(i) := (others=>'0');
         else 
            readline(mem_file, mem_file_line);
            read(mem_file_line, ram_content(i)); -- only difference from the previous function
         end if; 
         if endfile(mem_file) then
            early_eof_flag := TRUE; 
         end if; 
      end loop;
      --file_close(mem_file);
      return ram_content;
   end function;

   function init_mem(
      INIT_TYPE  : in string;
      filename   : in string;
      MEM_INIT   : in t_vector_array; -- (MEM_DEPTH-1 downto 0)(MEM_WIDTH-1 downto 0); TODO: fix this vivado error  
      MEM_DEPTH  : in integer;
      MEM_WIDTH  : in integer
   )
      return t_vector_array
   is 
      variable ram_content : t_vector_array(MEM_DEPTH-1 downto 0)(MEM_WIDTH-1 downto 0);
   begin
      if (INIT_TYPE = "hex") then
         ram_content := init_mem_hex(filename, MEM_DEPTH, MEM_WIDTH);
      elsif (INIT_TYPE = "bin") then
         ram_content := init_mem_bin(filename, MEM_DEPTH, MEM_WIDTH);
      else 
         ram_content := MEM_INIT;
      end if;
      return ram_content;
   end function; 

end package body;