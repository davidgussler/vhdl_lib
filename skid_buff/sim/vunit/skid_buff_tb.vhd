-- ###############################################################################################
-- # << Skid Buffer Testbench >> #
-- *********************************************************************************************** 
-- Copyright David N. Gussler 2022
-- *********************************************************************************************** 
-- File     : skid_buff_tb.vhd
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

library ieee;
context ieee.ieee_std_context;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.vc_context;

entity skid_buff_tb is
    generic (runner_cfg : string);
end entity;

architecture tb of skid_buff_tb is
    -- Simulation Signals / Constants
    constant C_CLK_PERIOD : time := 10 ns; 
    constant C_CLK_TO_Q : time := 1 ns;

    constant C_NUM_XACTIONS : positive := 10;

    signal clk   : std_logic := '0';
    signal rst   : std_logic := '0';
    signal rstn  : std_logic := '1';
    signal stall : std_logic := '0'; 

    signal start : boolean := false;
    signal done  : boolean := false;


    -- DUT Generics / Signals
    constant C_WIDTH : positive := 8; 
    constant C_REG_OUTPUTS : boolean := false; 


    signal o_ready : std_logic;
    signal i_valid : std_logic := '0';
    signal i_data  : std_logic_vector(C_WIDTH-1 downto 0) := (others=>'0');
    signal i_ready : std_logic := '1';
    signal o_valid : std_logic;
    signal o_data  : std_logic_vector(C_WIDTH-1 downto 0);


    -- BFMs
    constant master_axis : axi_stream_master_t := new_axi_stream_master(
        data_length => C_WIDTH--,
        --stall_config => new_stall_config(0.2, 1, 10)
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
                wait for 15 * C_CLK_PERIOD;
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


    -- Input Stimulus ----------------------------------------------------------
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


    -- Output Response ----------------------------------------------------------
    -- -------------------------------------------------------------------------
    prc_receiver_side : process(all)
    begin
        if (stall) then
            i_ready <= '0';
        else 
            i_ready <= '1';
        end if;
    end process;

    prc_stall : process
    begin
        stall <= '0';
        wait until rising_edge(o_valid);
        stall <= '1';
        wait for C_CLK_PERIOD*5;
    end process;

    
    -- TB Signals --------------------------------------------------------------
    -- -------------------------------------------------------------------------
    clk <= not clk after C_CLK_PERIOD / 2;
    rstn <= not rst;


    -- DUT ---------------------------------------------------------------------
    -- -------------------------------------------------------------------------
    dut : entity work.skid_buff
    generic map (
        G_WIDTH    => C_WIDTH,
        G_REG_OUTS => C_REG_OUTPUTS
    )
    port map (
        i_clk   => clk,
        i_rst   => rst,

        o_ready => o_ready,
        i_valid => i_valid,
        i_data  => i_data,

        i_ready => i_ready,
        o_valid => o_valid,
        o_data  => o_data
    );


    -- AXIS Master BFM VC ------------------------------------------------------
    -- -------------------------------------------------------------------------
    axis_m_bfm : entity vunit_lib.axi_stream_master
    generic map (
        master       => master_axis
    )
    port map (
        aclk         => clk,    
        areset_n     => rstn,   
        tvalid       => i_valid,
        tready       => o_ready,
        tdata        => i_data 
    );
      
end architecture;
