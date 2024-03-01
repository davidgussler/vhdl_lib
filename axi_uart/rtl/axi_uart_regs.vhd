-- #############################################################################
-- #  << Wishbone UART Registers >>
-- # ===========================================================================
-- # File     : wb_uart_regs.vhd
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
-- # This IP is register compatible with the Xilinx Uart-Lite core. As such, 
-- # it should work with all Xilinx software deisgned for their proprietary core.
-- # 
-- #############################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.gen_utils_pkg.all;

entity wb_uart_regs is
    generic (
        G_DATA_WIDTH   : positive range 5 to 8 := 8
    );
    port (
        i_clk : in std_logic;
        i_rst : in std_logic;

        -- AXI4-Lite Slave
        i_s_axil : in  axil_req_t;
        o_s_axil : out axil_resp_t;

        -- Register Breakout
        i_rx_fifo_data     : in  std_logic_vector(G_DATA_WIDTH-1 downto 0);
        i_rx_fifo_valid    : in  std_logic;
        i_rx_fifo_full     : in  std_logic;
        i_tx_fifo_empty    : in  std_logic;
        i_tx_fifo_full     : in  std_logic;
        i_intr_en          : in  std_logic;
        i_overrun_err      : in  std_logic;
        i_frame_err        : in  std_logic;
        i_parity_err       : in  std_logic;
        o_tx_fifo_data     : out std_logic_vector(G_DATA_WIDTH-1 downto 0);
        o_rst_tx_fifo      : out std_logic;
        o_rst_rx_fifo      : out std_logic;
        o_en_intr          : out std_logic;
        o_tx_fifo_wr_pulse : out std_logic;
        o_rx_fifo_rd_pulse : out std_logic;
        o_clear_err_pulse  : out std_logic
    );
end entity;

architecture rtl of wb_uart_regs is

    -- regs Constants & Signals ----------------------------------------------
    -- =========================================================================

    -- Name Register Indexes ---------------------------------------------------
    -- -------------------------------------------------------------------------
    constant RX_FIFO : natural := 0;
    constant TX_FIFO : natural := 1;
    constant STS_REG : natural := 2;
    constant CTL_REG : natural := 3;

    -- Register Bit-fields -----------------------------------------------------
    -- -------------------------------------------------------------------------
    subtype  FIFO_FLD is natural range G_DATA_WIDTH-1 downto 0;
    constant STS_RX_FIFO_DATA_VALID : integer := 0;
    constant STS_RX_FIFO_FULL       : integer := 1;
    constant STS_TX_FIFO_EMPTY      : integer := 2;
    constant STS_TX_FIFO_FULL       : integer := 3;
    constant STS_INTR_ENABLED       : integer := 4;
    constant STS_OVERRUN_ERR        : integer := 5;
    constant STS_FRAME_ERR          : integer := 6;
    constant STS_PARITY_ERR         : integer := 7;

    constant CTL_RST_TX_FIFO        : integer := 0;
    constant CTL_RST_RX_FIFO        : integer := 1;
    constant CTL_ENABLE_INTR        : integer := 4;


    -- regs generics --------------------------------------------------------
    -- -------------------------------------------------------------------------
    constant NUM_REGS     : positive := 4;
    constant NUM_ADR_BITS : positive := 4;

    constant REG_ADR :
        slv_array_t(NUM_REGS-1 downto 0)(NUM_ADR_BITS-1 downto 0) :=
    (
        RX_FIFO => X"0",
        TX_FIFO => X"4",
        STS_REG => X"8",
        ctl_REG => X"C"
    );

    constant REG_RST_VAL :
        slv_array_t(NUM_REGS-1 downto 0)((2 ** DAT_WIDTH_L2)-1 downto 0) :=
    (
        others  => (others=>'0')
    );

    signal regs_sts : slv_array_t(NUM_REGS-1 downto 0)(31 downto 0) := (others => (others => '0') ) ;
    signal regs_ctl : slv_array_t(NUM_REGS-1 downto 0)(31 downto 0);
    signal rd_pulse : std_logic_vector(NUM_REGS-1 downto 0);
    signal wr_pulse : std_logic_vector(NUM_REGS-1 downto 0);


    signal bus_req : bus_req_t; 
    signal bus_rsp : bus_resp_t;

begin

    axil_to_bus_inst : entity work.axil_to_bus
    port map (
        i_clk => i_clk,
        i_rst => i_rst,
        i_s_axil => i_s_axil,
        o_s_axil => o_s_axil,
        i_m_bus => bus_rsp,
        o_m_bus => bus_req
    );

    reg_bank_inst : entity work.reg_bank
    generic map (
      G_NUM_REGS  => NUM_REGS,
      G_ADDR_BITS => NUM_ADR_BITS,
      G_ADDRS     => REG_ADR,
      G_RST_VALS  => REG_RST_VAL
    )
    port map (
      i_clk => i_clk,
      i_rst => i_rst,
      i_s_bus => bus_req,
      o_s_bus => bus_rsp,
      o_ctl => regs_ctl,
      i_sts => regs_sts,
      o_wr => wr_pulse,
      o_rd => rd_pulse
    );
    

    -- Signal breakout ---------------------------------------------------------
    -- -------------------------------------------------------------------------
    regs_sts(RX_FIFO)(FIFO_FLD)               <= i_rx_fifo_data;
    regs_sts(STS_REG)(STS_RX_FIFO_DATA_VALID) <= i_rx_fifo_valid;
    regs_sts(STS_REG)(STS_RX_FIFO_FULL      ) <= i_rx_fifo_full;
    regs_sts(STS_REG)(STS_TX_FIFO_EMPTY     ) <= i_tx_fifo_empty;
    regs_sts(STS_REG)(STS_TX_FIFO_FULL      ) <= i_tx_fifo_full;
    regs_sts(STS_REG)(STS_INTR_ENABLED      ) <= i_intr_en;
    regs_sts(STS_REG)(STS_OVERRUN_ERR       ) <= i_overrun_err;
    regs_sts(STS_REG)(STS_FRAME_ERR         ) <= i_frame_err;
    regs_sts(STS_REG)(STS_PARITY_ERR        ) <= i_parity_err;

    o_tx_fifo_data <= regs_ctl(TX_FIFO)(FIFO_FLD);
    o_rst_tx_fifo  <= regs_ctl(CTL_REG)(CTL_RST_TX_FIFO);
    o_rst_rx_fifo  <= regs_ctl(CTL_REG)(CTL_RST_RX_FIFO);
    o_en_intr      <= regs_ctl(CTL_REG)(CTL_ENABLE_INTR);

    o_tx_fifo_wr_pulse <= wr_pulse(TX_FIFO);
    o_rx_fifo_rd_pulse <= rd_pulse(RX_FIFO);
    o_clear_err_pulse <= rd_pulse(STS_REG);

end architecture;
