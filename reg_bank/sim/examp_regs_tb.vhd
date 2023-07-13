-- #############################################################################
-- #  << Examp Regs Testbench >>
-- # ===========================================================================
-- # File     : examp_regs_tb.vhd
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
use vunit_lib.axi_lite_master_pkg.all;

library osvvm;
use osvvm.RandomPkg.all;

use work.gen_utils_pkg.all;
use work.examp_regs_pkg.all;

entity examp_regs_tb is
    generic (runner_cfg : string);
end entity;

architecture tb of examp_regs_tb is
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
    signal bus_m_req : bus_req_t;
    signal bus_m_resp : bus_resp_t;
    signal ctl : examp_regs_ctl_t;
    signal sts : examp_regs_sts_t;
    signal wr  : examp_regs_wr_t;
    signal rd  : examp_regs_rd_t;
  
    -- Helper procedures
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

        procedure write_simple_bus(
            constant waddr : in std_logic_vector(31 downto 0);
            constant wdata : in std_logic_vector(31 downto 0)) 
        is 
        begin
            wait until rising_edge(clk);
            bus_m_req.wen <= '1'; 
            bus_m_req.waddr <= waddr;
            bus_m_req.wdata <= wdata;
            wait until rising_edge(clk);
            bus_m_req.wen <= '0'; 
            bus_m_req.waddr <= X"XXXX_XXXX";
            bus_m_req.wdata <= X"XXXX_XXXX";
            wait for CLK_TO_Q;
        end procedure;


        procedure read_simple_bus(
            constant raddr : in std_logic_vector(31 downto 0);
            variable rdata : out std_logic_vector(31 downto 0)) 
        is 
        begin
            wait until rising_edge(clk);
            bus_m_req.ren <= '1'; 
            bus_m_req.raddr <= raddr;
            wait until rising_edge(clk);
            bus_m_req.ren <= '0'; 
            bus_m_req.raddr <= X"XXXX_XXXX";
            wait for CLK_TO_Q;
            rdata := bus_m_resp.rdata;
        end procedure;

        variable rnd : RandomPType;
        variable rdata : std_logic_vector(31 downto 0);
    begin
        disable_stop(error); -- Don't stop the simulation on errors

        -- Put test suite setup code here. This code is common to the entire test suite
        -- and is executed *once* prior to all test cases.
        test_runner_setup(runner, runner_cfg);
        rnd.InitSeed("common_seed");
        
        bus_m_req.ren <= '0';
        bus_m_req.wen <= '0';

        while test_suite loop 
            
            -- Put test case setup code here. This code executed before *every* test case.
            wait until rising_edge(clk);
            reset_prc(rst);
            info("Starting test...");
            wait until rising_edge(clk);

            if run("basic") then
                -- The test case code is placed in the corresponding (els)if branch.
                write_simple_bus(X"0000_0000", X"ABCD_FF23");
                check_equal(ctl.reg0.fld0, std_logic'('1'));
                check_equal(ctl.reg0.fld1, std_logic_vector'(X"F"));

                wait for 10 * CLK_PERIOD;

                read_simple_bus(X"0000_0000", rdata);
                check_equal(rdata, std_logic_vector'(X"0000_0F01"));

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
    examp_regs_inst : entity work.examp_regs
    port map (
        i_clk   => clk,
        i_rst   => rst,
        i_s_bus => bus_m_req,
        o_s_bus => bus_m_resp,
        o_ctl   => ctl,
        i_sts   => sts,
        o_wr    => wr,
        o_rd    => rd
    );
  

end architecture;
