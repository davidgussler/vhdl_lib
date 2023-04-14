-- #############################################################################
-- #  << UART Testbench >>
-- # ===========================================================================
-- # File     : uart_tb.vhd
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
-- # 
-- # 
-- #############################################################################

library ieee;
context ieee.ieee_std_context;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.vc_context;
use work.gen_utils_pkg.all;

entity uart_tb is
    generic (runner_cfg : string);
end entity;

architecture tb of uart_tb is
    -- Simulation Signals / Constants
    constant CLK_PERIOD  : time := 10 ns; 
    constant CLK_FREQ_HZ : positive := 100000000; 
    constant CLK_TO_Q : time := 1 ns;

    constant NUM_XACTIONS : positive := 10;

    signal clk   : std_logic := '0';
    signal rst   : std_logic := '0';
    signal rstn  : std_logic := '1';
    signal stall : std_logic := '0'; 

    signal start : boolean := false;
    signal done  : boolean := false;


    -- DUT Generics / Signals
    constant BAUD_RATE : positive := 115200; 
    constant DATA_WIDTH : positive := 8;
    constant PARITY    : integer := 0; 
    constant PARITY_EO  : std_logic := '0'; 

    signal rx_axis_tdata : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal rx_axis_tvalid : std_logic;
    signal rx_axis_tready : std_logic;
    signal tx_axis_tdata : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal tx_axis_tvalid : std_logic;
    signal tx_axis_tready : std_logic;
    signal uart_rx : std_logic;
    signal uart_tx : std_logic;
    signal parity_err : std_logic;
    signal frame_err : std_logic;


    -- BFMs
    constant axis_tx_bfm_cfg : axi_stream_master_t := new_axi_stream_master(
        data_length => DATA_WIDTH
    );

    constant axis_rx_bfm_cfg : axi_stream_slave_t := new_axi_stream_slave(
        data_length => DATA_WIDTH
    );

    constant uart_tx_bfm_cfg : uart_master_t := new_uart_master(
        initial_baud_rate => BAUD_RATE,
        idle_state => '1'
    );

    constant uart_rx_bfm_cfg : uart_slave_t := new_uart_slave(
        initial_baud_rate => BAUD_RATE,
        idle_state => '1',
        data_length => DATA_WIDTH
    );
    

begin
    -- Main TB Process ---------------------------------------------------------
    -- -------------------------------------------------------------------------
    main : process
    begin
        test_runner_setup(runner, runner_cfg);

        while test_suite loop

            if run("test_0") then
                info("Resetting DUT ...");
                rst <= '1';
                wait for 15 * CLK_PERIOD;
                rst <= '0';

                info("starting Test 0 ...");
                wait until rising_edge(clk);
                start <= true;
                wait until rising_edge(clk);
                start <= false;

                wait until (done and rising_edge(clk));
                info("Test done");
                wait for 100000 * CLK_PERIOD;
            end if;
        end loop;

        test_runner_cleanup(runner);
    end process;


    -- Input Stimulus ----------------------------------------------------------
    -- -------------------------------------------------------------------------
    prc_stimuli : process
    begin
        wait until start and rising_edge(clk);
        done <= false;
        wait until rising_edge(clk);
    
        info("Sending stream to DUT...");
    
        for xact_num in 1 to NUM_XACTIONS loop
            push_axi_stream(
                net, axis_tx_bfm_cfg, 
                tdata => std_logic_vector(to_unsigned(xact_num, DATA_WIDTH))
            );
        end loop;
    
        info("Stream sent!");
    
        wait until rising_edge(clk);
        done <= true;
    end process;

    
    -- TB Signals --------------------------------------------------------------
    -- -------------------------------------------------------------------------
    clk <= not clk after CLK_PERIOD / 2;
    rstn <= not rst;


    -- DUT ---------------------------------------------------------------------
    -- -------------------------------------------------------------------------
    u_dut : entity work.uart
    generic map (
        G_CLK_FREQ_HZ => CLK_FREQ_HZ,
        G_BAUD_RATE   => BAUD_RATE,
        G_DATA_WIDTH   => DATA_WIDTH,
        G_PARITY      => PARITY,
        G_PARITY_EO  => PARITY_EO
    )
    port map (
        i_clk => clk,
        i_rst => rst,

        o_m_axis_tdata  => rx_axis_tdata ,
        o_m_axis_tvalid => rx_axis_tvalid,
        i_m_axis_tready => rx_axis_tready,
        i_s_axis_tdata  => tx_axis_tdata ,
        i_s_axis_tvalid => tx_axis_tvalid,
        o_s_axis_tready => tx_axis_tready,
        i_uart_rx       => uart_rx,
        o_uart_tx       => uart_tx,
        o_parity_err    => parity_err,
        o_frame_err     => frame_err
    );


    -- BFMs --------------------------------------------------------------------
    -- -------------------------------------------------------------------------
    u_axis_m_tx_bfm : entity vunit_lib.axi_stream_master
    generic map (
        master       => axis_tx_bfm_cfg
    )
    port map (
        aclk         => clk,    
        areset_n     => rstn,   
        tvalid       => tx_axis_tvalid,
        tready       => tx_axis_tready,
        tdata        => tx_axis_tdata
    );

    -- TODO: 
    -- u_axis_s_rx_bfm : entity vunit_lib.axi_stream_slave
    -- generic map (
    --     slave       => axis_rx_bfm_cfg
    -- )
    -- port map (
    --     aclk         => clk,    
    --     areset_n     => rstn,   
    --     tvalid       => rx_axis_tvalid,
    --     tready       => rx_axis_tready,
    --     tdata        => rx_axis_tdata
    -- );

    -- TODO: 
    -- uart_master_bfm : entity vunit_lib.uart_master
    -- generic map (
    --     uart => uart_tx_bfm_cfg
    -- )
    -- port map (
    --     tx => uart_rx
    -- );

    -- u_uart_slave_bfm : entity vunit_lib.uart_slave
    -- generic map (
    --     uart => uart_rx_bfm_cfg
    -- )
    -- port map (
    --     rx => uart_tx
    -- );

end architecture;
