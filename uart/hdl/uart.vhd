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
        G_DATA_BITS   : positive range 5 to 8 := 8;
        -- Options:
        -- * "ODD_PARITY"  - Parity bit is set to 1 if even number of 1s in the 
        --    data bit sequence. Parity bit is 0 if odd number of 1s
        -- * "EVEN_PARITY" - Parity bit is set to 1 if odd number of 1s in the 
        --    data bit sequence. Parity bit is 0 if even number of 1s. 
        -- * "NO_PARITY"   - No parity bit. 
        G_PARITY      : uart_parity_t         := NO_PARITY
    );
    port (
        i_clk : in std_logic;
        i_rst : in std_logic;

        -- AXI-Stream - UART Rx
        o_m_axis_tdata  : out std_logic_vector(G_DATA_BITS-1 downto 0);
        o_m_axis_tvalid : out std_logic;
        i_m_axis_tready : in  std_logic; 

        -- AXI-Stream - UART Tx
        i_s_axis_tdata  : in  std_logic_vector(G_DATA_BITS-1 downto 0);
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

    -- Calculate number of clocks per bit based off of the user-given clock
    -- frequency and baud rate
    constant CLKS_PER_BIT : positive := G_CLK_FREQ_HZ / G_BAUD_RATE; 

    type uart_state_t is (S_IDLE, S_START, S_DATA, S_PARITY, S_STOP);
    signal tx_state     : uart_state_t;
    signal rx_state     : uart_state_t;

    signal tx_data : std_logic_vector(G_DATA_BITS-1 downto 0);
    signal tx_baud_ctr_en : std_logic; 
    signal tx_baud_ctr_done : std_logic; 
    signal tx_baud_cnt : unsigned(clog2(CLKS_PER_BIT)-1 downto 0); 
    signal tx_data_ctr_en : std_logic; 
    signal tx_data_ctr_done : std_logic; 
    signal tx_data_cnt : unsigned(clog2(G_DATA_BITS)-1 downto 0); 
    signal tx_parity : std_logic; 


begin

    -- UART Tx -----------------------------------------------------------------
    -- -------------------------------------------------------------------------

    -- Register Tx Data
    process (i_clk)
    begin
        if rising_edge(i_clk) then
            if (i_rst) then
                tx_data <= (others => '0'); 
            elsif (i_s_axis_tvalid and o_s_axis_tready) then
                tx_data <= i_s_axis_tdata;
            end if;
        end if;
    end process;


    -- TX Controller 
    -- process (i_clk)
    -- begin
    --     if rising_edge(i_clk) then
    --         if (i_rst) then
    --             tx_state        <= S_IDLE;
    --             tx_baud_ctr_en  <= '0'; 
    --             tx_data_ctr_en  <= '0'; 
    --             o_s_axis_tready <= '1';
    --             o_uart_tx       <= '1'; 
    --         else
    --             case (tx_state) is
    --                 when S_IDLE =>
    --                     tx_baud_ctr_en  <= '0'; 
    --                     tx_data_ctr_en  <= '0'; 
    --                     o_s_axis_tready <= '1';
    --                     o_uart_tx       <= '1'; 
    --                     if (i_s_axis_tvalid and o_s_axis_tready) then
    --                         tx_state <= S_START; 
    --                     end if; 

    --                 when S_START =>
    --                     tx_baud_ctr_en  <= '1'; 
    --                     tx_data_ctr_en  <= '0'; 
    --                     o_s_axis_tready <= '0';
    --                     o_uart_tx       <= '0'; 
    --                     if (tx_baud_ctr_done) then
    --                         tx_state <= S_DATA; 
    --                     end if; 

    --                 when S_DATA =>
    --                     tx_baud_ctr_en  <= '1'; 
    --                     tx_data_ctr_en  <= '1'; 
    --                     o_s_axis_tready <= '0';
    --                     o_uart_tx       <= tx_data(to_integer(tx_data_cnt)); 
    --                     if (tx_data_ctr_done) then
    --                         if (G_PARITY = NO_PARITY) then
    --                             tx_state <= S_STOP; 
    --                         else 
    --                             tx_state <= S_PARITY; 
    --                         end if; 
    --                     end if; 

    --                 when S_PARITY =>
    --                     tx_baud_ctr_en  <= '1'; 
    --                     tx_data_ctr_en  <= '0'; 
    --                     o_s_axis_tready <= '0';
    --                     o_uart_tx       <= tx_parity; 
    --                     if (tx_baud_ctr_done) then
    --                         tx_state <= S_STOP; 
    --                     end if; 

    --                 when S_STOP =>
    --                     tx_baud_ctr_en  <= '1'; 
    --                     tx_data_ctr_en  <= '0'; 
    --                     o_s_axis_tready <= '0';
    --                     o_uart_tx       <= '1'; 
    --                     if (tx_baud_ctr_done) then
    --                         tx_state <= S_IDLE; 
    --                     end if; 
                
    --                 when others =>
    --                     -- Unreachable
    --                     null;
    --             end case;
                
    --         end if;
    --     end if;
    -- end process;

    -- -- Determine next state
    -- process (all)
    -- begin
    --     nxt_tx_state <= tx_state; -- Stay put by default
    --     case (tx_state) is
    --         when S_IDLE =>
    --             if (i_s_axis_tvalid and o_s_axis_tready) then
    --                 nxt_tx_state        <= S_START; 
    --             end if; 

    --         when S_START =>
    --             if (tx_baud_ctr_done) then
    --                 nxt_tx_state        <= S_DATA;  
    --             end if; 

    --         when S_DATA =>
    --             if (tx_data_ctr_done) then
    --                 if (G_PARITY = NO_PARITY) then
    --                     nxt_tx_state <= S_STOP; 
    --                 else 
    --                     nxt_tx_state <= S_PARITY; 
    --                 end if; 
    --             end if; 

    --         when S_PARITY =>
    --             if (tx_baud_ctr_done) then
    --                 nxt_tx_state <= S_STOP; 
    --             end if; 

    --         when S_STOP =>
    --             if (tx_baud_ctr_done) then
    --                 nxt_tx_state <= S_IDLE; 
    --             end if; 
        
    --         when others =>
    --             -- Unreachable
    --             null;
    --     end case;
    -- end process;

    -- -- Set output based on next state
    -- process (i_clk)
    -- begin
    --     if rising_edge(i_clk) then
    --         if (i_rst) then
    --             tx_state        <= S_IDLE;
    --             tx_baud_ctr_en  <= '0'; 
    --             tx_data_ctr_en  <= '0'; 
    --             o_s_axis_tready <= '1';
    --             o_uart_tx       <= '1'; 
    --         else 
    --             tx_state <= nxt_tx_state; 
    --             case (nxt_tx_state) is
    --                 when S_IDLE =>

        
    --                 when S_START =>

        
    --                 when S_DATA =>

        
    --                 when S_PARITY =>

    --                 when S_STOP =>

                
    --                 when others =>
    --                     -- Unreachable
    --                     null;
    --             end case;
    --         end if;
    --     end if;
    -- end process;

    -- TX Controller 
    process (i_clk)
    begin
        if rising_edge(i_clk) then
            if (i_rst) then
                tx_state        <= S_IDLE;
                tx_baud_ctr_en  <= '0'; 
                tx_data_ctr_en  <= '0'; 
                o_s_axis_tready <= '1';
                o_uart_tx       <= '1'; 
            else
                case (tx_state) is
                    when S_IDLE =>
                        if (i_s_axis_tvalid and o_s_axis_tready) then
                            tx_state <= S_START; 
                            tx_baud_ctr_en  <= '1'; 
                            tx_data_ctr_en  <= '0'; 
                            o_s_axis_tready <= '0';
                            o_uart_tx       <= '0'; 
                        end if; 

                    when S_START =>
                        if (tx_baud_ctr_done) then
                            tx_state <= S_DATA; 
                            tx_baud_ctr_en  <= '1'; 
                            tx_data_ctr_en  <= '1'; 
                            o_s_axis_tready <= '0';
                            o_uart_tx       <= tx_data(to_integer(tx_data_cnt)); 
                        end if; 

                    when S_DATA =>
                        o_uart_tx       <= tx_data(to_integer(tx_data_cnt)); 
                        if (tx_data_ctr_done) then
                            if (G_PARITY = NO_PARITY) then
                                tx_state <= S_STOP; 
                                tx_baud_ctr_en  <= '1'; 
                                tx_data_ctr_en  <= '0'; 
                                o_s_axis_tready <= '0';
                                o_uart_tx       <= '1'; 
                            else 
                                tx_state <= S_PARITY; 
                                tx_baud_ctr_en  <= '1'; 
                                tx_data_ctr_en  <= '0'; 
                                o_s_axis_tready <= '0';
                                o_uart_tx       <= tx_parity; 
                            end if; 
                        end if; 

                    when S_PARITY =>
                        if (tx_baud_ctr_done) then
                            tx_state <= S_STOP; 
                            tx_baud_ctr_en  <= '1'; 
                            tx_data_ctr_en  <= '0'; 
                            o_s_axis_tready <= '0';
                            o_uart_tx       <= '1'; 
                        end if; 

                    when S_STOP =>
                        if (tx_baud_ctr_done) then
                            tx_state <= S_IDLE;
                            tx_baud_ctr_en  <= '0'; 
                            tx_data_ctr_en  <= '0'; 
                            o_s_axis_tready <= '1';
                            o_uart_tx       <= '1'; 
                        end if; 
                
                    when others =>
                        -- Unreachable
                        null;
                end case;
                
            end if;
        end if;
    end process;



    -- TX Baud Rate Counter
    process (i_clk)
    begin
        if rising_edge(i_clk) then
            if (i_rst) then
                tx_baud_cnt      <= (others=>'0');
                tx_baud_ctr_done <= '0';
            elsif (tx_baud_ctr_en) then
                tx_baud_cnt      <= tx_baud_cnt + 1; 
                tx_baud_ctr_done <= '0';
                if (CLKS_PER_BIT-1 = tx_baud_cnt) then 
                    tx_baud_cnt      <= (others=>'0');
                    tx_baud_ctr_done <= '1';
                end if;
            end if;
        end if;
    end process;

    -- TX Data Bit Counter
    process (i_clk)
    begin
        if rising_edge(i_clk) then
            if (i_rst) then
                tx_data_cnt      <= (others=>'0');
                tx_data_ctr_done <= '0';
            elsif (tx_data_ctr_en and tx_baud_ctr_done) then
                tx_data_cnt      <= tx_data_cnt + 1; 
                tx_data_ctr_done <= '0';
                if (G_DATA_BITS-1 = tx_data_cnt) then 
                    tx_data_cnt      <= (others=>'0');
                    tx_data_ctr_done <= '1';
                end if;
            end if;
        end if;
    end process;

    -- TX Parity Bit
    gen_parity : case G_PARITY generate
        when EVEN_PARITY =>
            process (i_clk)
            begin
                if rising_edge(i_clk) then
                    if (i_rst) then 
                        tx_parity <= '0'; 
                    elsif (tx_data_ctr_en and tx_baud_ctr_done and tx_data(to_integer(tx_data_cnt))) then
                        tx_parity <= not tx_parity;
                    end if; 
                end if;
            end process;

        when ODD_PARITY =>
            process (i_clk)
            begin
                if rising_edge(i_clk) then
                    if (i_rst) then 
                        tx_parity <= '1'; 
                    elsif (tx_data_ctr_en and tx_baud_ctr_done and tx_data(to_integer(tx_data_cnt))) then
                        tx_parity <= not tx_parity;
                    end if; 
                end if;
            end process;

        when NO_PARITY =>
            tx_parity <= '0';
    
        when others =>
            -- Unreachable

    end generate;


    -- UART Rx -----------------------------------------------------------------
    -- -------------------------------------------------------------------------

    -- RX Controller


    -- TX Data Bit Counter


    

end architecture;