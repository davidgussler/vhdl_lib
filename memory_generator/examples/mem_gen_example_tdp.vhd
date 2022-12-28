-- #############################################################################
-- #  << Memory Generator - True Dual Port RAM Example >>
-- # ===========================================================================
-- # File     : mem_gen_example_tdp.vhd
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
-- # Example using the full features of the memory generator.
-- # True dual-port RAM with independent clocks
-- #
-- #############################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.gen_utils_pkg.all;

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

    u_ram : entity work.memory_generator 
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
