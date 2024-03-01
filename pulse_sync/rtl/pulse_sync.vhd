
entity pulse_sync is
   generic (
      N_FLOPS : integer range 2 to 5 := 2;
      ACT_LVL : std_logic := '1'; -- 1 for active high, 0 for active low
   );
   port (
      i_clka : in std_logic;
      i_srsta : in std_logic;
      i_pulsea : in std_logic;
      i_clkb : in std_logic;
      i_srstb : in std_logic;
      o_pulseb : in std_logic;
   );
end entity;

architecture rtl of pulse_sync is
   constant RST_LVL := not ACT_LVL; 
   signal sync_regs : std_logic_vector(N_FLOPS-1 downto 0) := (others=>RST_LVL);
   signal toggled   : std_logic := RST_LVL; 
   signal r_toggled : std_logic := RST_LVL; 

   -- Vivado Synthesis Attributes --
   -- tells synthesizer that these are synchronizing registers
   attribute ASYNC_REG : string;
   attribute ASYNC_REG of sync_regs : signal is "TRUE";

   -- tells the synthesizer to not use CLB shift registers 
   -- for sync_regs, which looks like a shift register 
   attribute SHREG_EXTRACT : string;
   attribute SHREG_EXTRACT of sync_regs : signal is "NO";
begin
   -- toggle on input pulse
   process (i_clka)
   begin
      if rising_edge(i_clka) then
         if (i_srstb = '1') then
            toggled <= RST_LVL; 
         else
            if (i_pulsea = ACT_LVL) then 
               toggled <= not toggled;
            else 
               toggled <= toggled; 
            end if;
         end if;
      end if; 
   end process;

   -- sync to output clock
   process (i_clkb)
   begin
      if rising_edge(i_clkb) then
         if (i_srstb = '1') then
            sync_regs <= (others=>RST_LVL); 
            r_toggled <= RST_LVL; 
         else
            sync_regs(0) <= toggled; 
            r_toggled <= sync_regs(N_FLOPS-1); -- register output of the synchronizer one more time so it can be used to pulse the toggle. 
            for i in 1 to N_FLOPS-1 loop
               sync_regs(i) <= sync_regs(i - 1);
            end loop;
         end if;
      end if; 
   end process;

   -- pulse on toggle
   o_pulse <= r_toggled xor sync_regs(N_FLOPS-1); 

end architecture;
