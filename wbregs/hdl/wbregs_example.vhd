
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.gen_utils_pkg.all;


entity wbregs_example is 
    port(
        i_clk : in std_logic;
        i_rst : in std_logic;

        -- Wishbone Slave Interface
        i_wbs_cyc : in  std_logic;
        i_wbs_stb : in  std_logic;
        i_wbs_adr : in  std_logic_vector(7 downto 0);
        i_wbs_wen : in  std_logic;
        i_wbs_sel : in  std_logic_vector(3 downto 0);
        i_wbs_dat : in  std_logic_vector(31 downto 0);
        o_wbs_stl : out std_logic; 
        o_wbs_ack : out std_logic;
        o_wbs_err : out std_logic;
        o_wbs_dat : out std_logic_vector(31 downto 0);

        -- Custom module interface
        i_in_bit0  : in  std_logic;
        i_in_vec0  : in  std_logic_vector(15 downto 0);
        i_in_vec1  : in  std_logic_vector(31 downto 0);
        o_out_bit0 : out std_logic;
        o_out_vec0 : out std_logic_vector(7 downto 0);
        o_out_vec1 : out std_logic_vector(31 downto 0);

        o_rd_pulse : out std_logic_vector(5 downto 0);
        o_wr_pulse : out std_logic_vector(5 downto 0)

    );
end wbregs_example;


architecture rtl of wbregs_example is

    -- wbregs Constants & Signals ----------------------------------------------
    -- =========================================================================

    -- Name Register Indexes ---------------------------------------------------
    -- -------------------------------------------------------------------------
    constant REG0_RO : natural := 0;
    constant REG1_RO : natural := 1;
    constant REG2_RO : natural := 2;
    constant REG3_RW : natural := 3;
    constant REG4_RW : natural := 4;
    constant REG5_RW : natural := 5;

    -- Register Sub-ranges -----------------------------------------------------
    -- -------------------------------------------------------------------------
    constant REG0_BIT0 : natural := 0;
    subtype  REG1_VEC0 is natural range 31 downto 16;
    subtype  REG2_VEC0 is natural range 31 downto 0;
    constant REG3_BIT0 : natural := 8;
    subtype  REG4_VEC0 is natural range 15 downto 8;
    subtype  REG5_VEC0 is natural range 31 downto 0;

    -- wbregs generics ---------------------------------------------------------
    -- -------------------------------------------------------------------------
    constant C_DAT_WIDTH_L2 : positive := 5;
    constant C_NUM_REGS       : positive := 6;
    constant C_NUM_ADR_BITS   : positive := 8;

    constant C_REG_ADR        :
        slv_array_t(C_NUM_REGS-1 downto 0)(C_NUM_ADR_BITS-1 downto 0) :=
        (
            REG0_RO => X"00",
            REG1_RO => X"04",
            REG2_RO => X"08",
            REG3_RW => X"0C",
            REG4_RW => X"10",
            REG5_RW => X"14"
        );

    constant C_REG_TYPE       : regtype_array_t(C_NUM_REGS-1 downto 0) :=
        (
            REG0_RO => RO_REG,
            REG1_RO => RO_REG,
            REG2_RO => RO_REG,
            REG3_RW => RW_REG,
            REG4_RW => RW_REG,
            REG5_RW => RW_REG
        );

    constant C_REG_RST_VAL    :
        slv_array_t(C_NUM_REGS-1 downto 0)((2 ** C_DAT_WIDTH_L2)-1 downto 0) :=
        (
            REG0_RO => X"0000_0010",
            REG1_RO => X"0000_0010",
            REG2_RO => X"0000_0010",
            REG3_RW => X"0000_0010",
            REG4_RW => X"0000_0010",
            REG5_RW => X"0000_0010"
        );

    constant C_REG_USED_BITS  :
        slv_array_t(C_NUM_REGS-1 downto 0)((2 ** C_DAT_WIDTH_L2)-1 downto 0) :=
        (
            REG0_RO => X"0000_0001",
            REG1_RO => X"FFFF_0000",
            REG2_RO => X"FFFF_FFFF",
            REG3_RW => X"0000_0100",
            REG4_RW => X"0000_FF00",
            REG5_RW => X"FFFF_FFFF"
        );


    constant C_EN_ASSERT      : boolean := TRUE;

    signal regs_in  : slv_array_t(C_NUM_REGS-1 downto 0)((2 ** C_DAT_WIDTH_L2)-1 downto 0);
    signal regs_out : slv_array_t(C_NUM_REGS-1 downto 0)((2 ** C_DAT_WIDTH_L2)-1 downto 0);
    signal rd_stb : std_logic_vector(C_NUM_REGS-1 downto 0);
    signal wr_stb : std_logic_vector(C_NUM_REGS-1 downto 0);

    signal r0_b0 : std_logic;
    signal r1_v0 : std_logic_vector(15 downto 0);
    signal r2_v0 : std_logic_vector(31 downto 0);
    signal r3_b0 : std_logic;
    signal r4_v0 : std_logic_vector(7 downto 0);
    signal r5_v0 : std_logic_vector(31 downto 0);


begin

    -- Instantiate Register Interface ------------------------------------------
    -- -------------------------------------------------------------------------
    register_interface : entity work.wbregs(rtl)
    generic map (
        G_DAT_WIDTH_L2 => C_DAT_WIDTH_L2,
        G_NUM_REGS       => C_NUM_REGS,
        G_NUM_ADR_BITS   => C_NUM_ADR_BITS,
        G_REG_ADR        => C_REG_ADR,
        G_REG_TYPE       => C_REG_TYPE,
        G_REG_RST_VAL    => C_REG_RST_VAL,
        G_REG_USED_BITS  => C_REG_USED_BITS,
        G_EN_ASSERT      => C_EN_ASSERT
    )
    port map (
        i_clk => i_clk,
        i_rst => i_rst,

        -- Wishbone Slave Interface
        i_wbs_cyc => i_wbs_cyc,
        i_wbs_stb => i_wbs_stb,
        i_wbs_adr => i_wbs_adr,
        i_wbs_wen => i_wbs_wen,
        i_wbs_sel => i_wbs_sel,
        i_wbs_dat => i_wbs_dat,
        o_wbs_stl => o_wbs_stl,
        o_wbs_ack => o_wbs_ack,
        o_wbs_err => o_wbs_err,
        o_wbs_dat => o_wbs_dat,

        -- Register Interface
        i_regs => regs_in,
        o_regs => regs_out,

        -- Register R/W Interface
        o_rd_stb => rd_stb,
        o_wr_stb => wr_stb

    );

    regs_in(REG0_RO)(REG0_BIT0) <= r0_b0;
    regs_in(REG1_RO)(REG1_VEC0) <= r1_v0;
    regs_in(REG2_RO)(REG2_VEC0) <= r2_v0;

    r3_b0 <= regs_out(REG3_RW)(REG3_BIT0);
    r4_v0 <= regs_out(REG4_RW)(REG4_VEC0);
    r5_v0 <= regs_out(REG5_RW)(REG5_VEC0);


    -- Connect Register Interface to Standalone Design -------------------------
    -- -------------------------------------------------------------------------
    r0_b0 <= i_in_bit0;
    r1_v0 <= i_in_vec0;
    r2_v0 <= i_in_vec1;

    o_out_bit0 <= r3_b0;
    o_out_vec0 <= r4_v0;
    o_out_vec1 <= r5_v0;

    o_rd_pulse <= rd_stb;
    o_wr_pulse <= wr_stb; 

end architecture; 
