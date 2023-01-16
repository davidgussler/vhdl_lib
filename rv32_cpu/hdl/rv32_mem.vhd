-- #############################################################################
-- #  << RISC-V Internal Memory >>
-- # ===========================================================================
-- # File     : rv32_mem.vhd
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
-- # Instantiates a synchronous dual-port BRAM that responds in one cycle and 
-- # provides a wrapper for the internal CPU bus interface. 
-- #
-- #############################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.gen_utils_pkg.all;

entity rv32_mem is
    generic (
        G_DEPTH_L2 : positive := 10; 
        G_MEM_INIT     : slv_array_t(0 to (2**G_DEPTH_L2)-1)(31 downto 0)
            := (others=>(others=>'0'))
    );
    port (
        -- Clock & Reset
        i_clk      : in std_logic;
        i_rst      : in std_logic;

        -- Instruction Port
        i_s_iren      : in  std_logic;
        i_s_iaddr     : in  std_logic_vector(31 downto 0);
        o_s_irdat     : out std_logic_vector(31 downto 0);
        o_s_iack      : out std_logic; 
        o_s_ierr      : out std_logic;

        -- Data Port
        i_s_dren      : in  std_logic;
        i_s_dwen      : in  std_logic;
        i_s_dben      : in  std_logic_vector(3 downto 0); 
        i_s_daddr     : in  std_logic_vector(31 downto 0);
        i_s_dwdat     : in  std_logic_vector(31 downto 0);
        o_s_drdat     : out std_logic_vector(31 downto 0);
        o_s_dack      : out std_logic; 
        o_s_derr      : out std_logic
    );
end entity rv32_mem;


architecture rtl of rv32_mem is

begin

    -- Instantiate Memory ------------------------------------------------------
    -- -------------------------------------------------------------------------
    u_internal_ram : entity work.memory_generator 
    generic map(
        G_BYTES_PER_ROW => 4,
        G_BYTE_WIDTH    => 8,
        G_DEPTH_L2      => G_DEPTH_L2,
        G_MEM_STYLE     => "",
        G_MEM_INIT      => G_MEM_INIT,
        G_A_RD_LATENCY  => 1,
        G_B_RD_LATENCY  => 1,
        G_A_RD_MODE     => 1,
        G_B_RD_MODE     => 1    
    )
    port map(
        -- Port A (Instruction fetch)
        i_a_clk  => i_clk,
        i_a_addr => i_s_iaddr((G_DEPTH_L2+2)-1 downto 2),
        o_a_rdat => o_s_irdat,

        -- Port B (Data access)
        i_b_clk  => i_clk,
        i_b_we   => i_s_dwen and i_s_dben,
        i_b_addr => i_s_daddr((G_DEPTH_L2+2)-1 downto 2),
        i_b_wdat => i_s_dwdat,
        o_b_rdat => o_s_drdat
    );


    -- Responses ---------------------------------------------------------------
    -- -------------------------------------------------------------------------
    o_s_ierr <= '0';
    o_s_derr <= '0';

    sp_iack : process (i_clk) begin
        if rising_edge(i_clk) then
            if (i_rst) then
                o_s_iack <= '0';
                o_s_dack <= '0';
            else
                o_s_iack <= i_s_iren;
                o_s_dack <= i_s_dren or i_s_dwen;
            end if;
        end if;
    end process;

end architecture;
