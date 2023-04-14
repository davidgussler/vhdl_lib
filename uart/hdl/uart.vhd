-- #############################################################################
-- #  << UART >>
-- # ===========================================================================
-- # File     : uart.vhd
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
-- # 
-- # 
-- #############################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.gen_utils_pkg.all;

entity uart is
    generic (
        -- Clock rate in Hz of "i_clk"
        G_CLK_FREQ_HZ : positive              := 125000000; 
        -- Baud rate of the UART. Typical values are 115200 or 9600
        G_BAUD_RATE   : positive              := 115200;
        -- Number of data bits per UART transfer
        G_DATA_WIDTH   : positive range 5 to 8 := 8;
        -- 1 = use parity 
        -- 0 = no parity 
        G_PARITY      : integer range 0 to 1  := 0;
        -- 0 = even 
        -- 1 = odd 
        -- only valid if G_PARITY is set
        G_PARITY_EO   : std_logic         := '0'
    );
    port (
        i_clk : in std_logic;
        i_rst : in std_logic;

        -- AXI-Stream - UART Rx
        o_m_axis_tdata  : out std_logic_vector(G_DATA_WIDTH-1 downto 0);
        o_m_axis_tvalid : out std_logic;
        i_m_axis_tready : in  std_logic; 

        -- AXI-Stream - UART Tx
        i_s_axis_tdata  : in  std_logic_vector(G_DATA_WIDTH-1 downto 0);
        i_s_axis_tvalid : in  std_logic;
        o_s_axis_tready : out std_logic; 

        -- UART Interface 
        i_uart_rx  : in  std_logic;
        o_uart_tx  : out std_logic;

        -- Status
        o_parity_err : out std_logic;
        o_frame_err  : out std_logic
    );
end entity;

architecture rtl of uart is

    -- Calculate number of clocks per baud based off of the user-given clock
    -- frequency and baud rate
    constant CLKS_PER_BAUD : positive := G_CLK_FREQ_HZ / G_BAUD_RATE; 

    -- Data + start + stop + parity 
    constant BUF_WIDTH : positive := G_DATA_WIDTH + G_PARITY + 2; 

    type uart_state_t is (S_IDLE, S_DATA, S_BUF);
    signal tx_state     : uart_state_t;
    signal rx_state     : uart_state_t;

    signal tx_data : std_logic_vector(G_DATA_WIDTH-1 downto 0); 
    signal tx_buf : std_logic_vector(BUF_WIDTH-1 downto 0); 
    signal tx_baud_pulse : std_logic; 
    signal tx_baud_cnt : unsigned(clog2(CLKS_PER_BAUD)-1 downto 0); 
    signal tx_buf_idx : unsigned(clog2(BUF_WIDTH)-1 downto 0); 
    signal tx_parity : std_logic_vector(G_DATA_WIDTH downto 0); 


begin

    -- -------------------------------------------------------------------------
    -- UART Tx 
    -- -------------------------------------------------------------------------
    -- TX Baud Rate Counter
    process (i_clk)
    begin
        if rising_edge(i_clk) then
            if (i_rst) then
                tx_baud_cnt <= (others=>'0');
                tx_baud_pulse <= '0';
            else
                if (tx_baud_cnt < CLKS_PER_BAUD) then 
                    tx_baud_cnt <= tx_baud_cnt + 1; 
                    tx_baud_pulse <= '0';
                else 
                    tx_baud_cnt <= (others=>'0');
                    tx_baud_pulse <= '1';
                end if;
            end if;
        end if;
    end process;

    -- Tx parity calculation
    -- 9 inputs => two levels of LUTs
    tx_parity(0) <= G_PARITY_EO;
    tx_parity_logic: for i in 0 to G_DATA_WIDTH-1 generate
        tx_parity(i+1) <= tx_parity(i) xor tx_data(i);
    end generate;

    -- TX Controller 
    process (i_clk)
    begin
        if rising_edge(i_clk) then
            if (i_rst) then
                tx_state        <= S_IDLE;
                o_s_axis_tready <= '1';
                o_uart_tx       <= '1'; 
                tx_buf <= (others=>'0'); -- TODO: doesnt need a reset 
                tx_data <= (others=>'0'); -- TODO: doesnt need a reset 
                tx_buf_idx <= (others=>'0'); 
            else
                case (tx_state) is
                when S_IDLE =>
                    -- Register the data
                    if (i_s_axis_tvalid and o_s_axis_tready) then
                        tx_state <= S_BUF; 
                        o_s_axis_tready <= '0'; 
                        tx_data <= i_s_axis_tdata; 
                    else 
                        o_s_axis_tready <= '1';
                    end if; 

                when S_BUF =>
                    -- add start / stop / parity to tx buffer
                    tx_state <= S_DATA; 
                    if (G_PARITY = 0) then  
                        tx_buf <= '1' & tx_data & '0'; 
                    else 
                        tx_buf <= '1' & tx_parity(G_DATA_WIDTH) & tx_data & '0'; 
                    end if; 

                when S_DATA =>
                    if (tx_buf_idx >= BUF_WIDTH) then 
                        tx_state <= S_IDLE; 
                        tx_buf_idx <= (others=>'0');
                    elsif (tx_baud_pulse) then
                        o_uart_tx  <= tx_buf(to_integer(tx_buf_idx)); 
                        tx_buf_idx <= tx_buf_idx + 1;
                    end if; 

                when others =>
                    null;
                end case;
                
            end if;
        end if;
    end process;






    -- UART Rx -----------------------------------------------------------------
    -- -------------------------------------------------------------------------

    -- RX Controller


    -- RX Data Bit Counter


    

end architecture;