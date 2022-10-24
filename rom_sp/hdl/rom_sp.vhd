-- ###############################################################################################
-- # << Single Port RAM >> 
-- *********************************************************************************************** 
-- Copyright David N. Gussler 2022
-- *********************************************************************************************** 
-- File     : rom_sp.vhd
-- Author   : David Gussler - davidnguss@gmail.com 
-- Language : VHDL '08
-- History  :  Date      | Version | Comments 
--            --------------------------------
--            01-15-2022 | 1.0     | Initial 
-- *********************************************************************************************** 
-- Description : 
--   A highly configurable single port ROM. See descriptions of the generics below for help
--   with configuring the ROM to your needs.
--   Please see "rom_sp_tb.vhd" for example instantiations of this module.
-- Generics
--   DAT_COL_W => integer 1 to 64
--                Width of each column in bits
--               
--   DEPTH     => integer 1 to 2^32 
--                Depth of the memory; ie: size of the memory in bits = 
--                (DAT_N_COL*DAT_COL_W) * (DEPTH)
--                Theoritical Max is 4GBytes
--  
--   SYNC_RD   => boolean 
--                if TRUE, then reads happen on the positive edge of the clock rather than
--                being combinationally updated with the address 
--                  
--   OUT_REG   => boolean 
--                if TRUE, then an extra output register is added; Adds a cycle of delay
--                if a BLOCK RAM is to be inferred, then either SYNC_RD, or OUT_REG, 
--                or both SYNC_RD and OUT_REG must be set to TRUE. If SYNC_READ and 
--                OUT_REG are both false, there will no clocked output delay and en_i
--                is ignored for reads. If either SYNC_READ or OUT_REG is set, then 
--                there will be one cycle of delay, if both are set then 2 cycles of delay
--  
--   MEM_STYLE => string ("block", "ultra", "distributed", "registers") 
--                Ram synthesis attribute; Will suggest the style of memory to instantiate,
--                but if other generics are set in a way that is incompatible with the 
--                suggested memory type, then the synthsizer will make the final style 
--                decision.
--                If this generic is left blank or if an unknown string is passed in,  
--                then the synthesizer will decide what to do. 
--                See Xilinx UG901 - Vivado Synthesis for more information on dedicated RAMs
--
--   INIT_TYPE => string ("hex", "bin", "mem_init")
--                hex - Initialize the memory with external file that is in HEXADECIMAL format
--                bin - Initialize the memory with external file that is in BINARY format
--                mem_init - Initialize the memory with the MEM_INIT generic <- choose this 
--                          option if the memory does not need to be initialized 
--                If this generic is left blank or if an unknown string is passed in,
--                then the mem_init option will be selected. 
--  
--   FILE_NAME => string ("<file_name>.hex", "<file_name>.txt")
--                name of the external file used to initialize the memory if INIT_TYPE = 
--                "hex" or "bin"
--                hex files must use .txt or .hex extentions
--                binary files must use .txt extention
--                !! WARNING !!
--                It is important that the size of the memory file matches the size
--                of the memory described by the first three generics. If this is violated 
--                then unintended / unexplainable results may occur. 
--                If the memory configuration file is in a directory that is different from 
--                the directory that gen_utils_pkg is located in, then provide the ABSOLUTE
--                path. For example: 
--                "C:\Users\david\projects\fpga\reuse\memory\ram_sp\rtl\memory_init_bin.txt"
--                  
--   MEM_INIT  => t_vector_array - unconstrained array of unconstrained std_logic_vector()
--                This generic makes use of VHDL '08 features, so it may not be supported 
--                by all tools. Please consult your vendor documentation. 
--                If memory does not need to be initialized then there is no need to set
--                generic and it can be left at its default value of (others=>(others=>'0')
--                If memory does need to be initialized, then a constant should be defined:
--                constant MEM_INIT  : t_vector_array(DEPTH-1 downto 0)(WIDTH-1 downto 0) := 
--                (X"<init_val0>", X"<init_val1>", X"<init_val2>", X"<init_val3>", 
--                 X"<init_val4>", X"<init_val5>", X"<init_val6>", X"<init_val7>", ...etc)
--                and passed to the MEM_INIT generic.  
--                It is easy to get this part wrong if you're not careful. Make sure that 
--                DEPTH matches the DEPTH generic and WIDTH matches DAT_N_COL*DAT_COL_W
--  
-- ###############################################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_textio.all; 
use std.textio.all;

use work.gen_utils_pkg.all;

entity rom_sp is 
   generic(
      G_DAT_W     : integer range 1 to 64 := 32;
      G_DEPTH     : integer := 1024;
      G_SYNC_RD   : boolean := TRUE;
      G_OUT_REG   : boolean := FALSE;
      G_MEM_STYLE : string  := "";
      G_MEM_INIT  : slv_array_t(DEPTH-1 downto 0)(DAT_W-1 downto 0) := (others=>(others=>'0'))
   );
   port(
      i_en  : in std_logic;
      i_adr : in std_logic_vector(clog2(DEPTH)-1 downto 0);
      o_dat : out std_logic_vector(DAT_W-1 downto 0);

      i_clk : in std_logic
      );
end rom_sp;

architecture rtl of rom_sp is 
   signal w_dat, w2_dat : std_logic_vector(G_DAT_W-1 downto 0); 
   signal r_dat, r2_dat : std_logic_vector(G_DAT_W-1 downto 0) := (others=>'0');

   signal rom : slv_array_t(DEPTH-1 downto 0)(DAT_W-1 downto 0) := G_MEM_INIT;

   -- --------------------------------------------------------------------------------------------
   -- Synthesis Attributes
   -- --------------------------------------------------------------------------------------------  
   -- Viavado 
   attribute rom_style :  string;
   attribute rom_style of rom : signal is G_MEM_STYLE;

begin
   -- Error Checking 
   assert (not (G_SYNC_RD=FALSE and G_OUT_REG=FALSE) and (G_MEM_STYLE="block" or G_MEM_STYLE="ultra")) 
      report "Not able to instantiate device specific memory primitive. SYNC_RD and/or OUT_REG must be set to TRUE." 
      severity warning; 
   assert (not (to_integer(unsigned(i_adr)) > G_DEPTH))
      report "Tried to access an address that doesn't exist (this could happen if DEPTH is not a power of 2 and an address larger than DEPTH was used)."
      severity warning; 

   -- Output Assignments
   o_dat <= w2_dat; 

   -- --------------------------------------------------------------------------------------------
   -- Asynchronous Reads
   -- --------------------------------------------------------------------------------------------
   gen_async_read : if (G_SYNC_RD = FALSE) generate 
      w_dat <= rom(to_integer(unsigned(i_adr))); 
   end generate;

   -- --------------------------------------------------------------------------------------------
   -- Synchronous Reads
   -- --------------------------------------------------------------------------------------------
   gen_sync_read : if (G_SYNC_RD = TRUE) generate 
      proc_sync_read: process (i_clk)
      begin
         if rising_edge(i_clk) then 
            if (i_en = '1') then 
               r_dat <= rom(to_integer(unsigned(i_adr))); 
            end if;
         end if; 
      end process; 
      w_dat <= r_dat; 
   end generate;

   -- --------------------------------------------------------------------------------------------
   -- Optional Output Register
   -- --------------------------------------------------------------------------------------------
   gen_out_reg : if (G_OUT_REG = TRUE) generate 
      proc_sync_read: process (i_clk)
      begin
         if rising_edge(i_clk) then 
            if (i_en = '1') then 
               r2_dat <= w_dat;
            end if;
         end if; 
      end process; 
      w2_dat <= r2_dat; 
   end generate;

   gen_no_out_reg : if (G_OUT_REG = FALSE) generate 
      w2_dat <= w_dat; 
   end generate;

end rtl;