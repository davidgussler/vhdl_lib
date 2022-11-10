-- #################################################################################################
-- #  -<< Memory Generator - True Dual Port RAM Example >>-
-- # ===============================================================================================
-- # File     : mem_gen_example_tdp.vhd
-- # Author   : David Gussler - davidnguss@gmail.com 
-- # Language : VHDL '08
-- # History  :  Date      | Version | Comments 
-- #            --------------------------------
-- #            11-02-2022 | 1.0     | Initial 
-- # ===============================================================================================
-- # Example using the full features of the memory generator.
-- # True dual-port RAM with independent clocks
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
entity mem_gen_example_tdp is 
    generic(
        G_BYTES_PER_ROW : integer range 1 to 64 := 4;
        G_BYTE_WIDTH    : integer range 1 to 64 := 8;
        G_DEPTH_L2      : positive := 10;
        G_MEM_STYLE     : string  := "";
        G_MEM_INIT      : slv_array_t(0 to (2**G_DEPTH_L2)-1)(G_BYTES_PER_ROW*G_BYTE_WIDTH-1 downto 0)
                := (others=>(others=>'0'));
        G_A_RD_LATENCY  : natural range 0 to 4 := 1; 
        G_B_RD_LATENCY  : natural range 0 to 4 := 1; 
        G_A_RD_MODE     : natural range 0 to 1 := 0; 
        G_B_RD_MODE     : natural range 0 to 1 := 0
    );
    port(
        -- Port A
        i_a_clk  : in std_logic := '0';
        i_a_en   : in std_logic := '1';
        i_a_we   : in std_logic_vector(G_BYTES_PER_ROW-1 downto 0);
        i_a_addr : in std_logic_vector(G_DEPTH_L2-1 downto 0);
        i_a_wdat : in std_logic_vector(G_BYTES_PER_ROW*G_BYTE_WIDTH-1 downto 0);
        o_a_rdat : out std_logic_vector(G_BYTES_PER_ROW*G_BYTE_WIDTH-1 downto 0);

        -- Port B
        i_b_clk  : in std_logic := '0';
        i_b_en   : in std_logic := '1';
        i_b_we   : in std_logic_vector(G_BYTES_PER_ROW-1 downto 0);
        i_b_addr : in std_logic_vector(G_DEPTH_L2-1 downto 0);
        i_b_wdat : in std_logic_vector(G_BYTES_PER_ROW*G_BYTE_WIDTH-1 downto 0);
        o_b_rdat : out std_logic_vector(G_BYTES_PER_ROW*G_BYTE_WIDTH-1 downto 0)
    );
end entity;


architecture rtl of mem_gen_example_tdp is
begin

    ram : entity work.memory_generator 
    generic map(
        G_BYTES_PER_ROW => G_BYTES_PER_ROW,
        G_BYTE_WIDTH    => G_BYTE_WIDTH   ,
        G_DEPTH_L2      => G_DEPTH_L2     ,
        G_MEM_STYLE     => G_MEM_STYLE    ,
        G_MEM_INIT      => G_MEM_INIT     ,
        G_A_RD_LATENCY  => G_A_RD_LATENCY ,
        G_B_RD_LATENCY  => G_B_RD_LATENCY ,
        G_A_RD_MODE     => G_A_RD_MODE    ,
        G_B_RD_MODE     => G_B_RD_MODE    
    )
    port map(
        -- Port A
        i_a_clk  => i_a_clk ,
        i_a_en   => i_a_en  ,
        i_a_we   => i_a_we  ,
        i_a_addr => i_a_addr,
        i_a_wdat => i_a_wdat,
        o_a_rdat => o_a_rdat,

        -- Port B
        i_b_clk  => i_b_clk ,
        i_b_en   => i_b_en  ,
        i_b_we   => i_b_we  ,
        i_b_addr => i_b_addr,
        i_b_wdat => i_b_wdat,
        o_b_rdat => o_b_rdat
    );

end architecture;
