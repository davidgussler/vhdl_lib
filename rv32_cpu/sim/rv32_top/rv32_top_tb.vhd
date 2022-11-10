

library ieee;
context ieee.ieee_std_context;

library vunit_lib;
context vunit_lib.vunit_context;

use work.rv32_testbench_pkg.all;
use work.gen_utils_pkg.all;

entity rv32_top_tb is
    generic (runner_cfg : string);
end entity;

architecture tb of rv32_top_tb is

    -- Simulation Signals / Constants
    constant C_CLK_PERIOD : time := 10 ns; 
    constant C_CLK2Q      : time := 1 ns;

    signal clk   : std_logic := '0';
    signal rst   : std_logic := '0';
    signal rstn  : std_logic := '1';

    -- Simple test programs
    constant ITYPE_TEST : slv_array_t(0 to 1023)(31 downto 0) := (
        rv_addi(1, 0, 1),  -- 1
        rv_addi(2, 0, 2),  -- 2
        rv_slti(3, 2, 3),  -- 1
        rv_slti(4, 2,-3),  -- 0
        rv_sltui(5, 2, 3), -- 1
        rv_sltui(6, 2, 2), -- 0
        rv_xori(7, 2, 2),  -- 0   
        rv_ori(8, 0, 123), -- 123
        rv_andi(9, 1, 3),  -- 1
        rv_slli(10, 2, 4), -- 16
        rv_srli(11, 2, 1), -- 1
        rv_srai(12, 2, 2), -- 0
        others => (others=>'0')
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
                rst <= '1', '0' after 16 * C_CLK_PERIOD;

                wait for 200 * C_CLK_PERIOD;
            end if;
        end loop;

        test_runner_cleanup(runner);
    end process;

    -- TB Signals --------------------------------------------------------------
    -- -------------------------------------------------------------------------
    clk <= not clk after C_CLK_PERIOD / 2;
    rstn <= not rst;

    -- DUT ---------------------------------------------------------------------
    -- -------------------------------------------------------------------------
    u_dut : entity work.rv32_top
        generic map (
            G_USE_INT_MEM        => TRUE,
            G_INT_MEM_BASE_ADDR  => x"0000_0000",
            G_INT_MEM_SIZE_BYTES => INT_MEM_SIZE_BYTES, 
            G_INT_MEM_INIT       => ITYPE_TEST
        )
        port map (
            -- Clock & Reset
            i_clk => clk,
            i_rst => rst
        );
    end entity;
    


end architecture;
