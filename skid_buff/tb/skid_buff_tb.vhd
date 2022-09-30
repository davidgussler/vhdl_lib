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
--     Simple Testbench for FIFO module 
-- 
-- ###############################################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

entity skid_buff_tb is
end entity skid_buff_tb;

architecture bench of skid_buff_tb is
    ----------------------------------------------------------------------------
    -- TB level signals 
    ----------------------------------------------------------------------------
    constant CLK_FREQ   : real := 100.0E+6;
    constant CLK_PERIOD : time := (1.0E9 / CLK_FREQ) * 1 NS;
    constant CLK_TO_Q   : time := 1 NS;

    constant C_WIDTH : integer := 32;

    signal i_clk   : std_logic := '0';
    signal i_rst   : std_logic := '0';
    signal o_ready : std_logic;
    signal i_valid : std_logic := '0';
    signal i_data  : std_logic_vector(C_WIDTH-1 downto 0) := (others=>'0');
    signal i_ready : std_logic := '1';
    signal o_valid : std_logic;
    signal o_data  : std_logic_vector(C_WIDTH-1 downto 0);


    signal trans_request : std_logic := '0';

begin
    ----------------------------------------------------------------------------
    -- Instantiate the DUT 
    ----------------------------------------------------------------------------
    dut : entity work.skid_buff(rtl)
    generic map (
        G_WIDTH    => C_WIDTH,
        G_REG_OUTS => FALSE
    )
    port map (
        i_clk   => i_clk,
        i_rst   => i_rst,

        o_ready => o_ready,
        i_valid => i_valid,
        i_data  => i_data,

        i_ready => i_ready,
        o_valid => o_valid,
        o_data  => o_data
    );

    -- -- slave side only 
    -- process (i_clk)
    -- begin
    --     if rising_edge(i_clk) then

    --         i_ready <= i_valid;

    --         if (trans_request = '1') then
    --             i_valid <= '1';
    --             i_data <= std_logic_vector(unsigned(i_data)+1);
    --         elsif (o_ready = '1') then
    --             i_valid <= '0'; 
    --         end if; 
    --     end if;
    -- end process;


    ----------------------------------------------------------------------------
    -- Generate the clock
    ----------------------------------------------------------------------------
    clk_process : process 
    begin
        i_clk <= '1';
        wait for CLK_PERIOD / 2;
        i_clk <= '0';
        wait for CLK_PERIOD / 2;
    end process;


    stim_process: process

        ------------------------------------------------------------------------
        -- Define test procedures
        ------------------------------------------------------------------------

        procedure test_1 is
        begin

            req_loop : for i in 0 to 9 loop
                wait until rising_edge(i_clk);
                trans_request <= '1';
                wait until rising_edge(i_clk);
                trans_request <= '0';
                wait until rising_edge(i_clk);
            end loop;

            wait until rising_edge(i_clk);
            wait until rising_edge(i_clk);
            wait until rising_edge(i_clk);
            wait until rising_edge(i_clk);
            wait until rising_edge(i_clk);

        end procedure;


    ----------------------------------------------------------------------------
    -- Call test procedures
    ----------------------------------------------------------------------------
    begin
        test_1;

        wait for CLK_PERIOD * 10;
        assert FALSE
            report "Simulation Ended"
            severity failure;
        wait;
    end process;

end architecture bench;
