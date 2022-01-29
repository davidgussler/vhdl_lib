entity counter_lite is
   generic (
      CNT_W : natural := 32; -- width of counter in bits
      ROLLOVR_RST_VAL : integer := 0;  -- rollover and reset value of count
      THRESH          : integer := 2**CNT_W; -- when the count reaches this value, it will reset to ROLLOVR_RST_VAL
      DIR : integer range 0 to 1 := 0; -- 0 for upcount mode; 1 for downcount mode 
      SIGNED_TF : boolean := FALSE; -- FALSE for unsigned, TRUE for signed. 
   )
   port (
      i_en : in std_logic;
      o_count : out std_logic_vector(CNT_W-1 downto 0);

      i_srst  : in std_logic;
      i_clk   : in std_logic;
   );
end entity;

architecture rtl of up_counter_lite is
   signal count : integer := ROLLOVER_RST_VAL; 
begin

   if (SIGNED_TF = FALSE) generate 
      o_count <= std_logic_vector(to_unsigned(count, CNT_W-));
   end generate; 
   if (SIGNED_TF = TRUE) generate 
      o_count <= std_logic_vector(to_signed(count, CNT_W-));
   end generate;    

   -- up counter mode
   if (DIR = 0) generate 
      process (i_clk) begin
         if rising_edge(i_clk) then
            if i_srst = '1' then
               count <= ROLLOVER_RST_VAL; 
            else
               if (count = THRESH) then
                  count <= ROLLOVER_RST_VAL; 
               elsif (i_en = '1') then
                  count <= count + 1; 
               end if;
            end if;
         end if;
      end process;
   end generate;

   -- down counter mode 
   if (DIR = 1) generate 
      process (i_clk) begin
         if rising_edge(i_clk) then
            if i_srst = '1' then
               count <= ROLLOVER_RST_VAL; 
            else
               if (count = THRESH) then
                  count <= ROLLOVER_RST_VAL; 
               elsif (i_en = '1') then
                  count <= count - 1; 
               end if;
            end if;
         end if;
      end process;
   end generate;  
end architecture;