-- #################################################################################################
-- #  -<< Memory Generator - Single Port ROM Example >>-
-- # ===============================================================================================
-- # File     : mem_gen_example_rom_sp.vhd
-- # Author   : David Gussler - davidnguss@gmail.com 
-- # Language : VHDL '08
-- # History  :  Date      | Version | Comments 
-- #            --------------------------------
-- #            11-02-2022 | 1.0     | Initial 
-- # ===============================================================================================
-- # Single port ROM without an enable signal
-- # 
-- #################################################################################################

-- Libraries ---------------------------------------------------------------------------------------
-- -------------------------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.gen_utils_pkg.all;


-- Entity ==========================================================================================
-- =================================================================================================
entity mem_gen_example_rom_sp is 
    generic(
        G_DEPTH_L2      : positive := 10;
        G_MEM_STYLE     : string  := "";
        G_A_RD_LATENCY  : natural range 0 to 4 := 1; 
        G_B_RD_LATENCY  : natural range 0 to 4 := 1; 
        G_A_RD_MODE     : natural range 0 to 1 := 1; 
        G_B_RD_MODE     : natural range 0 to 1 := 1
    );
    port(
        i_clk  : in std_logic;
        i_addr : in std_logic_vector(G_DEPTH_L2-1 downto 0);
        o_rdat : out std_logic_vector(31 downto 0)
    );
end entity;


architecture rtl of mem_gen_example_rom_sp is
    constant MEM_INIT : slv_array_t(0 to (2**G_DEPTH_L2)-1)(31 downto 0) := (
        0 => x"1234_1234",
        1 => x"0101_0101",
        2 => x"1010_0101",
        3 => x"FFFF_CCCC",
        4 => x"0001_1238",
        5 => x"BBAA_CCDD",
        6 => x"5432_1098",
        7 => x"221A_BCDA",
        8 => x"4398_BEEF",
        9 => x"0000_18AD",
        others =>   x"1234_ABCD"
        
        );
        
begin

    rom : entity work.memory_generator
    generic map(
        G_BYTES_PER_ROW => 1,
        G_BYTE_WIDTH    => 32   ,
        G_DEPTH_L2      => G_DEPTH_L2     ,
        G_MEM_STYLE     => G_MEM_STYLE    ,
        G_MEM_INIT      => MEM_INIT     ,
        G_A_RD_LATENCY  => G_A_RD_LATENCY ,
        G_B_RD_LATENCY  => G_B_RD_LATENCY ,
        G_A_RD_MODE     => G_A_RD_MODE    ,
        G_B_RD_MODE     => G_B_RD_MODE    
    )
    port map(
        i_a_clk  => i_clk ,
        i_a_addr => i_addr,
        o_a_rdat => o_rdat
    );

end architecture;
