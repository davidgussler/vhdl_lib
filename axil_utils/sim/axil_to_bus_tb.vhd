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

entity axil_to_bus_tb is
    generic (runner_cfg : string);
end entity;

architecture tb of axil_to_bus_tb is
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
    signal axil_req : axil_req_t;
    signal axil_resp : axil_resp_t;
    signal bus_req : bus_req_t;
    signal bus_resp : bus_resp_t;

    -- BFMs
    constant axil_bus : bus_master_t := new_bus(data_length => 32, address_length => 32);

    constant MEM_BYTES : natural := 1024*4; 
    constant mem       : memory_t := new_memory;
    constant mem_buff  : buffer_t := allocate(mem, MEM_BYTES);
    
begin
    -- Main TB Process ---------------------------------------------------------
    -- -------------------------------------------------------------------------
    main : process
        variable rdata : std_logic_vector(axil_resp.rdata'range);
        variable wdata : std_logic_vector(axil_req.wdata'range);
        variable rnd : RandomPType;
    begin
        test_runner_setup(runner, runner_cfg);
        rnd.InitSeed("common_seed");

        if run("basic") then
            info("Resetting DUT ...");
            rst <= '1';
            wait for 16 * CLK_PERIOD;
            rst <= '0';

            info("Starting test...");
            wait until rising_edge(clk);
            write_bus(net, axil_bus, X"0123_4567", X"ABCD_EF12");
            write_bus(net, axil_bus, X"0000_0044", X"1234_5678");
            write_bus(net, axil_bus, X"0000_0048", X"2345_6789");
            write_bus(net, axil_bus, X"0000_004C", X"3456_7890");
            --check_bus(net, axil_bus, X"0123_4567", X"ABCD_EF12");
            read_bus(net, axil_bus, X"0123_4567", rdata);
            wdata := X"FFFF_FFFF";
            check_equal(rdata, wdata);
            check_bus(net, axil_bus, X"0000_0044", wdata);



            info("Test done");
            wait for 100 * CLK_PERIOD;
        elsif run("reads_no_stalls") then
            info("Resetting DUT ...");
            rst <= '1';
            wait for 16 * CLK_PERIOD;
            rst <= '0';

            info("Starting test...");
            wait until rising_edge(clk);
            read_bus(net, axil_bus, X"0123_4567", rdata);

            info("Test done");
            wait for 100 * CLK_PERIOD;
        elsif run("writes_no_stalls") then
            info("Resetting DUT ...");
            rst <= '1';
            wait for 16 * CLK_PERIOD;
            rst <= '0';

            info("Starting test...");
            wait until rising_edge(clk);
            write_bus(net, axil_bus, X"0123_4567", X"ABCD_EF12");

            info("Test done");
            wait for 100 * CLK_PERIOD;
        
        -- reads with stalls 

        -- writes with stalls

        -- mix of reads and writes with stalls

        end if;

    test_runner_cleanup(runner);
    end process;
    test_runner_watchdog(runner, 100 us);


    
    -- TB Signals --------------------------------------------------------------
    -- -------------------------------------------------------------------------
    clk <= not clk after CLK_PERIOD / 2;
    rstn <= not rst;


    -- DUT ---------------------------------------------------------------------
    -- -------------------------------------------------------------------------
    axil_to_bus_inst : entity work.axil_to_bus
    port map (
        i_clk => clk,
        i_rst => rst,
        i_s_axil => axil_req,
        o_s_axil => axil_resp,
        i_m_bus => bus_resp,
        o_m_bus => bus_req
    );
    bus_resp.rdata <= (others=>'1');



    -- BFM ---------------------------------------------------------------------
    -- -------------------------------------------------------------------------
    u_axi_lite_master_bfm: entity vunit_lib.axi_lite_master
    generic map (
        bus_handle => axil_bus
    )
    port map (
        aclk    => clk,
        arready => axil_resp.arready,
        arvalid => axil_req.arvalid,
        araddr  => axil_req.araddr,
        rready  => axil_req.rready,
        rvalid  => axil_resp.rvalid,
        rdata   => axil_resp.rdata,
        rresp   => axil_resp.rresp,
        awready => axil_resp.awready,
        awvalid => axil_req.awvalid,
        awaddr  => axil_req.awaddr,
        wready  => axil_resp.wready,
        wvalid  => axil_req.wvalid,
        wdata   => axil_req.wdata,
        wstrb   => axil_req.wstrb,
        bvalid  => axil_resp.bvalid,
        bready  => axil_req.bready,
        bresp   => axil_resp.bresp
    );


end architecture;
