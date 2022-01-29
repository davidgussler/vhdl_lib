-- ###############################################################################################
-- # << General Utilities Package >> 
-- *********************************************************************************************** 
-- Copyright 2022
-- *********************************************************************************************** 
-- File     : template_pkg.vhd
-- Author   : David Gussler
-- Created  : 12/12/2021
-- Language : VHDL '08
-- Description : 
--   A collection of common functions and types
-- ###############################################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_textio.all; 
use std.textio.all;

package gen_utils_pkg is
   -- ============================================================================================
   -- Common Types
   -- ============================================================================================
   constant c_NIBBLE_W : integer := 4;
   constant c_BYTE_W   : integer := 8;
   constant c_HWORD_W  : integer := 16;
   constant c_WORD_W   : integer := 32;
   constant c_DWORD_W  : integer := 64;
   constant c_QWORD_W  : integer := 128;

   subtype t_nibble is std_logic_vector(c_NIBBLE_W-1 downto 0);
   subtype t_byte   is std_logic_vector(c_BYTE_W  -1 downto 0);
   subtype t_hword  is std_logic_vector(c_HWORD_W -1 downto 0);
   subtype t_word   is std_logic_vector(c_WORD_W  -1 downto 0);
   subtype t_dword  is std_logic_vector(c_DWORD_W -1 downto 0);
   subtype t_qword  is std_logic_vector(c_QWORD_W -1 downto 0);

   type t_nibble_array is array (natural range <>) of t_nibble; 
   type t_byte_array   is array (natural range <>) of t_byte;
   type t_hword_array  is array (natural range <>) of t_hword; 
   type t_word_array   is array (natural range <>) of t_word;
   type t_dword_array  is array (natural range <>) of t_dword; 
   type t_qword_array  is array (natural range <>) of t_qword; 
   
   type t_vector_array  is array (natural range <>) of std_logic_vector; 
   
   
   -- ============================================================================================
   -- Common Function Declariations
   -- ============================================================================================
   
   -- --------------------------------------------------------------------------------------------
   -- Ceiling of log2
   -- --------------------------------------------------------------------------------------------
   -- Use:      Useful for determining the number of bits necessary to represent an integer
   -- Examples: ceil_log2(1024) = 10
   --           ceil_log2(1023) = 10
   --           ceil_log2(1025) = 11
   -- --------------------------------------------------------------------------------------------
   function ceil_log2(
      x : positive) 
      return natural;
   


   -- ============================================================================================
   -- Memory Initialization Function Declariations
   -- ============================================================================================

   -- --------------------------------------------------------------------------------------------
   -- Initialize a RAM or ROM from a hex file
   -- --------------------------------------------------------------------------------------------
   -- Use: 
   -- Examples: 
   -- --------------------------------------------------------------------------------------------
   function init_mem_hex(
      filename  : string;  
      MEM_DEPTH : integer;
      MEM_WIDTH : integer)
      return t_vector_array;

   -- --------------------------------------------------------------------------------------------
   -- Initialize a RAM or ROM from a binary file
   -- --------------------------------------------------------------------------------------------
   -- Use:     
   -- Examples: 
   -- --------------------------------------------------------------------------------------------   
   function init_mem_bin(
      filename  : in string;
      MEM_DEPTH : in integer;
      MEM_WIDTH : in integer)
      return t_vector_array;
   
   -- --------------------------------------------------------------------------------------------
   -- General RAM/ROM initialization function
   -- --------------------------------------------------------------------------------------------
   -- Use:     Recommended for the user to calll this function
   -- Examples: 
   -- --------------------------------------------------------------------------------------------
   function init_mem(
      INIT_TYPE : in string;
      filename  : in string;
      MEM_INIT  : in t_vector_array;
      MEM_DEPTH : in integer;
      MEM_WIDTH : in integer)
      return t_vector_array; 
      
end package;

package body gen_utils_pkg is
   -- ============================================================================================
   -- Common Functions
   -- ============================================================================================

   -- --------------------------------------------------------------------------------------------
   -- Ceiling of log2
   -- --------------------------------------------------------------------------------------------
   function ceil_log2 (
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



   -- ============================================================================================
   -- Memory Initialization Functions
   -- ============================================================================================
   
   -- --------------------------------------------------------------------------------------------
   -- Initialize a RAM or ROM from a hex file
   -- --------------------------------------------------------------------------------------------
   function init_mem_hex(
      filename  : string;
      MEM_DEPTH : integer;
      MEM_WIDTH : integer)
      return t_vector_array
   is 
      file mem_file : text open read_mode is filename;
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
      file_close(mem_file);
      return ram_content;
   end function;

   -- --------------------------------------------------------------------------------------------
   -- Initialize a RAM or ROM from a binary file
   -- --------------------------------------------------------------------------------------------
   function init_mem_bin(
      filename   : in string;
      MEM_DEPTH  : in integer;
      MEM_WIDTH  : in integer)
      return t_vector_array
   is 
      file mem_file : text open read_mode is filename;
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
      file_close(mem_file);
      return ram_content;
   end function;

   -- --------------------------------------------------------------------------------------------
   -- General RAM/ROM initialization function
   -- --------------------------------------------------------------------------------------------
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