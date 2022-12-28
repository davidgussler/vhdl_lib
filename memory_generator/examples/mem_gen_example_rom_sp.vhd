-- #############################################################################
-- #  << Memory Generator - Single Port ROM Example >>
-- # ===========================================================================
-- # File     : mem_gen_example_rom_sp.vhd
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
-- # Single port ROM without an enable signal
-- #
-- #############################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.gen_utils_pkg.all;

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

    u_rom : entity work.memory_generator
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
