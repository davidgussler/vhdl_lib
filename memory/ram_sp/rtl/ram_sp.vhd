-- ###############################################################################################
-- # << Single Port RAM >> 
-- *********************************************************************************************** 
-- Copyright 2021
-- *********************************************************************************************** 
-- File     : ram_sp.vhd
-- Author   : David Gussler - davidnguss@gmail.com 
-- Language : VHDL '08
-- History  :  Date      | Version | Comments 
--            --------------------------------
--            12-18-2021 | 1.0     | Initial 
-- *********************************************************************************************** 
-- Description : 
--    A highly configurable single port RAM. See descriptions of the generics below for help
--    with configuring the RAM to your needs.
--    Please see "ram_sp_tb.vhd" for example instantiations of this module.
-- Generics
--    * DAT_N_COL => integer 1 to 64
--                   Number of data columns per memory word; Each column can be exclusivly 
--                   written; Set to 1 if indivudial bits within each memory word do not 
--                   need to be exclusively written.
--                   Typically this generic is set in conjunction with DAT_COL_W when byte write
--                   granularity is required. For example: a RAM with 32 bit words and byte
--                   writes would have DAT_N_COL=4 and DAT_COL_W=8. If byte writes are not
--                   required for the same 32 bit RAM, then DAT_N_COL=1 and DAT_COL_W=32
--                  
--    * DAT_COL_W => integer 1 to 64
--                   Width of each column in bits
--                  
--    * DEPTH     => integer 1 to 2^32 
--                   Depth of the memory; ie: size of the memory in bits = 
--                   (DAT_N_COL*DAT_COL_W) * (DEPTH)
--                   Theoritical Max is 4GBytes
--
--    * SYNC_RD   => boolean 
--                   if TRUE, then reads happen on the positive edge of the clock rather than
--                   being combinationally updated with the address 
--                     
--    * OUT_REG   => boolean 
--                   if TRUE, then an extra output register is added; Adds a cycle of delay
--                   if a BLOCK RAM is to be inferred, then either SYNC_RD, or OUT_REG, 
--                   or both SYNC_RD and OUT_REG must be set to TRUE. If SYNC_READ and 
--                   OUT_REG are both false, there will no clocked output delay and en_i
--                   is ignored for reads. If either SYNC_READ or OUT_REG is set, then 
--                   there will be one cycle of delay, if both are set then 2 cycles of delay
--
--    * MEM_STYLE => string ("block", "ultra", "distributed", "registers") 
--                   Ram synthesis attribute; Will suggest the style of memory to instantiate,
--                   but if other generics are set in a way that is incompatible with the 
--                   suggested memory type, then the synthsizer will make the final style 
--                   decision.
--                   If this generic is left blank or if an unknown string is passed in,  
--                   then the synthesizer will decide what to do. 
--                   See Xilinx UG901 - Vivado Synthesis for more information on dedicated RAMs
--
--    * INIT_TYPE => string ("hex", "bin", "mem_init")
--                   hex - Initialize the memory with external file that is in HEXADECIMAL format
--                   bin - Initialize the memory with external file that is in BINARY format
--                   mem_init - Initialize the memory with the MEM_INIT generic <- choose this 
--                             option if the memory does not need to be initialized 
--                   If this generic is left blank or if an unknown string is passed in,
--                   then the mem_init option will be selected. 
--
--    * FILE_NAME => string ("<file_name>.hex", "<file_name>.txt")
--                   name of the external file used to initialize the memory if INIT_TYPE = 
--                   "hex" or "bin"
--                   hex files must use .txt or .hex extentions
--                   binary files must use .txt extention
--                   !! WARNING !!
--                   It is important that the size of the memory file matches the size
--                   of the memory described by the first three generics. If this is violated 
--                   then unintended / unexplainable results may occur. 
--                   If the memory configuration file is in a directory that is different from 
--                   the directory that gen_utils_pkg is located in, then provide the ABSOLUTE
--                   path. For example: 
--                   "C:\Users\david\projects\fpga\reuse\memory\ram_sp\rtl\memory_init_bin.txt"
--                     
--    * MEM_INIT  => t_vector_array - unconstrained array of unconstrained std_logic_vector()
--                   This generic makes use of VHDL '08 features, so it may not be supported 
--                   by all tools. Please consult your vendor documentation. 
--                   If memory does not need to be initialized then there is no need to set
--                   generic and it can be left at its default value of (others=>(others=>'0')
--                   If memory does need to be initialized, then a constant should be defined:
--                   constant MEM_INIT  : t_vector_array(DEPTH-1 downto 0)(WIDTH-1 downto 0) := 
--                   (X"<init_val0>", X"<init_val1>", X"<init_val2>", X"<init_val3>", 
--                    X"<init_val4>", X"<init_val5>", X"<init_val6>", X"<init_val7>", ...etc)
--                   and passed to the MEM_INIT generic.  
--                   It is easy to get this part wrong if you're not careful. Make sure that 
--                   DEPTH matches the DEPTH generic and WIDTH matches DAT_N_COL*DAT_COL_W
--
-- ###############################################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_textio.all; 
use std.textio.all;

use work.gen_utils_pkg.all;

entity ram_sp is 
   generic(
      DAT_N_COL : integer range 1 to 64 := 4;
      DAT_COL_W : integer range 1 to 64 := 8;
      DEPTH     : integer := 1024;
      SYNC_RD   : boolean := TRUE;
      OUT_REG   : boolean := FALSE;
      MEM_STYLE : string  := "";
      INIT_TYPE : string  := ""; 
      FILE_NAME : string  := "mem_init.txt"; -- make sure to provide absolute path!
      MEM_INIT  : t_vector_array(DEPTH-1 downto 0)(DAT_N_COL*DAT_COL_W-1 downto 0) := (others=>(others=>'0'))
   );
   port(
      i_en  : in std_logic;
      i_we  : in std_logic_vector(DAT_N_COL-1 downto 0);
      i_adr : in std_logic_vector(ceil_log2(DEPTH)-1 downto 0);
      i_dat : in std_logic_vector(DAT_N_COL*DAT_COL_W-1 downto 0);
      o_dat : out std_logic_vector(DAT_N_COL*DAT_COL_W-1 downto 0);

      i_clk : in std_logic
      );
end ram_sp;

architecture rtl of ram_sp is 
   constant DAT_W : integer := DAT_N_COL * DAT_COL_W;
   signal w_dat, w2_dat : std_logic_vector(DAT_W-1 downto 0); 
   signal r_dat, r2_dat : std_logic_vector(DAT_W-1 downto 0) := (others=>'0'); -- optomized out if not used

   signal ram : t_vector_array(DEPTH-1 downto 0)(DAT_W-1 downto 0) := init_mem(INIT_TYPE, FILE_NAME, MEM_INIT, DEPTH, DAT_W);

   -- --------------------------------------------------------------------------------------------
   -- Synthesis Attributes
   -- --------------------------------------------------------------------------------------------  
   -- Viavado 
   attribute ram_style :  string;
   attribute ram_style of ram : signal is MEM_STYLE;

begin
   -- Error Checking 
   assert (not (SYNC_RD=FALSE and OUT_REG=FALSE) and (MEM_STYLE="block" or MEM_STYLE="ultra")) 
      report "Not able to instantiate device specific memory primitive. SYNC_RD and/or OUT_REG must be set to TRUE." 
      severity warning; 
   assert (not (to_integer(unsigned(i_adr)) > DEPTH))
      report "Tried to access an address that doesn't exist (this could happen if DEPTH is not a power of 2 and an address larger than DEPTH was used)."
      severity warning; 

   -- Output Assignments
   o_dat <= w2_dat; 

   -- --------------------------------------------------------------------------------------------
   -- Writes
   -- --------------------------------------------------------------------------------------------
   proc_ram: process (i_clk)
   begin
      if rising_edge(i_clk) then 
         if (i_en = '1') then 
            for i in 0 to DAT_N_COL-1 loop
               if (i_we(i) = '1') then 
                  ram(to_integer(unsigned(i_adr)))(i*DAT_COL_W+DAT_COL_W-1 downto i*DAT_COL_W) <= 
                     i_dat(i*DAT_COL_W+DAT_COL_W-1 downto i*DAT_COL_W); 
               end if;
            end loop;
         end if; 
      end if;
   end process;

   -- --------------------------------------------------------------------------------------------
   -- Asynchronous Reads
   -- --------------------------------------------------------------------------------------------
   gen_async_read : if (SYNC_RD = FALSE) generate 
      w_dat <= ram(to_integer(unsigned(i_adr))); 
   end generate;

   -- --------------------------------------------------------------------------------------------
   -- Synchronous Reads
   -- --------------------------------------------------------------------------------------------
   gen_sync_read : if (SYNC_RD = TRUE) generate 
      proc_sync_read: process (i_clk)
      begin
         if rising_edge(i_clk) then 
            if (i_en = '1') then 
               r_dat <= ram(to_integer(unsigned(i_adr))); 
            end if;
         end if; 
      end process; 
      w_dat <= r_dat; 
   end generate;

   -- --------------------------------------------------------------------------------------------
   -- Optional Output Register
   -- --------------------------------------------------------------------------------------------
   gen_out_reg : if (OUT_REG = TRUE) generate 
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

   gen_no_out_reg : if (OUT_REG = FALSE) generate 
      w2_dat <= w_dat; 
   end generate;

end rtl;