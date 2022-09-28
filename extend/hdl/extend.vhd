library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity extend is
   generic (
      SIGN_EXT : boolean := TRUE; -- TRUE=sign extend; FALSE= zero extend
      IN_W     : natural := 12; 
      OUT_W    : natural := 32;
   );
   port (
      i_dat : in std_logic_vector(IN_W-1 downto 0);
      o_dat : out std_logic_vector(OUT_W-1 downto 0);
   );
end entity;

architecture rtl of extend is
   signal dat : std_logic_vector(OUT_W-1 downto 0);
begin
   -- error checking 
   assert not (OUT_W <= IN_W) 
      report "EXTENDER: Input width is greater than output width. This is not typical use for this module"
      severity warning; 

   dat_o <= dat;

   -- typical case 
   if (OUT_W > IN_W) generate 
      if (SIGN_EXT = TRUE) generate 
         dat(OUT_W-1 downto IN_W) <= (others=>i_dat(IN_W-1));
         dat(IN_W-1 downto 0) <= i_dat;
      end generate; 

      if (SIGN_EXT = FALSE) generate 
         dat(OUT_W-1 downto IN_W) <= (others=>'0');
         dat(IN_W-1 downto 0) <= i_dat;
      end generate; 
   end generate; 

   -- will cut off the input's most significant bits. not typical how this module should be used, but 
   -- this functionality is included for completeness
   if (OUT_W <= IN_W) generate 
      dat <= i_dat(OUT_W-1 downto 0);
   end generate; 

end architecture;