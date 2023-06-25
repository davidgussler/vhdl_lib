-- #############################################################################
-- #  << Skid Buffer >>
-- # ===========================================================================
-- # File     : skid_buff.vhd
-- # Author   : David Gussler - david.gussler@proton.me
-- # Language : VHDL '08
-- # ===========================================================================
-- # BSD 2-Clause License
-- # 
-- # Copyright (c) 2022-2023, David Gussler. All rights reserved.
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
-- # Skid Buffer with optional output registers. o_ready will always be
-- # registered. Using this module with G_REG_OUTS=0 will incur zero latency
-- # and register o_ready. Using this module with G_REG_OUTS=1 will incur 
-- # one cycle of latency, but add a full pipeline "slice." 
-- # This module can be inserted into the critical path of a valid/ready 
-- # handshake protocal to pipeline the logic while maintaining 100 percent 
-- # thruput.
-- # This logic can be pretty confusing to understand but I promise it works :) 
-- # The beauty is that this can easilly be dropped in somewhere without needing 
-- # to think thru the complicated implementation details. 
-- #
-- # Source: https://zipcpu.com/blog/2019/05/22/skidbuffer.html
-- # 
-- #############################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity skid_buff is 
    generic(
        -- Data width 
        G_WIDTH    : positive := 32;

        -- Register outputs; With this disabled, only o_ready is registered
        -- With this enabled, o_valid and o_data are also registered (useful for 
        -- pipelining longer paths), but the data will take an extra clockcycle
        -- to reach its destination.
        G_REG_OUTS : boolean  := FALSE
    );
    port(
        i_clk : in std_logic;
        i_rst : in std_logic;

        -- Input Interface 
        i_valid : in  std_logic;
        o_ready : out std_logic;
        i_data  : in  std_logic_vector(G_WIDTH-1 downto 0);

        -- Output Interface 
        o_valid : out std_logic;
        i_ready : in  std_logic;
        o_data  : out std_logic_vector(G_WIDTH-1 downto 0)

    );
end skid_buff;


architecture rtl of skid_buff is
    -- Registers
    signal r_idata : std_logic_vector(G_WIDTH-1 downto 0);
    signal r_valid : std_logic;

    -- Wires
    signal ovalid : std_logic;
    signal odata  : std_logic_vector(G_WIDTH-1 downto 0);
    signal slave_not_stalled : std_logic;
    signal m_sending_s_stalled : std_logic;

begin
    odata  <= r_idata when r_valid else i_data;
    ovalid <= i_valid or r_valid;

    slave_not_stalled   <= not ovalid or i_ready;
    m_sending_s_stalled <= (i_valid and o_ready) and (ovalid and not i_ready);

    sp_valid_ready : process (i_clk)
    begin
        if rising_edge(i_clk) then
            if (i_rst) then
                r_valid <= '0';
                o_ready <= '1';
            else 
                -- Master is sending data, but the slave side is stalled
                if (m_sending_s_stalled) then
                    r_valid <= '1';
                    o_ready <= '0';
                -- Output is not stalled
                elsif (i_ready) then
                    r_valid <= '0';
                    o_ready <= '1';
                end if;
            end if;
        end if;
    end process;

    sp_data_reg : process (i_clk)
    begin
        if rising_edge(i_clk) then
            if (m_sending_s_stalled) then
                r_idata <= i_data;
            end if;
        end if;
    end process;


    -- Optional Output Registers -----------------------------------------------
    -- -------------------------------------------------------------------------
    -- If slave side is NOT stalled, then the next data/valid can update
    -- but if the slave is stalled, then the next data/valid should
    -- stay equal to the last. Basics of how an axi master works.
    -- This expression: "not (ovalid = '1' and i_ready = '0')"
    -- is logically equivilant to this one:
    -- (ovalid = '0' or i_ready = '1')
    ig_reg_outs_true : if (G_REG_OUTS = TRUE) generate
        sp_reg_outs : process (i_clk)
        begin
            if rising_edge(i_clk) then
                if (i_rst) then
                    o_valid <= '0';
                    o_data  <= (others=>'-');
                elsif (slave_not_stalled) then
                    o_valid <= ovalid;
                    o_data  <= odata;
                end if;
            end if; 
        end process;
    end generate;

    ig_reg_outs_false : if (G_REG_OUTS = FALSE) generate
        o_valid <= ovalid; 
        o_data  <= odata;
    end generate;

end rtl;
