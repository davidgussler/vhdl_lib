-- #############################################################################
-- #  << Wishbone UART >>
-- # ===========================================================================
-- # File     : wb_uart.vhd
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

entity wb_uart is
    generic (
        G_CLK_RATE_HZ : positive              := 125000000; 
        G_BAUD_RATE   : positive              := 115200;
        G_DATA_WIDTH  : positive range 5 to 8 := 8;
        G_PARITY      : integer range 0 to 1  := 0;
        G_PARITY_EO   : std_logic             := '0'
    );
    port (
        i_clk : in std_logic;
        i_rst : in std_logic;

        -- Wishbone Slave Interface
        i_wbs_cyc : in  std_logic;
        i_wbs_stb : in  std_logic;
        i_wbs_adr : in  std_logic_vector(3 downto 0);
        i_wbs_wen : in  std_logic;
        i_wbs_sel : in  std_logic_vector(3 downto 0);
        i_wbs_dat : in  std_logic_vector(31 downto 0);
        o_wbs_stl : out std_logic; 
        o_wbs_ack : out std_logic;
        o_wbs_err : out std_logic;
        o_wbs_dat : out std_logic_vector(31 downto 0);

        -- UART Interface 
        i_uart_rx  : in  std_logic;
        o_uart_tx  : out std_logic; 

        o_uart_irq : out std_logic
    );
end entity;

architecture rtl of wb_uart is
    signal sync_uart_rx : std_logic;
    signal filtered_uart_rx : std_logic;

    signal rx_fifo_data     : std_logic_vector(G_DATA_WIDTH-1 downto 0);
    signal rx_fifo_empty    : std_logic;
    signal rx_fifo_full     : std_logic;
    signal tx_fifo_empty    : std_logic;
    signal tx_fifo_full     : std_logic;
    signal en_intr          : std_logic;
    signal overrun_err      : std_logic;
    signal frame_err        : std_logic;
    signal parity_err       : std_logic;
    signal tx_fifo_data     : std_logic_vector(G_DATA_WIDTH-1 downto 0);
    signal rst_tx_fifo      : std_logic;
    signal rst_rx_fifo      : std_logic;
    signal intr_en          : std_logic;
    signal tx_fifo_wr_pulse : std_logic;
    signal rx_fifo_rd_pulse : std_logic;
    signal clear_err_pulse : std_logic;

    signal overrun_err_lat  : std_logic;
    signal frame_err_lat    : std_logic;
    signal parity_err_lat   : std_logic;

    signal rx_axis_tdata  : std_logic_vector(G_DATA_WIDTH-1 downto 0);
    signal rx_axis_tvalid : std_logic;
    signal rx_axis_tready : std_logic;
    signal tx_axis_tdata  : std_logic_vector(G_DATA_WIDTH-1 downto 0);
    signal tx_axis_tvalid : std_logic;
    signal tx_axis_tready : std_logic;

begin

    u_wb_uart_regs : entity work.wb_uart_regs
    generic map (
        G_DATA_WIDTH => G_DATA_WIDTH
    )
    port map (
        i_clk => i_clk,
        i_rst => i_rst,

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

        i_rx_fifo_data     => rx_fifo_data,
        i_rx_fifo_valid    => not rx_fifo_empty,
        i_rx_fifo_full     => rx_fifo_full,
        i_tx_fifo_empty    => tx_fifo_empty,
        i_tx_fifo_full     => tx_fifo_full,
        i_intr_en          => intr_en,
        i_overrun_err      => overrun_err,
        i_frame_err        => frame_err,
        i_parity_err       => parity_err,
        o_tx_fifo_data     => tx_fifo_data,
        o_rst_tx_fifo      => rst_tx_fifo,
        o_rst_rx_fifo      => rst_rx_fifo,
        o_en_intr          => en_intr,
        o_tx_fifo_wr_pulse => tx_fifo_wr_pulse,
        o_rx_fifo_rd_pulse => rx_fifo_rd_pulse,
        o_clear_err_pulse => clear_err_pulse
    );


    -- Rx Synchronizer
    u_sync_bit : entity work.sync_bit
    generic map (
      G_N_FLOPS => 2,
      G_RST_VAL => '0'
    )
    port map (
      i_clk => i_clk,
      i_rst => i_rst,
      i_async => i_uart_rx,
      o_sync => sync_uart_rx
    );
  
    -- Rx Filter
    u_glitch_filter : entity work.glitch_filter
    generic map (
        G_STABLE_CLKS => 16,
        G_RST_VAL => '0'
    )
    port map (
        i_clk => i_clk,
        i_rst => i_rst,
        i_glitchy => sync_uart_rx,
        o_filtered => filtered_uart_rx
    );


    u_uart : entity work.uart
    generic map (
        G_CLK_FREQ_HZ => G_CLK_RATE_HZ,
        G_BAUD_RATE   => G_BAUD_RATE,
        G_OS_RATE     => 16,
        G_DATA_WIDTH  => G_DATA_WIDTH,
        G_PARITY      => G_PARITY,
        G_PARITY_EO   => G_PARITY_EO
    )
    port map (
        i_clk => i_clk,
        i_rst => i_rst,

        o_m_axis_tdata  => rx_axis_tdata,
        o_m_axis_tvalid => rx_axis_tvalid,
        i_m_axis_tready => not rx_fifo_full,

        i_s_axis_tdata  => tx_axis_tdata,
        i_s_axis_tvalid => not tx_fifo_empty,
        o_s_axis_tready => tx_axis_tready,

        i_uart_rx => i_uart_rx,
        o_uart_tx => o_uart_tx,

        o_parity_err => parity_err_lat,
        o_frame_err  => frame_err_lat,
        o_dropped_rx_err => overrun_err_lat
    );

    u_tx_fifo : entity work.fifo
    generic map (
        G_WIDTH     => G_DATA_WIDTH,
        G_DEPTH_L2  => 4,
        G_MEM_STYLE => "",
        G_FALLTHRU  => TRUE
    )
    port map (
        i_clk => i_clk,
        i_rst => i_rst,

        i_wr   => tx_fifo_wr_pulse,
        i_dat  => tx_fifo_data,
        o_full => tx_fifo_full,

        i_rd    => tx_axis_tready,
        o_dat   => tx_axis_tdata,
        o_empty => tx_fifo_empty
    );

    u_rx_fifo : entity work.fifo
    generic map (
        G_WIDTH     => G_DATA_WIDTH,
        G_DEPTH_L2  => 4,
        G_MEM_STYLE => "",
        G_FALLTHRU  => TRUE
    )
    port map (
        i_clk => i_clk,
        i_rst => i_rst,

        i_wr   => rx_axis_tvalid,
        i_dat  => rx_axis_tdata,
        o_full => rx_fifo_full,

        i_rd    => rx_fifo_rd_pulse,
        o_dat   => rx_fifo_data,
        o_empty => rx_fifo_empty
    );



    -- Interrupt latching / clearing
    process (i_clk)
    begin
        if rising_edge(i_clk) then
            if (i_rst) then
                parity_err_lat <= '0';
                frame_err_lat <= '0';
                overrun_err_lat <= '0';
            else
                if (parity_err) then
                    parity_err_lat <= '1';
                elsif(clear_err_pulse) then
                    parity_err_lat <= '0';
                end if;

                if (frame_err) then
                    frame_err_lat <= '1';
                elsif(clear_err_pulse) then
                    frame_err_lat <= '0';
                end if;

                if (overrun_err) then
                    overrun_err_lat <= '1';
                elsif(clear_err_pulse) then
                    overrun_err_lat <= '0';
                end if; 
            end if;
        end if;
    end process;

end architecture; 
