-- #############################################################################
-- #  -<< Machine Time >>-
-- # ===========================================================================
-- # Copyright 2022, David Gusser
-- # ===========================================================================
-- # File     : wb_mtime.vhd
-- # Author   : David Gussler - davidnguss@gmail.com 
-- # Language : VHDL '08
-- # ===========================================================================
-- # 
-- #############################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.gen_utils_pkg.all;

entity wb_mtime is
    port (        
        --  Clock & Reset
        i_clk : in std_logic;
        i_rst : in std_logic;

        -- Wishbone Slave Interface
        i_wbs_cyc  : in  std_logic;
        i_wbs_stb  : in  std_logic;
        i_wbs_adr  : in  std_logic_vector(7 downto 0);
        i_wbs_wen  : in  std_logic;
        i_wbs_sel  : in  std_logic_vector(3 downto 0);
        i_wbs_wdat : in  std_logic_vector(31 downto 0);
        o_wbs_stl  : out std_logic; 
        o_wbs_ack  : out std_logic;
        o_wbs_err  : out std_logic;
        o_wbs_rdat : out std_logic_vector(31 downto 0);

        -- Mtime Interrupt 
        o_mt_irq   : out std_logic
    );
end entity wb_mtime;

architecture rtl of wb_mtime is
    -- =========================================================================
    -- Wishbone Constants & Signals ============================================
    -- =========================================================================

    -- Register Indexes --------------------------------------------------------
    -- -------------------------------------------------------------------------
    constant RW_MTIME_SET : natural := 0;
    constant RO_MTIME     : natural := 1;
    constant RW_MTIME_CMP : natural := 2;

    -- Set Generics ------------------------------------------------------------
    -- -------------------------------------------------------------------------
    constant DAT_WIDTH_L2 : positive := 5;
    constant NUM_REGS     : positive := 3;
    constant NUM_ADR_BITS : positive := 4;
    constant EN_ASSERT    : boolean  := TRUE;

    constant DAT_WIDTH : positive := 2 ** DAT_WIDTH_L2;

    -- When a RO and RW reigster share the same address, the RO_REG is always
    -- the one returned by wb_regs. Doing this makes it look like (from a 
    -- bus-master's perspective) there is only one RW register, but this special
    -- register can be written by both the bus master and by hardware. Therefore
    -- the last value written by the bus master is not guarenteed to be returned 
    -- on the next read. This lets us set the counter at any time via software 
    -- but also increment that value in hardware. 
    constant REG_ADR : slv_array_t(NUM_REGS-1 downto 0)(NUM_ADR_BITS-1 downto 0) := (
        RW_MTIME_SET => x"0",
        RO_MTIME     => x"0",
        RW_MTIME_CMP => x"4"
    );

    constant REG_TYPE : regtype_array_t(NUM_REGS-1 downto 0) := (
        RW_MTIME_SET => RW_REG,
        RO_MTIME     => RO_REG,
        RW_MTIME_CMP => RW_REG
    );

    constant REG_RST_VAL : slv_array_t(NUM_REGS-1 downto 0)(DAT_WIDTH-1 downto 0) := (
        RW_MTIME_SET => (others=>'0'),
        RO_MTIME     => (others=>'0'),
        RW_MTIME_CMP => (others=>'1')
    );

    constant REG_USED_BITS : slv_array_t(NUM_REGS-1 downto 0)(DAT_WIDTH-1 downto 0) := (
        others => (others=>'1')
    );

    signal regs_sts  : slv_array_t(NUM_REGS-1 downto 0)(DAT_WIDTH-1 downto 0);
    signal regs_ctrl : slv_array_t(NUM_REGS-1 downto 0)(DAT_WIDTH-1 downto 0);
    signal wr_pulse  : std_logic_vector(NUM_REGS-1 downto 0);

    signal mtime_count    : unsigned(DAT_WIDTH-1 downto 0);
    signal mtime_wr_val   : unsigned(DAT_WIDTH-1 downto 0);
    signal mtime_wr_pulse : std_logic; 
    signal mtime_cmp      : unsigned(DAT_WIDTH-1 downto 0);

begin

    -- Wishbone Register Interface ---------------------------------------------
    -- -------------------------------------------------------------------------
    u_wb_regs : entity work.wb_regs
    generic map (
        G_DAT_WIDTH_L2   => DAT_WIDTH_L2,
        G_NUM_REGS       => NUM_REGS,
        G_NUM_ADR_BITS   => NUM_ADR_BITS,
        G_REG_ADR        => REG_ADR,
        G_REG_TYPE       => REG_TYPE,
        G_REG_RST_VAL    => REG_RST_VAL,
        G_REG_USED_BITS  => REG_USED_BITS,
        G_EN_ASSERT      => EN_ASSERT
    )
    port map (
        i_clk => i_clk,
        i_rst => i_rst,

        -- Wishbone Slave Interface
        i_wbs_cyc  => i_wbs_cyc ,
        i_wbs_stb  => i_wbs_stb ,
        i_wbs_adr  => i_wbs_adr ,
        i_wbs_wen  => i_wbs_wen ,
        i_wbs_sel  => i_wbs_sel ,
        i_wbs_wdat => i_wbs_wdat,
        o_wbs_stl  => o_wbs_stl ,
        o_wbs_ack  => o_wbs_ack ,
        o_wbs_err  => o_wbs_err ,
        o_wbs_rdat => o_wbs_rdat,

        -- Register Data Interface
        i_regs => regs_sts ,
        o_regs => regs_ctrl,

        -- Register R/W Interface
        o_rd_pulse => open,
        o_wr_pulse => wr_pulse

    );

    regs_sts(RO_MTIME) <= std_logic_vector(mtime_count);   

    mtime_wr_val   <= unsigned(regs_ctrl(RW_MTIME_SET));
    mtime_wr_pulse <= wr_pulse(RW_MTIME_SET);
    mtime_cmp      <= unsigned(regs_ctrl(RW_MTIME_CMP));


    -- Counter & Interrupt -----------------------------------------------------
    -- -------------------------------------------------------------------------
    process (i_clk)
    begin
        if rising_edge(i_clk) then
            if (i_rst) then
                mtime_count <= (others=>'0'); 
                o_mt_irq <= '0';
            else
                if (mtime_count >= mtime_cmp) then
                    o_mt_irq <= '1'; 
                else
                    o_mt_irq <= '0'; 
                end if; 
                
                if (mtime_wr_pulse) then
                    mtime_count <= mtime_wr_val;
                else
                    mtime_count <= mtime_count + 1; 
                end if; 
            end if;       
        end if;
    end process;
end architecture;
