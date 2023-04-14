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
        G_DATA_BITS   : positive range 5 to 8 := 8;
        G_PARITY      : uart_parity_t         := NO_PARITY
    );
    port (
        i_clk : in std_logic;
        i_rst : in std_logic;

        -- Wishbone Slave Interface
        i_wbs_cyc : in  std_logic;
        i_wbs_stb : in  std_logic;
        i_wbs_adr : in  std_logic_vector(31 downto 0);
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

begin

    u_wb_uart_regs : wb_uart_regs
    generic map (
        G_DATA_BITS => G_DATA_BITS
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
        i_rx_fifo_valid    => rx_fifo_valid,
        i_rx_fifo_full     => rx_fifo_full,
        i_tx_fifo_empty    => tx_fifo_empty,
        i_tx_fifo_full     => tx_fifo_full,
        i_en_intr          => en_intr,
        i_overrun_err      => overrun_err,
        i_frame_err        => frame_err,
        i_parity_err       => parity_err,
        o_tx_fifo_data     => tx_fifo_data,
        o_rst_tx_fifo      => rst_tx_fifo,
        o_rst_rx_fifo      => rst_rx_fifo,
        o_en_intr          => en_intr,
        o_tx_fifo_wr_pulse => tx_fifo_wr_pulse,
        o_rx_fifo_rd_pulse => rx_fifo_rd_pulse
    );


    -- Off-chip UART Rx Synchronizer

    -- Rx filter

    u_uart : uart
    generic map (
        G_CLK_FREQ_HZ => G_CLK_RATE_HZ,
        G_BAUD_RATE   => G_BAUD_RATE,
        G_DATA_BITS   => G_DATA_BITS,
        G_PARITY      => G_PARITY
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

        o_parity_err => parity_err,
        o_frame_err  => frame_err
    );



    u_tx_fifo : fifo
    generic map (
        G_WIDTH     => G_DATA_BITS,
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

    u_rx_fifo : fifo
    generic map (
        G_WIDTH     => G_DATA_BITS,
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
        o_empty => not rx_fifo_valid -- CAN I DO THIS??? 
    );



    -- Process to generate interrupts
    -- TODO: 

end architecture; 
