-- ###############################################################################################
-- # << Synchronous FIFO >> 
-- *********************************************************************************************** 
-- Copyright 2022
-- *********************************************************************************************** 
-- File     : fifo_sync.vhd
-- Author   : David Gussler - davidnguss@gmail.com 
-- Language : VHDL '08
-- History  :  Date      | Version | Comments 
--            --------------------------------
--            04-30-2022 | 1.0     | Initial 
-- *********************************************************************************************** 
-- Description : 
--    Synchronous FIFO module 
-- Generics :
--
--
--
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;


entity fifo is
   generic (
      G_WIDTH        : positive := 32; 
      G_DEPTH_L2   : positive := 11; 
      G_ALMOST_FULL  : natural  := 2; 
      G_ALMOST_EMPTY : natural  := 2;
      G_MEM_STYLE    : string  := "";
      G_REG_OUTPUT   : boolean := TRUE
   );
   port (
      i_clk   : in std_logic;
      i_rst   : in std_logic;

      -- Write Port
      i_wr           : in  std_logic; 
      i_dat          : in  std_logic_vector(G_WIDTH-1 downto 0); 
      o_almost_full  : out std_logic; 
      o_full         : out std_logic; 

      -- Read Port
      i_rd           : in  std_logic; 
      o_dat          : out std_logic_vector(G_WIDTH-1 downto 0); 
      o_almost_empty : out std_logic; 
      o_empty        : out std_logic
   );
end entity;

architecture rtl of fifo is
   
   -- Constants 
   constant C_DEPTH : integer := 2 ** G_DEPTH_L2; 
   constant C_ALMOST_FULL_LVL : integer := C_DEPTH - G_ALMOST_FULL; 
   
   -- Types 
   type t_fifo  is array (C_DEPTH-1 downto 0) of std_logic_vector(G_WIDTH-1 downto 0); 

   -- Wires 
   signal w_full  : std_logic; 
   signal w_empty : std_logic; 

   -- Registers 
   signal r_fifo_cnt : unsigned(G_DEPTH_L2 downto 0) := (others=>'0'); -- tracks how "full" the fifo is
   signal r_rd_ptr   : unsigned(G_DEPTH_L2-1 downto 0) := (others=>'0'); 
   signal r_wr_ptr   : unsigned(G_DEPTH_L2-1 downto 0) := (others=>'0');   
   signal r_fifo     : t_fifo; 

   -- --------------------------------------------------------------------------------------------
   -- Synthesis Attributes
   -- --------------------------------------------------------------------------------------------  
   -- Viavado 
   attribute ram_style : string;
   attribute ram_style of r_fifo : signal is G_MEM_STYLE;

begin

   -- Comb Assignments
   o_full <= w_full;
   o_empty <= w_empty; 
   o_almost_full  <= '1' when r_fifo_cnt >= C_ALMOST_FULL_LVL else '0';
   o_almost_empty <= '1' when r_fifo_cnt <= G_ALMOST_EMPTY else '0';

   w_full  <= '1' when r_fifo_cnt = C_DEPTH else '0'; 
   w_empty <= '1' when r_fifo_cnt = 0       else '0';

   sp_fifo_sync : process (i_clk)
   begin
      if rising_edge(i_clk) then
         if (i_rst) then 
            r_fifo_cnt <= (others=>'0');
            r_fifo     <= (others=>'0');
            r_wr_ptr   <= (others=>'0');
            r_rd_ptr   <= (others=>'0');
         else 

            -- Determine how full the FIFO is  
            if (i_wr = '1' and w_full = '0') and (i_rd = '0') then 
               r_fifo_cnt <= r_fifo_cnt + 1;
            elsif (i_rd = '1' and w_empty = '0') and (i_wr = '0') then 
               r_fifo_cnt <= r_fifo_cnt - 1;
            end if; 

            -- Write
            if (i_wr = '1' and w_full = '0') then 
               r_fifo(to_integer(r_wr_ptr)) <= i_dat; 
               r_wr_ptr <= r_wr_ptr + 1;
            end if; 

            -- Read 
            if (i_rd = '1' and w_empty = '0') then 
               r_rd_ptr <= r_rd_ptr + 1;
            end if; 
         end if; 
      end if;
   end process;

   ig_reg_out : if (G_REG_OUTPUT = TRUE) generate
      sp_sync_reads : process (i_clk)
      begin
         if rising_edge(i_clk) then
            if (i_rst) then 
               o_dat <= (others=>'0');
            else 
               if (i_rd = '1' and w_empty = '0') then 
                  o_dat <= r_fifo(to_integer(r_rd_ptr)); 
               end if; 
            end if; 
         end if;
      end process;
   end generate;

   ig_no_reg_out : if (G_REG_OUTPUT = FALSE) generate
      ap_async_reads : process (all)
      begin
         o_dat <= r_fifo(to_integer(r_rd_ptr)); 
      end process;
   end generate;


end architecture;
