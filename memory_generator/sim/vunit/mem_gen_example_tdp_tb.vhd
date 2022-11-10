
library ieee;
context ieee.ieee_std_context;

library vunit_lib;
context vunit_lib.vunit_context;

entity mem_gen_example_tdp_tb is
    generic (runner_cfg : string);
end entity;

architecture tb of mem_gen_example_tdp_tb is
    -- Simulation Signals / Constants
    constant C_CLK_PERIOD : time := 10 ns; 
    constant C_CLK_TO_Q : time := 1 ns;
    constant C_NUM_XACTIONS : positive := 10;

    signal clk   : std_logic := '0';
    signal rst   : std_logic := '0';
    signal rstn  : std_logic := '1';

    signal start : boolean := false;
    signal done  : boolean := false;


    signal a_en  : std_logic := '0';
    signal a_we  : std_logic_vector(3 downto 0) := (others=>'0');
    signal a_addr: std_logic_vector(9 downto 0):= (others=>'0');
    signal a_wdat: std_logic_vector(31 downto 0):= (others=>'0');
    signal a_rdat: std_logic_vector(31 downto 0):= (others=>'0');

    signal b_en  : std_logic := '0';
    signal b_we  : std_logic_vector(3 downto 0):= (others=>'0');
    signal b_addr: std_logic_vector(9 downto 0):= (others=>'0');
    signal b_wdat: std_logic_vector(31 downto 0):= (others=>'0');
    signal b_rdat: std_logic_vector(31 downto 0):= (others=>'0');


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
            a_en   <= '1';
            a_we   <= x"F";
            a_addr <= b"1010101010";
            a_wdat <= x"DEAD_BEEF";
            wait until rising_edge(clk);
            a_en   <= '0';
            a_we   <= x"0";

            wait until rising_edge(clk);
            wait until rising_edge(clk);
            wait until rising_edge(clk);
            wait until rising_edge(clk);
            wait until rising_edge(clk);
            b_en   <= '1';
            b_addr <= b"1010101010";
            wait until rising_edge(clk);
            wait until rising_edge(clk);
            wait until rising_edge(clk);
            wait until rising_edge(clk);
            wait until rising_edge(clk);
            assert a_wdat = b_rdat; 
            wait until rising_edge(clk);
            b_en   <= '0';
            wait until rising_edge(clk);

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
    u_dut : entity work.mem_gen_example_tdp
    port map(
        -- Port A
        i_a_clk  => clk ,
        i_a_en   => a_en  ,
        i_a_we   => a_we  ,
        i_a_addr => a_addr,
        i_a_wdat => a_wdat,
        o_a_rdat => a_rdat,

        -- Port B
        i_b_clk  => clk ,
        i_b_en   => b_en  ,
        i_b_we   => b_we  ,
        i_b_addr => b_addr,
        i_b_wdat => b_wdat,
        o_b_rdat => b_rdat
    );

end architecture;
