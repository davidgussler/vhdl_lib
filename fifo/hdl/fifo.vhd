-- #############################################################################
-- #  << Synchronous FIFO >>
-- # ===========================================================================
-- # File     : fifo.vhd
-- # Author   : David Gussler - david.gussler@proton.me
-- # Language : VHDL '08
-- # ===========================================================================
-- # BSD 2-Clause License
-- # 
-- # Copyright (c) 2022, David Gussler. All rights reserved.
-- # 
-- # Redistribution and use in source and binary forms, with or without
-- # modification, are permitted provided that the following conditions are met:
-- # 
-- # 1. Redistributions of source code must retain the above copyright notice,
-- #     this list of conditions and the following disclaimer.
-- # 
-- # 2. Redistributions in binary form must reproduce the above copyright 
-- #    notice, this list of conditions and the following disclaimer in the 
-- #    documentation and/or other materials provided with the distribution.
-- # 
-- # THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
-- # AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
-- # IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE 
-- # ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE 
-- # LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
-- # CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF 
-- # SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS 
-- # INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN 
-- # CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) 
-- # ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
-- #  POSSIBILITY OF SUCH DAMAGE.
-- # ===========================================================================
-- # Simple synchronous FIFO module with fallthru and standard modes
-- # Source: https://vhdlwhiz.com/ring-buffer-fifo/
-- #
-- #############################################################################
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity fifo is
   generic (
      G_WIDTH     : positive := 32; 
      G_DEPTH_L2  : positive := 11; -- true depth = 2^G_DEPTH_L2 - 1
      G_MEM_STYLE : string  := "auto";
      G_FALLTHRU  : boolean := FALSE
   );
   port (
      -- Clock & Reset
      i_clk : in std_logic;
      i_rst : in std_logic := '0';

      -- Write Port
      i_wr       : in  std_logic; 
      i_dat      : in  std_logic_vector(G_WIDTH-1 downto 0); 
      o_full_nxt : out std_logic; 
      o_full     : out std_logic; 

      -- Read Port
      i_rd        : in  std_logic; 
      o_dat       : out std_logic_vector(G_WIDTH-1 downto 0); 
      o_empty_nxt : out std_logic; 
      o_empty     : out std_logic;

      o_fill_cnt  : out std_logic_vector(G_DEPTH_L2-1 downto 0)
   );
end entity;

architecture rtl of fifo is

   -- Constants 
   constant C_DEPTH : integer := 2 ** G_DEPTH_L2; 
   
   -- Types 
   type t_ram  is array (C_DEPTH-1 downto 0) of std_logic_vector(G_WIDTH-1 downto 0); 

   -- Wires 
   signal fifo_cnt : unsigned(G_DEPTH_L2-1 downto 0);  -- tracks how "full" the fifo is

   -- Registers 
   signal rd_ptr : unsigned(G_DEPTH_L2-1 downto 0); 
   signal wr_ptr : unsigned(G_DEPTH_L2-1 downto 0);   
   signal ram    : t_ram; 

   -- --------------------------------------------------------------------------------------------
   -- Synthesis Attributes
   -- --------------------------------------------------------------------------------------------  
   -- Vivado 
   attribute ram_style : string;
   attribute ram_style of ram : signal is G_MEM_STYLE;

begin

   -- Comb Assignments
   o_full      <= '1' when fifo_cnt = C_DEPTH-1  else '0'; 
   o_full_nxt  <= '1' when fifo_cnt >= C_DEPTH-2 else '0';
   o_empty     <= '1' when fifo_cnt = 0          else '0';
   o_empty_nxt <= '1' when fifo_cnt <= 1         else '0';
   o_fill_cnt  <= std_logic_vector(fifo_cnt); 

   -- Update count
   ap_fifo_count : process (all)
   begin
      if (wr_ptr < rd_ptr) then
         fifo_cnt <= wr_ptr - rd_ptr + C_DEPTH; 
      else 
         fifo_cnt <= wr_ptr - rd_ptr; 
      end if; 
   end process;


   -- Update pointers
   sp_pointers : process (i_clk)
   begin
      if rising_edge(i_clk) then
         if (i_rst) then 
            wr_ptr   <= (others=>'0');
            rd_ptr   <= (others=>'0');
         else 

            -- Write
            if (i_wr and not o_full) then 
               wr_ptr <= wr_ptr + 1;
            end if; 

            -- Read 
            if (i_rd and not o_empty) then 
               rd_ptr <= rd_ptr + 1;
            end if; 

         end if; 
      end if;
   end process;


   -- Writes
   sp_fifo_writes : process (i_clk)
   begin
      if rising_edge(i_clk) then
         if (i_wr and not o_full) then 
            ram(to_integer(wr_ptr)) <= i_dat; 
         end if; 
      end if;
   end process;

   -- Sync reads
   ig_no_fallthru : if (G_FALLTHRU = FALSE) generate
      sp_sync_reads : process (i_clk)
      begin
         if rising_edge(i_clk) then
            if (i_rst) then 
               o_dat <= (others=>'0');
            else 
               if (i_rd and not o_empty) then 
                  o_dat <= ram(to_integer(rd_ptr)); 
               end if; 
            end if; 
         end if;
      end process;
   end generate;

   -- Lookahead reads 
   ig_fallthru : if (G_FALLTHRU = TRUE) generate
      o_dat <= ram(to_integer(rd_ptr)); 
   end generate;

end architecture;
