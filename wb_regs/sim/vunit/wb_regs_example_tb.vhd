-- ###############################################################################################
-- # << Skid Buffer Testbench >> #
-- *********************************************************************************************** 
-- Copyright David N. Gussler 2022
-- *********************************************************************************************** 
-- File     : wb_regs_example_tb.vhd
-- Author   : David Gussler - davidnguss@gmail.com 
-- Language : VHDL '08
-- History  :  Date      | Version | Comments 
--            --------------------------------
--            10-01-2022 | 1.0     | Initial 
-- *********************************************************************************************** 
-- Description : 
--    Basic testbench for the skid buffer module
--    Makes use of the Vunit verification framework
--    After trying cocotb and vunit, I've decided that I like vunit much better
--       Everything "just works" and the project feels more mature
--       The BFMs are a huge draw.
-- ###############################################################################################

-- Libraries -------------------------------------------------------------------
-- -----------------------------------------------------------------------------
library ieee;
context ieee.ieee_std_context;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.vc_context;

library osvvm;
use osvvm.RandomPkg.all;


-- Entity ----------------------------------------------------------------------
-- -----------------------------------------------------------------------------
entity wb_regs_example_tb is
    generic (runner_cfg : string);
end entity;


-- Architecture ----------------------------------------------------------------
-- -----------------------------------------------------------------------------
architecture tb of wb_regs_example_tb is

    -- Simulation Signals / Constants
    constant C_CLK_PERIOD : time := 10 ns; 
    constant C_CLK2Q : time := 1 ns;

    constant C_NUM_XACTIONS : positive := 10;

    signal clk   : std_logic := '0';
    signal rst   : std_logic := '0';
    signal rstn  : std_logic := '1';

    signal start : boolean := false;
    signal done  : boolean := false;


    -- DUT Signals
    signal wbs_cyc : std_logic;
    signal wbs_stb : std_logic;
    signal wbs_adr : std_logic_vector(7 downto 0);
    signal wbs_wen : std_logic;
    signal wbs_sel : std_logic_vector(3 downto 0);
    signal wbs_dat : std_logic_vector(31 downto 0);
    signal wbs_stl : std_logic; 
    signal wbs_ack : std_logic;
    signal wbs_err : std_logic;
    signal wbs_dat : std_logic_vector(31 downto 0);


    -- BFMs
    constant bus_master : bus_master_t := new_bus(
        data_length => 32,
        address_length => 8,
        byte_length => 8,
        logger => get_logger("wishbone_bus")
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


    -- Input Stimuli ----------------------------------------------------------
    -- -------------------------------------------------------------------------
    prc_stimuli : process
    begin
        wait until start and rising_edge(clk);
        done <= false;
        wait until rising_edge(clk);
    
        info("Sending stream to DUT...");
    
        for xact_num in 1 to C_NUM_XACTIONS loop
            push_axi_stream(
                net, master_axis, 
                tdata => std_logic_vector(to_unsigned(xact_num, C_WIDTH))
            );
        end loop;
    
        info("Stream sent!");
    
        wait until rising_edge(clk);
        done <= true;
    end process;

    
    -- TB Signals --------------------------------------------------------------
    -- -------------------------------------------------------------------------
    clk <= not clk after C_CLK_PERIOD / 2;
    rstn <= not rst;


    -- DUT ---------------------------------------------------------------------
    -- -------------------------------------------------------------------------
    dut : entity work.wb_regs_example
    port map(
        i_clk => clk,
        i_rst => rst,

        -- Wishbone Slave Interface
        i_wbs_cyc => wbs_cyc,
        i_wbs_stb => wbs_stb,
        i_wbs_adr => wbs_adr,
        i_wbs_wen => wbs_wen,
        i_wbs_sel => wbs_sel,
        i_wbs_dat => wbs_dat,
        o_wbs_stl => wbs_stl,
        o_wbs_ack => wbs_ack,
        o_wbs_err => wbs_err,
        o_wbs_dat => wbs_dat,

        -- Custom module interface
        i_in_bit0  => 
        i_in_vec0  => RandSlv(Size => 8)
        i_in_vec1  => 
        o_out_bit0 => 
        o_out_vec0 => 
        o_out_vec1 => 
        o_rd_pulse => 
        o_wr_pulse => 

    );



    -- AXIS Master BFM VC ------------------------------------------------------
    -- -------------------------------------------------------------------------
    wbm_bfm : entity vunit_lib.wishbone_master
    generic map (
        bus_handle => bus_master,
        strobe_high_probability => 1.0
    )
    port (
        clk   => clk,
        adr   => wbs_adr,
        dat_i => wbs_dat,
        dat_o => wbs_dat,
        sel   => wbs_sel,
        cyc   => wbs_cyc,
        stb   => wbs_stb,
        we    => wbs_wen,
        stall => wbs_stl,
        ack   => wbs_ack
    );

end architecture;
