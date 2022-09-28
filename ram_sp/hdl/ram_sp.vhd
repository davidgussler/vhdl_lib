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
-- Description 
--    A highly configurable single port RAM. See descriptions of the generics below for help
--    with configuring the RAM to your needs.
--    Please see "ram_sp_tb.vhd" for example instantiations of this module.
--
-- Generics
--    G_DAT_N_COL  : integer range 1 to 64 := 4
--       Number of data columns per memory word; Each column can be exclusivly 
--       written; Set to 1 if indivudial bits within each memory word do not 
--       need to be exclusively written.
--       Typically this generic is set in conjunction with DAT_COL_W when byte write
--       granularity is required. For example: a RAM with 32 bit words and byte
--       writes would have DAT_N_COL=4 and DAT_COL_W=8. If byte writes are not
--       required for the same 32 bit RAM, then DAT_N_COL=1 and DAT_COL_W=32
--                  
--    G_DAT_COL_W  : integer range 1 to 64 := 8
--       Width of each column in bits
--                     
--    G_DEPTH      : positive := 1024
--       Depth of the memory; ie: size of the memory in bits = (DAT_N_COL*DAT_COL_W) * (DEPTH)
--       
--    G_RD_LATENCY : natural range 0 to 16 := 1
--       Number of cycles that it takes to output the ram data on the "o_dat" port after the 
--       address is received. 0 = combinational output. 
--       This must be set to > 1 if block RAM is to be instantiated. 
--   
--    G_MEM_STYLE  : string  := "auto"   OPTIONS:  ("block", "ultra", "distributed", "registers") 
--       Ram synthesis attribute; Will suggest the style of memory to instantiate,
--       but if other generics are set in a way that is incompatible with the 
--       suggested memory type, then the synthsizer will make the final style 
--       decision.
--       If this generic is left blank or if an unknown string is passed in,  
--       then the synthesizer will decide what to do. 
--       See Xilinx UG901 - Vivado Synthesis for more information on dedicated BRAMs
--                        
--    G_MEM_INIT   : t_vector_array(G_DEPTH-1 downto 0)(G_DAT_N_COL*G_DAT_COL_W-1 downto 0) 
--                 := (others=>(others=>'0'))
--       This generic makes use of VHDL '08 features, so it may not be supported 
--       by all tools. Please consult your vendor documentation. 
--       If memory does not need to be initialized then there is no need to set
--       generic and it can be left at its default value of (others=>(others=>'0')
--       If memory does need to be initialized, then a constant should be defined:
--       constant MEM_INIT  : t_vector_array(DEPTH-1 downto 0)(WIDTH-1 downto 0) := 
--       (X"<init_val0>", X"<init_val1>", X"<init_val2>", X"<init_val3>", 
--        X"<init_val4>", X"<init_val5>", X"<init_val6>", X"<init_val7>", ...etc)
--       and passed to the MEM_INIT generic.  
--       It is easy to get this part wrong if you're not careful. Make sure that 
--       DEPTH matches the DEPTH generic and WIDTH matches DAT_N_COL*DAT_COL_W
--
-- ###############################################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.gen_utils_pkg.all;

entity ram_sp is 
   generic(
      G_DAT_N_COL  : integer range 1 to 64 := 4;
      G_DAT_COL_W  : integer range 1 to 64 := 8;
      G_DEPTH      : positive := 1024;
      G_RD_LATENCY : natural range 0 to 16 := 1; 
      G_MEM_STYLE  : string  := "auto";
      G_MEM_INIT   : slv_array_t(G_DEPTH-1 downto 0)
         (G_DAT_N_COL*G_DAT_COL_W-1 downto 0) := (others=>(others=>'0'));
      G_EN_ASSERT  : boolean := TRUE
   );
   port(
      i_en  : in std_logic;
      i_we  : in std_logic_vector(G_DAT_N_COL-1 downto 0);
      i_adr : in std_logic_vector(clog2(G_DEPTH)-1 downto 0);
      i_dat : in std_logic_vector(G_DAT_N_COL*G_DAT_COL_W-1 downto 0);
      o_dat : out std_logic_vector(G_DAT_N_COL*G_DAT_COL_W-1 downto 0);

      i_clk : in std_logic
      );
end ram_sp;

architecture rtl of ram_sp is 
   -- Constants 
   constant C_DAT_W : integer := G_DAT_N_COL * G_DAT_COL_W;

   -- Types 
   type data_out_pipe_t is array (G_RD_LATENCY-1 downto 0) of 
      std_logic_vector(C_DAT_W-1 downto 0); 

   -- Wires
   signal w_dat : std_logic_vector(C_DAT_W-1 downto 0); 

   -- Registers
   signal r_dat : data_out_pipe_t := (others=>(others=>'0'));
   signal r_ram : slv_array_t(G_DEPTH-1 downto 0)(C_DAT_W-1 downto 0) := G_MEM_INIT;

   -- --------------------------------------------------------------------------
   -- Synthesis Attributes
   -- --------------------------------------------------------------------------
   -- Viavado 
   attribute ram_style : string;
   attribute ram_style of r_ram : signal is G_MEM_STYLE;

begin
   -- --------------------------------------------------------------------------
   -- Assignments
   -- --------------------------------------------------------------------------
   o_dat <= w_dat; 

   -- --------------------------------------------------------------------------
   -- Writes
   -- --------------------------------------------------------------------------
   prc_write : process (i_clk)
   begin
      if rising_edge(i_clk) then 
         if (i_en = '1') then 
            for i in 0 to G_DAT_N_COL-1 loop
               if (i_we(i) = '1') then 
                  r_ram(to_integer(unsigned(i_adr)))
                     (i*G_DAT_COL_W+G_DAT_COL_W-1 downto i*G_DAT_COL_W) <= 
                     i_dat(i*G_DAT_COL_W+G_DAT_COL_W-1 downto i*G_DAT_COL_W); 
               end if;
            end loop;
         end if; 
      end if;
   end process;

   -- --------------------------------------------------------------------------
   -- Asynchronous Reads
   -- --------------------------------------------------------------------------
   gen_async_read : if (G_RD_LATENCY = 0) generate 
      w_dat <= r_ram(to_integer(unsigned(i_adr))); 
   end generate;

   -- --------------------------------------------------------------------------
   -- Synchronous Reads
   -- --------------------------------------------------------------------------
   gen_sync_read : if (G_RD_LATENCY = 1) generate 
      proc_sync_read: process (i_clk)
      begin
         if rising_edge(i_clk) then 
            if (i_en = '1') then 
               r_dat(0) <= r_ram(to_integer(unsigned(i_adr))); 
            end if;
         end if; 
      end process; 
      w_dat <= r_dat(0); 
   end generate;

   -- --------------------------------------------------------------------------
   -- Synchronous Reads & Output Pipeline Registers
   -- --------------------------------------------------------------------------
   gen_sync_read_pipes : if (G_RD_LATENCY > 1) generate 
      proc_sync_read: process (i_clk)
      begin
         if rising_edge(i_clk) then 
            if (i_en = '1') then 
               r_dat(0) <= r_ram(to_integer(unsigned(i_adr))); 
               for i in 1 to G_RD_LATENCY-1 loop 
                  r_dat(i) <= r_dat(i-1); 
               end loop; 
            end if;
         end if; 
      end process; 
      w_dat <= r_dat(G_RD_LATENCY-1); 
   end generate;


   -- --------------------------------------------------------------------------
   -- Assertions 
   -- --------------------------------------------------------------------------
   gen_assertions : if (G_EN_ASSERT = TRUE) generate
      -- pragma translate_off 
      assert not (G_RD_LATENCY = 0 and (G_MEM_STYLE="block" or G_MEM_STYLE="ultra")) 
         report "Not able to instantiate the requested device specific memory primitive." &
            " G_RD_LATENCY must be at least 1." 
         severity warning; 
      assert (not (to_integer(unsigned(i_adr)) > G_DEPTH))
         report "Address is out of range (this could happen if G_DEPTH is not a power of 2" &
            " and an address larger than G_DEPTH was used). This will produce unexpected behavior"
         severity warning; 
      -- pragma translate_on 
   end generate;    

end rtl;