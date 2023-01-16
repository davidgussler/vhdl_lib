-- #############################################################################
-- #  << << RISC-V CPU Top Level >> >>
-- # ===========================================================================
-- # File     : rv32_top.vhd
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
-- # Connects the CPU(s) to the cache & memory system. Exposes the external
-- # Wishbone interface to the user. 
-- #
-- #############################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.gen_utils_pkg.all;

entity rv32_top is
    generic (
        G_INT_MEM_SIZE_BYTES : positive                      := 4 * 1024; 
        G_INT_MEM_INIT       : slv_array_t(0 to (G_INT_MEM_SIZE_BYTES/4)-1)(31 downto 0)
            := (others=>(others=>'0'))
    );
    port (
        -- Clock & Reset
        i_clk : in std_logic;
        i_rst : in std_logic;
        
        -- External Instruction Interface
        o_wbi_cyc  : out std_logic;
        o_wbi_stb  : out std_logic;
        o_wbi_adr  : out std_logic_vector(31 downto 0);
        o_wbi_sel  : out std_logic_vector(3 downto 0);
        i_wbi_stl  : in std_logic := '0'; 
        i_wbi_ack  : in std_logic := '0';
        i_wbi_err  : in std_logic := '0';
        i_wbi_rdat : in std_logic_vector(31 downto 0);
        
        -- External Data Interface
        o_wbd_cyc  : out std_logic;
        o_wbd_stb  : out std_logic;
        o_wbd_adr  : out std_logic_vector(31 downto 0);
        o_wbd_wen  : out std_logic;
        o_wbd_sel  : out std_logic_vector(3 downto 0);
        o_wbd_wdat : out std_logic_vector(31 downto 0);
        i_wbd_stl  : in std_logic := '0'; 
        i_wbd_ack  : in std_logic := '0';
        i_wbd_err  : in std_logic := '0';
        i_wbd_rdat : in std_logic_vector(31 downto 0);

        -- Interrupts
        i_ms_irq    : in  std_logic := '0'; 
        i_me_irq    : in  std_logic := '0';
        i_mt_irq    : in  std_logic := '0';

        -- CPU Control
        o_sleep     : out std_logic;
        o_debug     : out std_logic;
        i_db_halt   : in  std_logic := '0';
        i_mtime     : in  std_logic_vector(31 downto 0) := (others=>'0')
    );
end entity;


architecture rtl of rv32_top is

    constant RESET_ADDR        : std_logic_vector(31 downto 0) := x"0000_0000";
    constant INT_MEM_BASE_ADDR : std_logic_vector(31 downto 0) := x"0000_0000";
    constant EXT_MEM_BASE_ADDR : std_logic_vector(31 downto 0) := x"8000_0000";

    -- Bus select constants
    constant INT_MEM : integer := 0;
    constant EXT_MEM : integer := 1;

    -- Represents the width necessary to address G_INT_MEM_SIZE_BYTES
    constant INT_MEM_ADDR_W : integer := clog2(G_INT_MEM_SIZE_BYTES);
    
    -- Since using byte addresses, but each row of internal memory is 4 bytes
    constant INT_MEM_DEPTH_L2 : integer := INT_MEM_ADDR_W-2;


    -- CPU to bus
    signal cpu_iren   : std_logic; 
    signal cpu_iaddr  : std_logic_vector(31 downto 0);
    signal cpu_ifence : std_logic;
    signal cpu_irdat  : std_logic_vector(31 downto 0);
    signal cpu_iack   : std_logic;
    signal cpu_ierr   : std_logic;

    signal cpu_dren   : std_logic;
    signal cpu_dwen   : std_logic;
    signal cpu_dben   : std_logic_vector(3 downto 0);
    signal cpu_daddr  : std_logic_vector(31 downto 0);
    signal cpu_dwdat  : std_logic_vector(31 downto 0);
    signal cpu_dfence : std_logic;
    signal cpu_drdat  : std_logic_vector(31 downto 0);
    signal cpu_dack   : std_logic;
    signal cpu_derr   : std_logic;

    -- Bus to internal and external memory 
    signal per_iren   : std_logic_vector(1 downto 0);
    signal per_iaddr  : std_logic_vector(31 downto 0);
    signal per_irdat  : slv_array_t(0 to 1)(31 downto 0);
    signal per_iack   : std_logic_vector(1 downto 0);
    signal per_ierr   : std_logic_vector(1 downto 0);

    signal per_dren   : std_logic_vector(1 downto 0);
    signal per_dwen   : std_logic_vector(1 downto 0);
    signal per_dben   : std_logic_vector(3 downto 0);
    signal per_daddr  : std_logic_vector(31 downto 0);
    signal per_dwdat  : std_logic_vector(31 downto 0);
    signal per_drdat  : slv_array_t(0 to 1)(31 downto 0);
    signal per_dack   : std_logic_vector(1 downto 0);
    signal per_derr   : std_logic_vector(1 downto 0);



begin

    -- Processor ---------------------------------------------------------------
    -- -------------------------------------------------------------------------
    u_cpu : entity work.rv32_cpu
    generic map (
        G_HART_ID    => x"0000_0000",
        G_RESET_ADDR => RESET_ADDR
    )
    port map (
        -- Clock & Reset
        i_clk       => i_clk,
        i_rst       => i_rst,
        
        -- Instruction  Interface 
        o_iren      => cpu_iren  ,
        o_iaddr     => cpu_iaddr ,
        o_fencei    => cpu_ifence,
        i_irdat     => cpu_irdat ,
        i_iack      => cpu_iack  ,
        i_ierr      => cpu_ierr  ,

        -- Data Interface 
        o_dren      => cpu_dren  ,
        o_dwen      => cpu_dwen  ,
        o_dben      => cpu_dben  ,
        o_daddr     => cpu_daddr ,
        o_dwdat     => cpu_dwdat ,
        o_fence     => cpu_dfence,
        i_drdat     => cpu_drdat ,
        i_dack      => cpu_dack  ,
        i_derr      => cpu_derr  ,

        -- Interrupts
        i_ms_irq    => i_ms_irq,
        i_me_irq    => i_me_irq,
        i_mt_irq    => i_mt_irq,

        -- Other
        o_sleep     => o_sleep  ,
        o_debug     => o_debug  ,
        i_db_halt   => i_db_halt,
        i_mtime     => i_mtime  
    );

    -- Internal Buses ----------------------------------------------------------
    -- -------------------------------------------------------------------------
    u_instr_bus : entity work.rv32_bus
    generic map (
        G_NS          => 2,
        G_S_BASE_ADR  => (EXT_MEM_BASE_ADDR, INT_MEM_BASE_ADDR),
        G_S_ADR_W     => (30, INT_MEM_ADDR_W)
    )
    port map (
        -- Clock & Reset
        i_clk       => i_clk,
        i_rst       => i_rst,

        -- Slave Port (CPU Side)
        i_s_ren      => cpu_iren,
        i_s_wen      => '0',
        i_s_ben      => (others=>'1'),
        i_s_addr     => cpu_iaddr,
        i_s_wdat     => (others=>'0'),
        o_s_rdat     => cpu_irdat, 
        o_s_ack      => cpu_iack, 
        o_s_err      => cpu_ierr,

        -- Master Ports (Peripheral Side)
        o_m_ren      => per_iren,
        o_m_wen      => open,
        o_m_ben      => open,
        o_m_addr     => per_iaddr,
        o_m_wdat     => open,
        i_m_rdat     => per_irdat, 
        i_m_ack      => per_iack, 
        i_m_err      => per_ierr
    );

    u_data_bus : entity work.rv32_bus
    generic map (
        G_NS          => 2,
        G_S_BASE_ADR  => (EXT_MEM_BASE_ADDR, INT_MEM_BASE_ADDR),
        G_S_ADR_W     => (30, INT_MEM_ADDR_W)
    )
    port map (
        -- Clock & Reset
        i_clk       => i_clk,
        i_rst       => i_rst,

        -- Slave Port (CPU Side)
        i_s_ren      => cpu_dren  , 
        i_s_wen      => cpu_dwen  ,
        i_s_ben      => cpu_dben  ,
        i_s_addr     => cpu_daddr ,
        i_s_wdat     => cpu_dwdat ,
        o_s_rdat     => cpu_drdat ,
        o_s_ack      => cpu_dack  ,
        o_s_err      => cpu_derr  ,

        -- Master Ports (Peripheral Side)
        o_m_ren      => per_dren  , 
        o_m_wen      => per_dwen  ,
        o_m_ben      => per_dben  ,
        o_m_addr     => per_daddr ,
        o_m_wdat     => per_dwdat ,
        i_m_rdat     => per_drdat ,
        i_m_ack      => per_dack  ,
        i_m_err      => per_derr  
    );


    -- Internal memory ---------------------------------------------------------
    -- -------------------------------------------------------------------------
    u_internal_mem : entity work.rv32_mem 
    generic map (
        G_DEPTH_L2  => INT_MEM_DEPTH_L2,
        G_MEM_INIT  => G_INT_MEM_INIT
    )
    port map (
        i_clk       => i_clk,
        i_rst       => i_rst,

        i_s_iren    => per_iren(INT_MEM),
        i_s_iaddr   => per_iaddr,
        o_s_irdat   => per_irdat(INT_MEM),
        o_s_iack    => per_iack(INT_MEM),
        o_s_ierr    => per_ierr(INT_MEM),

        i_s_dren    => per_dren(INT_MEM),
        i_s_dwen    => per_dwen(INT_MEM), 
        i_s_dben    => per_dben, 
        i_s_daddr   => per_daddr,
        i_s_dwdat   => per_dwdat, 
        o_s_drdat   => per_drdat(INT_MEM),
        o_s_dack    => per_dack(INT_MEM),
        o_s_derr    => per_derr(INT_MEM)
    );



    -- External Wishbone Interfaces --------------------------------------------
    -- -------------------------------------------------------------------------
    u_wb_instr_if : entity work.rv32_wb_if
    port map (
        i_clk      => i_clk,
        i_rst      => i_rst,

        i_s_ren   => per_iren(EXT_MEM),
        i_s_wen   => '0',
        i_s_ben   => (others=>'1'),
        i_s_addr  => per_iaddr,
        i_s_wdat  => (others=>'0'),
        o_s_rdat  => per_irdat(EXT_MEM), 
        o_s_ack   => per_iack(EXT_MEM), 
        o_s_err   => per_ierr(EXT_MEM),
        
        o_wbm_cyc  => o_wbi_cyc,
        o_wbm_stb  => o_wbi_stb, 
        o_wbm_adr  => o_wbi_adr, 
        o_wbm_wen  => open, 
        o_wbm_sel  => o_wbi_sel, 
        o_wbm_wdat => open,
        i_wbm_stl  => i_wbi_stl, 
        i_wbm_ack  => i_wbi_ack, 
        i_wbm_err  => i_wbi_err, 
        i_wbm_rdat => i_wbi_rdat
    );

    u_wb_data_if : entity work.rv32_wb_if
    port map (
        i_clk      => i_clk,
        i_rst      => i_rst,

        i_s_ren   => per_dren(EXT_MEM),
        i_s_wen   => per_dwen(EXT_MEM), 
        i_s_ben   => per_dben, 
        i_s_addr  => per_daddr,
        i_s_wdat  => per_dwdat, 
        o_s_rdat  => per_drdat(EXT_MEM),
        o_s_ack   => per_dack(EXT_MEM),
        o_s_err   => per_derr(EXT_MEM),

        o_wbm_cyc  => o_wbd_cyc,
        o_wbm_stb  => o_wbd_stb, 
        o_wbm_adr  => o_wbd_adr, 
        o_wbm_wen  => o_wbd_wen, 
        o_wbm_sel  => o_wbd_sel, 
        o_wbm_wdat => o_wbd_wdat,
        i_wbm_stl  => i_wbd_stl, 
        i_wbm_ack  => i_wbd_ack, 
        i_wbm_err  => i_wbd_err, 
        i_wbm_rdat => i_wbd_rdat
    );

end architecture;
