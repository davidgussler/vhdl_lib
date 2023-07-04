-- #############################################################################
-- #  << AXI-Lite to Bus Testbench >>
-- # ===========================================================================
-- # File     : axil_to_bus_tb.vhd
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

library osvvm;
use osvvm.RandomPkg.all;

use work.gen_utils_pkg.all;

entity axil_pipe_tb is
    generic (runner_cfg : string);
end entity;

architecture tb of axil_pipe_tb is
    -- Simulation Signals / Constants
    constant CLK_PERIOD  : time := 10 ns; 
    constant CLK_FREQ_HZ : positive := 100000000; 
    constant CLK_TO_Q : time := 1 ns;

    signal clk   : std_logic := '0';
    signal rst   : std_logic := '0';
    signal rstn  : std_logic := '1';
    signal stall : std_logic := '0'; 

    signal start : boolean := false;
    signal done  : boolean := false;


    -- DUT Signals
    signal axil_m_req : axil_req_t;
    signal axil_m_resp : axil_resp_t;
    signal axil_s_req : axil_req_t;
    signal axil_s_resp : axil_resp_t;

    -- BFMs
    constant axil_master : bus_master_t := new_bus(data_length => 32, address_length => 32);

    constant MEM_BYTES : natural := 1024*4; 
    constant mem       : memory_t := new_memory;
    constant mem_buff  : buffer_t := allocate(mem, MEM_BYTES);
    constant axil_slave : axi_slave_t := new_axi_slave(mem, data_length => 32, address_length => 32);


    procedure reset_prc(signal rst : out std_logic) is 
    begin 
        info("Resetting DUT ...");
        rst <= '1';
        wait for 16 * CLK_PERIOD;
        rst <= '0';
    end procedure; 
    
begin
    -- -------------------------------------------------------------------------
    -- Main TB Process 
    -- -------------------------------------------------------------------------
    main : process
        variable rdata : std_logic_vector(axil_m_resp.rdata'range);
        variable wdata : std_logic_vector(axil_m_req.wdata'range);
        variable rnd : RandomPType;
    begin

        -- Put test suite setup code here. This code is common to the entire test suite
        -- and is executed *once* prior to all test cases.
        test_runner_setup(runner, runner_cfg);
        rnd.InitSeed("common_seed");

        while test_suite loop 

            -- Put test case setup code here. This code executed before *every* test case.
            wait until rising_edge(clk);
            reset_prc(rst);
            info("Starting test...");
            wait until rising_edge(clk);

            if run("basic") then
                -- The test case code is placed in the corresponding (els)if branch.
                write_bus(net, axil_master, X"0123_4567", X"ABCD_EF12");
                read_bus(net, axil_master, X"0123_4567", rdata);

            elsif run("Test to_string for boolean") then
                check_equal(to_string(true), "true");

            end if;

            -- Put test case cleanup code here. This code executed after *every* test case.
            info("Test done");
            wait for 100 * CLK_PERIOD;

        end loop;

        -- Put test suite cleanup code here. This code is common to the entire test suite
        -- and is executed *once* after all test cases have been run.
        test_runner_cleanup(runner);
    end process;

    test_runner_watchdog(runner, 100 us);


    
    -- TB Signals --------------------------------------------------------------
    -- -------------------------------------------------------------------------
    clk <= not clk after CLK_PERIOD / 2;
    rstn <= not rst;


    -- DUT ---------------------------------------------------------------------
    -- -------------------------------------------------------------------------
    u_axil_pipe : entity work.axil_pipe
    port map (
        i_clk => clk,
        i_rst => rst,
        i_s_axil => axil_m_req,
        o_s_axil => axil_m_resp,
        i_m_axil => axil_s_resp,
        o_m_axil => axil_s_req
    );


    -- M BFM ---------------------------------------------------------------------
    -- -------------------------------------------------------------------------
    u_axi_lite_master_bfm: entity vunit_lib.axi_lite_master
    generic map (
        bus_handle => axil_master
    )
    port map (
        aclk    => clk,
        arready => axil_m_resp.arready,
        arvalid => axil_m_req.arvalid,
        araddr  => axil_m_req.araddr,
        rready  => axil_m_req.rready,
        rvalid  => axil_m_resp.rvalid,
        rdata   => axil_m_resp.rdata,
        rresp   => axil_m_resp.rresp,
        awready => axil_m_resp.awready,
        awvalid => axil_m_req.awvalid,
        awaddr  => axil_m_req.awaddr,
        wready  => axil_m_resp.wready,
        wvalid  => axil_m_req.wvalid,
        wdata   => axil_m_req.wdata,
        wstrb   => axil_m_req.wstrb,
        bvalid  => axil_m_resp.bvalid,
        bready  => axil_m_req.bready,
        bresp   => axil_m_resp.bresp
    );

    -- S BFM ---------------------------------------------------------------------
    -- -------------------------------------------------------------------------

    u_axi_read_slave : axi_read_slave
    generic map (
        axi_slave => axi_slave
    )
    port map (
        aclk    => aclk,
        arvalid => arvalid,
        arready => arready,
        arid    => arid,
        araddr  => araddr,
        arlen   => arlen,
        arsize  => arsize,
        arburst => arburst,
        rvalid  => rvalid,
        rready  => rready,
        rid     => rid,
        rdata   => rdata,
        rresp   => rresp,
        rlast   => rlast
    );

    u_axi_write_slave : axi_write_slave
    generic map (
        axi_slave => axi_slave
    )
    port map (
        aclk    => aclk,
        awvalid => awvalid,
        awready => awready,
        awid    => awid,
        awaddr  => awaddr,
        awlen   => awlen,
        awsize  => awsize,
        awburst => awburst,
        wvalid  => wvalid,
        wready  => wready,
        wdata   => wdata,
        wstrb   => wstrb,
        wlast   => wlast,
        bvalid  => bvalid,
        bready  => bready,
        bid     => bid,
        bresp   => bresp
    );


end architecture;
