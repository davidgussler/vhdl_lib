-- ###############################################################################################
-- # << FIFO Testbench >> #
-- *********************************************************************************************** 
-- Copyright David N. Gussler 2022
-- *********************************************************************************************** 
-- File     : skid_buff_tb.vhd
-- Author   : David Gussler - davidnguss@gmail.com 
-- Language : VHDL '08
-- History  :  Date      | Version | Comments 
--            --------------------------------
--            07-05-2022 | 1.0     | Initial 
-- *********************************************************************************************** 
-- Description : 
-- 
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
    constant C_REG_OUTPUTS : boolean := true; 


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
        if (o_valid and stall) then
            i_ready <= '0';
        else 
            i_ready <= '1';
        end if;
    end process;

    process (clk)
        variable count : natural := 0;
    begin
        if rising_edge(clk) then
            if (done) then
                count := count+1;
                report "hello world";
            end if;

            if ((count > 2) and (count < 6)) then
                stall <= '1';
            else 
                stall <= '0';
            end if; 

        end if;
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







-- entity skid_buff_tb is
-- end entity skid_buff_tb;

-- architecture bench of skid_buff_tb is
--     ----------------------------------------------------------------------------
--     -- TB level signals 
--     ----------------------------------------------------------------------------
--     constant CLK_FREQ   : real := 100.0E+6;
--     constant CLK_PERIOD : time := (1.0E9 / CLK_FREQ) * 1 NS;
--     constant CLK_TO_Q   : time := 1 NS;

--     constant C_WIDTH : integer := 32;

--     signal i_clk   : std_logic := '0';
--     signal i_rst   : std_logic := '0';
--     signal o_ready : std_logic;
--     signal i_valid : std_logic := '0';
--     signal i_data  : std_logic_vector(C_WIDTH-1 downto 0) := (others=>'0');
--     signal i_ready : std_logic := '1';
--     signal o_valid : std_logic;
--     signal o_data  : std_logic_vector(C_WIDTH-1 downto 0);


--     signal trans_request : std_logic := '0';

-- begin
--     ----------------------------------------------------------------------------
--     -- Instantiate the DUT 
--     ----------------------------------------------------------------------------
--     dut : entity work.skid_buff(rtl)
--     generic map (
--         G_WIDTH    => C_WIDTH,
--         G_REG_OUTS => FALSE
--     )
--     port map (
--         i_clk   => i_clk,
--         i_rst   => i_rst,

--         o_ready => o_ready,
--         i_valid => i_valid,
--         i_data  => i_data,

--         i_ready => i_ready,
--         o_valid => o_valid,
--         o_data  => o_data
--     );

--     -- -- slave side only 
--     -- process (i_clk)
--     -- begin
--     --     if rising_edge(i_clk) then

--     --         i_ready <= i_valid;

--     --         if (trans_request = '1') then
--     --             i_valid <= '1';
--     --             i_data <= std_logic_vector(unsigned(i_data)+1);
--     --         elsif (o_ready = '1') then
--     --             i_valid <= '0'; 
--     --         end if; 
--     --     end if;
--     -- end process;
    
--     -- Simple AXIS master

--     slave_not_stalled <= '1' when ovalid = '0' or i_ready = '1' else '0';
--     process (i_clk)
--     begin
--         if rising_edge(i_clk) then
--             if (i_rst = '1') then
--                 o_valid <= '0';
--             elsif (slave_not_stalled = '1') then
--                 o_valid <= ovalid_request;
--             end if;
--         end if; 
--     end process;

--     process (i_clk)
--     begin
--         if rising_edge(i_clk) then
--             if (slave_not_stalled = '1') then
--                 o_data <= odata_request;
--             end if;
--         end if;
--     end process;


--     ----------------------------------------------------------------------------
--     -- Generate the clock
--     ----------------------------------------------------------------------------
--     clk_process : process 
--     begin
--         i_clk <= '1';
--         wait for CLK_PERIOD / 2;
--         i_clk <= '0';
--         wait for CLK_PERIOD / 2;
--     end process;


--     stim_process: process

--         ------------------------------------------------------------------------
--         -- Define test procedures
--         ------------------------------------------------------------------------

--         procedure test_1 is
--         begin

--             req_loop : for i in 0 to 9 loop
--                 wait until rising_edge(i_clk);
--                 trans_request <= '1';
--                 wait until rising_edge(i_clk);
--                 trans_request <= '0';
--                 wait until rising_edge(i_clk);
--             end loop;

--             wait until rising_edge(i_clk);
--             wait until rising_edge(i_clk);
--             wait until rising_edge(i_clk);
--             wait until rising_edge(i_clk);
--             wait until rising_edge(i_clk);

--         end procedure;


--     ----------------------------------------------------------------------------
--     -- Call test procedures
--     ----------------------------------------------------------------------------
--     begin
--         test_1;

--         wait for CLK_PERIOD * 10;
--         assert FALSE
--             report "Simulation Ended"
--             severity failure;
--         wait;
--     end process;

-- end architecture bench;
