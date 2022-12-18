-- #############################################################################
-- #  -<< RISC-V CPU Top Level >>-
-- # ===========================================================================
-- # Copyright 2022, David Gusser
-- # ===========================================================================
-- # File     : rv32_top.vhd
-- # Author   : David Gussler - david.gussler@proton.me
-- # Language : VHDL '08
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
        G_USE_INT_MEM        : boolean                       := TRUE; 
        G_INT_MEM_BASE_ADDR  : std_logic_vector(31 downto 0) := x"0000_0000";
        G_INT_MEM_SIZE_BYTES : positive                      := 4 * 1024; 
        G_INT_MEM_INIT       : slv_array_t(0 to (G_INT_MEM_SIZE_BYTES/4)-1)(31 downto 0)
            := (others=>(others=>'0'))
    );
    port (
        -- Clock & Reset
        i_clk : in std_logic;
        i_rst : in std_logic;
        
        -- CPU Control
        o_sleep     : out std_logic;
        o_debug     : out std_logic;
        i_db_halt   : in  std_logic := '0';
        i_mtime     : in  std_logic_vector(31 downto 0) := (others=>'0');

        -- Interrupts
        i_ms_irq    : in  std_logic := '0'; 
        i_me_irq    : in  std_logic := '0';
        i_mt_irq    : in  std_logic := '0';

        -- Instruction Interface
        o_wbi_cyc  : out std_logic;
        o_wbi_stb  : out std_logic;
        o_wbi_adr  : out std_logic_vector(31 downto 0);
        o_wbi_sel  : out std_logic_vector(3 downto 0);
        i_wbi_stl  : in std_logic := '0'; 
        i_wbi_ack  : in std_logic := '0';
        i_wbi_err  : in std_logic := '0';
        i_wbi_rdat : in std_logic_vector(31 downto 0);
        
        -- Data Interface
        o_wbd_cyc  : out std_logic;
        o_wbd_stb  : out std_logic;
        o_wbd_adr  : out std_logic_vector(31 downto 0);
        o_wbd_wen  : out std_logic;
        o_wbd_sel  : out std_logic_vector(3 downto 0);
        o_wbd_wdat : out std_logic_vector(31 downto 0);
        i_wbd_stl  : in std_logic := '0'; 
        i_wbd_ack  : in std_logic := '0';
        i_wbd_err  : in std_logic := '0';
        i_wbd_rdat : in std_logic_vector(31 downto 0)  
    );
end entity;


architecture rtl of rv32_top is
    constant RESET_ADDR : std_logic_vector(31 downto 0) := x"0000_0000";
    constant TRAP_ADDR  : std_logic_vector(31 downto 0) := x"0000_0800";

    signal iren     : std_logic; 
    signal iaddr    : std_logic_vector(31 downto 0);
    signal fencei   : std_logic; 
    signal irdat    : std_logic_vector(31 downto 0);
    signal istall   : std_logic; 
    signal ierror   : std_logic; 

    signal dren     : std_logic; 
    signal dwen     : std_logic; 
    signal dben     : std_logic_vector(3 downto 0);
    signal daddr    : std_logic_vector(31 downto 0);
    signal fence    : std_logic; 
    signal dwdat    : std_logic_vector(31 downto 0);
    signal drdat    : std_logic_vector(31 downto 0);
    signal dstall   : std_logic; 
    signal derror   : std_logic; 

begin

    u_cpu : entity work.rv32_cpu
    generic map (
        G_HART_ID    => x"0000_0000",
        G_RESET_ADDR => RESET_ADDR,
        G_TRAP_ADDR  => TRAP_ADDR
    )
    port map (
        -- Clock & Reset
        i_clk       => i_clk,
        i_rst       => i_rst,
        
        -- Instruction  Interface 
        o_iren      => iren  ,
        o_iaddr     => iaddr ,
        o_fencei    => fencei,
        i_irdat     => irdat ,
        i_istall    => istall,
        i_ierror    => ierror,

        -- Data Interface 
        o_dren      => dren  ,
        o_dwen      => dwen  ,
        o_dben      => dben  ,
        o_daddr     => daddr ,
        o_fence     => fence,
        o_dwdat     => dwdat ,
        i_drdat     => drdat ,
        i_dstall    => dstall,
        i_derror    => derror,

        -- Interrupts
        i_ms_irq    => i_ms_irq ,
        i_me_irq    => i_me_irq ,
        i_mt_irq    => i_mt_irq,

        -- Other
        o_sleep     => o_sleep  ,
        o_debug     => o_debug  ,
        i_db_halt   => i_db_halt,
        i_mtime     => i_mtime  
    );


    u_memory : entity work.rv32_mem
    generic map (
        G_USE_INT_MEM        => G_USE_INT_MEM        ,
        G_INT_MEM_BASE_ADDR  => G_INT_MEM_BASE_ADDR  ,
        G_INT_MEM_SIZE_BYTES => G_INT_MEM_SIZE_BYTES ,
        G_INT_MEM_INIT       => G_INT_MEM_INIT
    )
    port map (
        -- Clock & Reset
        i_clk      => i_clk,
        i_rst      => i_rst,

        -- Instruction port from cpu
        i_iren     => iren  ,
        i_iaddr    => iaddr ,
        i_fencei   => fencei,
        o_irdat    => irdat ,
        o_istall   => istall,
        o_ierror   => ierror,

        -- Data port from cpu
        i_dren     => dren  ,
        i_dwen     => dwen  ,
        i_dsel     => dben  ,
        i_daddr    => daddr ,
        i_fence   => fence,
        i_dwdat    => dwdat ,
        o_drdat    => drdat ,
        o_dstall   => dstall,
        o_derror   => derror,

        -- Instruction port to external interface
        o_wbi_cyc  => o_wbi_cyc ,  
        o_wbi_stb  => o_wbi_stb , 
        o_wbi_adr  => o_wbi_adr , 
        o_wbi_sel  => o_wbi_sel , 
        i_wbi_stl  => i_wbi_stl , 
        i_wbi_ack  => i_wbi_ack , 
        i_wbi_err  => i_wbi_err , 
        i_wbi_rdat => i_wbi_rdat,
        
        -- Data port to external interface
        o_wbd_cyc  => o_wbd_cyc ,
        o_wbd_stb  => o_wbd_stb ,
        o_wbd_adr  => o_wbd_adr ,
        o_wbd_wen  => o_wbd_wen ,
        o_wbd_sel  => o_wbd_sel ,
        o_wbd_wdat => o_wbd_wdat,
        i_wbd_stl  => i_wbd_stl ,
        i_wbd_ack  => i_wbd_ack ,
        i_wbd_err  => i_wbd_err ,
        i_wbd_rdat => i_wbd_rdat
    );

end architecture;
