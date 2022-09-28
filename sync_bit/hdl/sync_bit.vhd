-- synchronizes i_bit to i_clk as o_bit. No handshaking. 
-- assumes i_bit is held for at least 1.25x i_clk period 
-- reset signal is not required for any of the modules
-- tie the reset input to '0' and the synthesizer will 
-- strip the signal and related logic
-- all reset values are assigned a default at startup, 
-- if reset isnt necessary, tie it to gnd to save resources 
-- and make place n route easier

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sync_bit is
   generic (
      N_FLOPS : integer range 2 to 5 := 2;
      ACT_LVL : std_logic := '1'; -- 1 for active high, 0 for active low
   );
   port (
      i_clk : in std_logic;
      i_srst : in std_logic;
      i_bit : in std_logic;
      o_bit : out std_logic;
   );
end entity;

architecture rtl of sync_bit is
   constant RST_LVL := not ACT_LVL; 
   signal sync_regs : std_logic_vector(N_FLOPS-1 downto 0) := (others=>RST_LVL);

   -- Vivado Synthesis Attributes --
   -- tells synthesizer that these are synchronizing registers
   attribute ASYNC_REG : string;
   attribute ASYNC_REG of sync_regs : signal is "TRUE";

   -- tells the synthesizer to not use CLB shift registers 
   -- for sync_regs, which looks like a shift register 
   attribute SHREG_EXTRACT : string;
   attribute SHREG_EXTRACT of sync_regs : signal is "NO";
begin
   o_bit <= sync_regs(N_FLOPS-1);

   -- sync flops
   process (i_clk)
   begin
      if rising_edge(i_clk) then
         if (i_srst = '1') then
            sync_regs <= (others=>RST_LVL); 
         else
            sync_regs(0) <= i_bit; 
            for i in 1 to N_FLOPS-1 loop
               sync_regs(i) <= sync_regs(i - 1);
            end loop;
         end if;
      end if; 
   end process;
end architecture;