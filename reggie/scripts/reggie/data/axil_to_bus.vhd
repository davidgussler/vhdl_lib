-- #############################################################################
-- #  << AXI4-Lite to Simple Bus Adaptor >>
-- # ===========================================================================
-- # File     : axil_to_bus.vhd
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
-- # This module translates an AXI interface to a simplified bus interface to 
-- # make downstream user logic simpler by abstracting away the complexities of 
-- # AXI. It is able to maintain 100% thruput as long as 
-- # the master doesn't stall and the master sets a valid write address and write 
-- # data on the same cycle. No bubble cycles inserted here.
-- #
-- # This module addds no latency or pipelining. If that is needed to ease timing,
-- # use the axil_pipe module along with this one.
-- #############################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.gen_utils_pkg.all;

entity axil_to_bus is 
    port(
        i_clk : in std_logic;
        i_rst : in std_logic;

        -- AXI4-Lite Slave
        i_s_axil : in  axil_req_t;
        o_s_axil : out axil_resp_t;

        -- Simple Bus Master
        i_m_bus : in  bus_resp_t; 
        o_m_bus : out bus_req_t
    );
end entity;


architecture rtl of axil_to_bus is 
    
    signal awvalid : std_logic;
    signal wr_en : std_logic;
    signal awaddr  : std_logic_vector(31 downto 0);

    signal wvalid : std_logic;
    signal wready : std_logic;
    signal wdata  : std_logic_vector(31 downto 0);

    signal arvalid : std_logic;
    signal rd_en : std_logic;
    signal araddr  : std_logic_vector(31 downto 0);

begin
    -- -------------------------------------------------------------------------
    -- Writes
    -- -------------------------------------------------------------------------

    -- Write Address
    u_aw_skid_buff : entity work.skid_buff
    generic map (
        G_WIDTH    => i_s_axil.awaddr'LENGTH,
        G_REG_OUTS => FALSE
    )
    port map (
        i_clk   => i_clk,
        i_rst   => i_rst,

        i_valid => i_s_axil.awvalid,
        o_ready => o_s_axil.awready,
        i_data  => i_s_axil.awaddr, 

        o_valid => awvalid,
        i_ready => wr_en,
        o_data  => awaddr
    );

    -- Write Data
    u_w_skid_buff : entity work.skid_buff
    generic map (
        G_WIDTH    => i_s_axil.wdata'LENGTH,
        G_REG_OUTS => FALSE
    )
    port map (
        i_clk   => i_clk,
        i_rst   => i_rst,

        i_valid => i_s_axil.wvalid,
        o_ready => o_s_axil.wready,
        i_data  => i_s_axil.wdata,

        o_valid => wvalid,
        i_ready => wr_en,
        o_data  => wdata
    );
    -- Enable a write if both the write address and write data are valid
    -- Also, we can't enable a new write if the last write response has been stalled
    wr_en <= awvalid and wvalid and not (o_s_axil.bvalid and not i_s_axil.bready);

    process (i_clk) begin
        if rising_edge(i_clk) then
            if i_rst then
                o_s_axil.bvalid <= '0'; 
            else
                -- Set write response to valid the cycle after the write request 
                -- since our simple bus always responds in one cycle
                if wr_en then
                    o_s_axil.bvalid <= '1';
                
                -- Don't have to check for valid here because if we've made it to 
                -- this point in the if statement then we know that valid has 
                -- already been set
                elsif i_s_axil.bready then -- and bvalid
                    o_s_axil.bvalid <= '0'; 
                end if;
            end if; 
        end if;
    end process;
    -- Always respond with OKAY
    o_s_axil.bresp <= AXI_RESP_OKAY; 

    o_m_bus.wen <= wr_en; 
    o_m_bus.waddr <= awaddr;
    o_m_bus.wdata <= wdata;


    -- -------------------------------------------------------------------------
    -- Reads
    -- -------------------------------------------------------------------------

    -- Read Address
    u_ar_skid_buff : entity work.skid_buff
    generic map (
        G_WIDTH    => 32,
        G_REG_OUTS => FALSE
    )
    port map (
        i_clk   => i_clk,
        i_rst   => i_rst,

        i_valid => i_s_axil.arvalid,
        o_ready => o_s_axil.arready,
        i_data  => i_s_axil.araddr,

        o_valid => arvalid,
        i_ready => rd_en,
        o_data  => araddr
    );
    -- Enable a read if the read address is valid
    -- Also, we can't enable a new read if the last read response has been stalled
    rd_en <= arvalid and not (o_s_axil.rvalid and not i_s_axil.rready);

    process (i_clk) begin
        if rising_edge(i_clk) then
            if i_rst then
                o_s_axil.rvalid <= '0'; 
            else
                if rd_en then
                    o_s_axil.rvalid <= '1';
                elsif i_s_axil.rready then -- and rvalid
                    o_s_axil.rvalid <= '0'; 
                end if;
            end if; 
        end if;
    end process;
    -- Always respond with OKAY
    o_s_axil.rresp <= AXI_RESP_OKAY; 
    o_s_axil.rdata <= i_m_bus.rdata;
    
    o_m_bus.ren <= rd_en; 
    o_m_bus.raddr <= araddr;

end architecture;

