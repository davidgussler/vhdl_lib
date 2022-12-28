-- #############################################################################
-- #  << Wishbone Crossbar Vunit Testbench >>
-- # ===========================================================================
-- # File     : wb_xbar_tb.vhd
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
-- # Testing out the VUnit Wishbone master and slave BFMs. 
-- # These are really handy!
-- #
-- #############################################################################

library ieee;
context ieee.ieee_std_context;
library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.vc_context;
library osvvm;
use osvvm.RandomPkg.all;
use work.gen_utils_pkg.all;


entity wb_xbar_tb is
    generic (
        runner_cfg : string
    );
end entity;


architecture tb of wb_xbar_tb is

    -- Simulation Signals / Constants
    constant C_CLK_PERIOD : time := 10 ns; 
    constant C_CLK2Q : time := 1 ns;

    constant C_NUM_XACTIONS : positive := 10;

    signal clk   : std_logic := '0';
    signal rst   : std_logic := '0';
    signal rstn  : std_logic := '1';

    signal start : boolean := false;
    signal done  : boolean := false;

    -- DUT Generics ------------------------------------------------------------
    constant C_NM            : positive := 2;
    constant C_NS            : positive := 2;
    constant C_DAT_W_L2      : positive := 4; 
    constant C_ADR_W         : positive := 16;
    constant C_S_BASE_ADR    : slv_array_t(0 to C_NS-1)(C_ADR_W-1 downto 0) := (X"1000", X"2000");
    constant C_S_ADR_W       : int_array_t(0 to C_NS-1) := (12, 12);
    constant C_MAX_OUTSTAND  : positive := 64; 
    constant C_WATCHDOG_CLKS : positive := 64;
    constant C_CONN_MATRIX   : slv_array_t(C_NM-1 downto 0)(0 to C_NS-1) := (B"11", B"11");
    constant C_ROUND_ROBIN   : boolean := FALSE;


    -- DUT Signals -------------------------------------------------------------
    -- Slave Interface(s)
    signal i_wbs_cyc : std_logic_vector(C_NM-1 downto 0) := (others=>'0');
    signal i_wbs_stb : std_logic_vector(C_NM-1 downto 0) := (others=>'0');
    signal i_wbs_adr : slv_array_t     (C_NM-1 downto 0)(C_ADR_W-1 downto 0) := (others=>(others=>'0')); 
    signal i_wbs_wen : std_logic_vector(C_NM-1 downto 0) := (others=>'0');
    signal i_wbs_sel : slv_array_t     (C_NM-1 downto 0)((2 ** (C_DAT_W_L2-3))-1 downto 0) := (others=>(others=>'0')); 
    signal i_wbs_dat : slv_array_t     (C_NM-1 downto 0)((2 ** C_DAT_W_L2)-1 downto 0) := (others=>(others=>'0'));
    signal o_wbs_stl : std_logic_vector(C_NM-1 downto 0):= (others=>'0'); 
    signal o_wbs_ack : std_logic_vector(C_NM-1 downto 0):= (others=>'0'); 
    signal o_wbs_err : std_logic_vector(C_NM-1 downto 0):= (others=>'0'); 
    signal o_wbs_dat : slv_array_t     (C_NM-1 downto 0)((2 ** C_DAT_W_L2)-1 downto 0);
    
    -- Master Interface(s)
    signal o_wbm_cyc : std_logic_vector(C_NS-1 downto 0):= (others=>'0');
    signal o_wbm_stb : std_logic_vector(C_NS-1 downto 0):= (others=>'0');
    signal o_wbm_adr : slv_array_t     (C_NS-1 downto 0)(C_ADR_W-1 downto 0) := (others=>(others=>'0')); 
    signal o_wbm_wen : std_logic_vector(C_NS-1 downto 0):= (others=>'0');
    signal o_wbm_sel : slv_array_t     (C_NS-1 downto 0)((2 ** (C_DAT_W_L2-3))-1 downto 0) := (others=>(others=>'0'));
    signal o_wbm_dat : slv_array_t     (C_NS-1 downto 0)((2 ** C_DAT_W_L2)-1 downto 0) := (others=>(others=>'0'));
    signal i_wbm_stl : std_logic_vector(C_NS-1 downto 0) := (others=>'0'); 
    signal i_wbm_ack : std_logic_vector(C_NS-1 downto 0) := (others=>'0'); 
    signal i_wbm_err : std_logic_vector(C_NS-1 downto 0) := (others=>'0'); 
    signal i_wbm_dat : slv_array_t     (C_NS-1 downto 0)((2 ** C_DAT_W_L2)-1 downto 0) := (others=>(others=>'0'));


    -- BFMs
    --type bus_master_array_t is array (0 to C_NM-1) of bus_master_t; 

    constant memory0 : memory_t := new_memory;
    constant buf0 : buffer_t := allocate(memory0, 1024);
    constant wbs0 : wishbone_slave_t := new_wishbone_slave(
        memory => memory0,
        ack_high_probability => 1.0,
        stall_high_probability => 0.0
    );
    
    constant memory1 : memory_t := new_memory;
    constant buf1 : buffer_t := allocate(memory1, 1024);
    constant wbs1 : wishbone_slave_t := new_wishbone_slave(
        memory => memory1,
        ack_high_probability => 1.0,
        stall_high_probability => 0.0
    );

    constant wbm0 : bus_master_t := new_bus(
        data_length => (2 ** C_DAT_W_L2),
        address_length => C_ADR_W,
        byte_length => 8,
        logger => get_logger("master0")
    );
    
    constant wbm1 : bus_master_t := new_bus(
        data_length => (2 ** C_DAT_W_L2),
        address_length => C_ADR_W,
        byte_length => 8,
        logger => get_logger("master1")
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
                wait until rising_edge(clk);
                rst <= '1';
                wait for 16 * C_CLK_PERIOD;
                rst <= '0';

                info("starting Test 0 ...");
                wait until rising_edge(clk);
                start <= true;
                wait until rising_edge(clk);
                start <= false;

                wait until (done and rising_edge(clk));
                info("Test done");
                wait for 100 * C_CLK_PERIOD;
            end if;
        end loop;

        test_runner_cleanup(runner);
    end process;


    -- Input Stimuli -----------------------------------------------------------
    -- -------------------------------------------------------------------------
    prc_wbm_xactions : process
        variable rnd : RandomPType; 
        variable rdata_bref : std_logic_vector(15 downto 0);
        variable rdata_data : std_logic_vector(15 downto 0);
    begin
        wait until start and rising_edge(clk);
        done <= false;
        wait until rising_edge(clk);
        
        info("Writing...");
        write_bus(net, wbm0, X"1000", X"DADA", B"11");
        info("Write complete!");
        info("Waiting 10 clockcycles");
        wait for 10 * C_CLK_PERIOD;
        info("Reading...");
        read_bus(net, wbm0, X"1000", rdata_bref);
        info("Read Complete!");
        
        wait until rising_edge(clk);
        done <= true;
    end process;

    
    -- TB Signals --------------------------------------------------------------
    -- -------------------------------------------------------------------------
    clk <= not clk after C_CLK_PERIOD / 2;
    rstn <= not rst;


    -- DUT ---------------------------------------------------------------------
    -- -------------------------------------------------------------------------
    u_dut : entity work.wb_xbar
    generic map (
        G_NM            => C_NM            ,
        G_NS            => C_NS            ,
        G_DAT_W_L2      => C_DAT_W_L2      ,
        G_ADR_W         => C_ADR_W         ,
        G_S_BASE_ADR    => C_S_BASE_ADR    ,
        G_S_ADR_W       => C_S_ADR_W       ,
        G_MAX_OUTSTAND  => C_MAX_OUTSTAND  ,
        G_WATCHDOG_CLKS => C_WATCHDOG_CLKS ,
        G_CONN_MATRIX   => C_CONN_MATRIX   ,
        G_ROUND_ROBIN   => C_ROUND_ROBIN
    )
    port map (
        i_clk => clk,
        i_rst => rst,

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

        o_wbm_cyc => o_wbm_cyc,
        o_wbm_stb => o_wbm_stb,
        o_wbm_adr => o_wbm_adr,
        o_wbm_wen => o_wbm_wen,
        o_wbm_sel => o_wbm_sel,
        o_wbm_dat => o_wbm_dat,
        i_wbm_stl => i_wbm_stl,
        i_wbm_ack => i_wbm_ack,
        i_wbm_err => i_wbm_err,
        i_wbm_dat => i_wbm_dat
    );




    -- Wishbone BFMs -----------------------------------------------------------
    -- -------------------------------------------------------------------------
    -- Master 0
    u_wbm0_bfm : entity vunit_lib.wishbone_master
    generic map (
        bus_handle => wbm0,
        strobe_high_probability => 1.0
    )
    port map(
        clk   => clk,
        adr   => i_wbs_adr(0),
        dat_i => o_wbs_dat(0),
        dat_o => i_wbs_dat(0),
        sel   => i_wbs_sel(0),
        cyc   => i_wbs_cyc(0),
        stb   => i_wbs_stb(0),
        we    => i_wbs_wen(0),
        stall => o_wbs_stl(0),
        ack   => o_wbs_ack(0)
    );

    -- Master 1
    u_wbm1_bfm : entity vunit_lib.wishbone_master
    generic map (
        bus_handle => wbm1,
        strobe_high_probability => 1.0
    )
    port map(
        clk   => clk,
        adr   => i_wbs_adr(1),
        dat_i => o_wbs_dat(1),
        dat_o => i_wbs_dat(1),
        sel   => i_wbs_sel(1),
        cyc   => i_wbs_cyc(1),
        stb   => i_wbs_stb(1),
        we    => i_wbs_wen(1),
        stall => o_wbs_stl(1),
        ack   => o_wbs_ack(1)
    );

    -- Slave 0
    u_wbs0_bfm : entity vunit_lib.wishbone_slave
    generic map (
        wishbone_slave => wbs0
    )
    port map (
        clk   => clk,
        adr   => o_wbm_adr(0)(11 downto 0),
        dat_i => o_wbm_dat(0),
        dat_o => i_wbm_dat(0),
        sel   => o_wbm_sel(0),
        cyc   => o_wbm_cyc(0),
        stb   => o_wbm_stb(0),
        we    => o_wbm_wen(0),
        stall => i_wbm_stl(0),
        ack   => i_wbm_ack(0)
    );

    -- Slave 1
    u_wbs1_bfm : entity vunit_lib.wishbone_slave
    generic map (
        wishbone_slave => wbs1
    )
    port map (
        clk   => clk,
        adr   => o_wbm_adr(1)(11 downto 0),
        dat_i => o_wbm_dat(1),
        dat_o => i_wbm_dat(1),
        sel   => o_wbm_sel(1),
        cyc   => o_wbm_cyc(1),
        stb   => o_wbm_stb(1),
        we    => o_wbm_wen(1),
        stall => i_wbm_stl(1),
        ack   => i_wbm_ack(1)
    );

end architecture;
