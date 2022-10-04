-- #############################################################################
-- # << Skid Buffer >> #
-- *****************************************************************************
-- Copyright David N. Gussler 2022
-- *****************************************************************************
-- File     : skid_buff.vhd
-- Author   : David Gussler - davidnguss@gmail.com 
-- Language : VHDL '08
-- History  :  Date      | Version | Comments 
--            --------------------------------
--            09-29-2022 | 1.0     | Initial 
-- *****************************************************************************
-- Description : 
--    Skid Buffer with optional output registers. o_ready will always be
--    registered. Using this module with G_REG_OUTS=0 will incur zero latency
--    and register o_ready. Using this module with G_REG_OUTS=1 will incur 
--    one cycle of latency, but add a full pipeline "slice." 
--    This module can be inserted into the critical path of a valid/ready 
--    handshake protocal to pipeline the logic while maintaining 100 percent 
--    thruput.
--
--    Source that explains the theory:
--    https://zipcpu.com/blog/2019/05/22/skidbuffer.html
--
-- Generics
--   G_WIDTH    : positive := 32
--     Data width 
--   G_REG_OUTS : boolean := FALSE
--     Register outputs; With this disabled, only o_ready is registered
--     With this enabled, o_valid and o_data are also registered (useful for 
--     pipelining longer paths), but the data will take an extra clockcycle
--     to reach its destination.
-- #############################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity skid_buff is 
    generic(
        G_WIDTH    : positive := 32;
        G_REG_OUTS : boolean := FALSE
    );
    port(
        i_clk : in std_logic;
        i_rst : in std_logic;

        -- Input Interface (Master Side)
        i_valid : in  std_logic;
        o_ready : out std_logic;
        i_data  : in  std_logic_vector(G_WIDTH-1 downto 0);

        -- Output Interface (Slave Side)
        o_valid : out std_logic;
        i_ready : in  std_logic;
        o_data  : out std_logic_vector(G_WIDTH-1 downto 0)

    );
end skid_buff;


architecture rtl of skid_buff is
    -- Registers
    signal r_idata : std_logic_vector(G_WIDTH-1 downto 0);
    signal r_valid : std_logic;
    signal r_oready : std_logic;

    -- Wires
    signal ovalid : std_logic;
    signal odata  : std_logic_vector(G_WIDTH-1 downto 0);
    signal slave_not_stalled : std_logic;
    signal m_sending_s_stalled : std_logic;

begin
    -- Async -------------------------------------------------------------------
    -- -------------------------------------------------------------------------
    odata <= r_idata when r_valid else i_data;
    ovalid <= i_valid or r_valid;
    o_ready <= r_oready;

    slave_not_stalled <= '1' when ((not ovalid) or i_ready) else '0';
    m_sending_s_stalled <= '1' when 
        (i_valid and r_oready) and (ovalid and (not i_ready))
        else '0';

    -- Sync --------------------------------------------------------------------
    -- -------------------------------------------------------------------------
    process (i_clk)
    begin
        if rising_edge(i_clk) then
            if (i_rst) then
                r_valid <= '0';
                r_oready <= '1';
            else 
                -- Master is sending data, but the slave side is stalled
                if (m_sending_s_stalled) then
                    r_valid <= '1';
                    r_oready <= '0';
                -- Output is not stalled
                elsif (i_ready) then
                    r_valid <= '0';
                    r_oready <= '1';
                end if;
            end if;
        end if;
    end process;

    process (i_clk)
    begin
        if rising_edge(i_clk) then
            if (m_sending_s_stalled) then
                r_idata <= i_data;
            end if;
        end if;
    end process;


    -- Optional Output Registers -----------------------------------------------
    -- -------------------------------------------------------------------------
    -- if slave side is NOT stalled, then the next data/valid can update
    -- but if the slave is stalled, then the next data/valid should
    -- stay equal to the last. Basics of how an axi master works.
    -- This expression: "not (ovalid = '1' and i_ready = '0')"
    -- is logically equivilant to this one:
    -- (ovalid = '0' or i_ready = '1')
    gen_reg_outs_true : if G_REG_OUTS = TRUE generate
        process (i_clk)
        begin
            if rising_edge(i_clk) then
                if (i_rst) then
                    o_valid <= '0';
                elsif (slave_not_stalled) then
                    o_valid <= ovalid;
                end if;
            end if; 
        end process;

        process (i_clk)
        begin
            if rising_edge(i_clk) then
                if (slave_not_stalled) then
                    o_data <= odata;
                end if;
            end if;
        end process;

    end generate;

    gen_reg_outs_false : if G_REG_OUTS = FALSE generate
        o_data <= odata;
        o_valid <= ovalid; 
    end generate;

end rtl;
