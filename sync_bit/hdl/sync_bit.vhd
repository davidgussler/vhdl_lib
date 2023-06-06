-- #############################################################################
-- #  << Sync Bit >>
-- # ===========================================================================
-- # File     : sync_bit.vhd
-- # Author   : David Gussler - david.gussler@proton.me
-- # Language : VHDL '08
-- # ===========================================================================
-- # BSD 2-Clause License
-- # 
-- # Copyright (c) 2023, David Gussler. All rights reserved.
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
-- # Simple 1-bit synchronizer.
-- # 
-- #############################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sync_bit is
   generic (
      G_N_FLOPS : integer range 2 to 5 := 2;
      G_RST_VAL : std_logic := '0'
   );
   port (
      i_clk : in  std_logic;
      i_rst : in  std_logic;
      i_async : in  std_logic;
      o_sync : out std_logic
   );
end entity;

architecture rtl of sync_bit is
   signal sync_regs : std_logic_vector(G_N_FLOPS-1 downto 0);

   -- Vivado Synthesis Attributes --
   -- tells synthesizer that these are synchronizing registers
   attribute ASYNC_REG : string;
   attribute ASYNC_REG of sync_regs : signal is "TRUE";

   -- tells the synthesizer to not use CLB shift registers 
   -- for sync_regs, which looks like a shift register 
   attribute SHREG_EXTRACT : string;
   attribute SHREG_EXTRACT of sync_regs : signal is "NO";
begin
   o_sync <= sync_regs(0);

   -- sync flops
   process (i_clk)
   begin
      if rising_edge(i_clk) then
         if (i_rst = '1') then
            sync_regs <= (others=>G_RST_VAL); 
         else 
            sync_regs <= i_async & sync_regs(G_N_FLOPS-1 downto 1);
         end if;
      end if; 
   end process;
end architecture;