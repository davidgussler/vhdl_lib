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
-- # 
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
    
    signal arvalid : std_logic;
    signal arready : std_logic;
    signal araddr  : std_logic_vector(31 downto 0);

begin
    -- INPUT SIDE
    -- read address
    -- i_s_axil.arvalid
    -- o_s_axil.arready
    -- i_s_axil.araddr

    -- -- write address 
    -- i_s_axil.awvalid
    -- o_s_axil.awready
    -- i_s_axil.awaddr

    -- -- write data 
    -- i_s_axil.wvalid 
    -- o_s_axil.wready 
    -- i_s_axil.wdata  


    -- -- OUTPUT SIDE
    -- -- read response
    -- o_s_axil.rvalid 
    -- i_s_axil.rready 
    -- o_s_axil.rdata  
    -- o_s_axil.rresp <= AXI_RESP_OKAY; 

    -- -- write response
    -- o_s_axil.bvalid 
    -- i_s_axil.bready 
    -- o_s_axil.bresp <= AXI_RESP_OKAY; 


    -- o_m_bus.wen  
    -- o_m_bus.waddr
    -- o_m_bus.wdata

    -- i_m_bus.rdata
    -- o_m_bus.ren
    -- o_m_bus.raddr


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
        i_ready => arready,
        o_data  => araddr
    );
    arready <= i_s_axil.rready;

    process (i_clk) begin
        if rising_edge(i_clk) then
            if i_rst then

            else
                if arvalid and arready then
                    o_m_bus.ren <= '1'; 
                    o_m_bus.raddr <= araddr; 
                else 
                    o_m_bus.ren <= '0';
                end if;
            end if; 
        end if;
    end process;

    process (i_clk) begin
        if rising_edge(i_clk) then
            if i_rst then

            else
                if o_m_bus.ren then
                    o_s_axil.rvalid <= '1'; 
                    o_s_axil.rdata <= i_m_bus.rdata;
                end if;
            end if; 
        end if;
    end process;
  
    









    -- -- Write Address
    -- u_aw_skid_buff : entity work.skid_buff
    -- generic map (
    --     G_WIDTH    => 32,
    --     G_REG_OUTS => FALSE
    -- )
    -- port map (
    --     i_clk   => i_clk,
    --     i_rst   => i_rst,

    --     i_valid => i_s_axil.awvalid,
    --     o_ready => o_s_axil.awready,
    --     i_data  => i_s_axil.awaddr, 

    --     o_valid => awvalid,
    --     i_ready => awready,
    --     o_data  => awaddr,
    -- );

    -- -- Write Data
    -- u_w_skid_buff : entity work.skid_buff
    -- generic map (
    --     G_WIDTH    => 32,
    --     G_REG_OUTS => FALSE
    -- )
    -- port map (
    --     i_clk   => i_clk,
    --     i_rst   => i_rst,

    --     i_valid => i_s_axil.wvalid,
    --     o_ready => o_s_axil.wready,
    --     i_data  => i_s_axil.waddr,

    --     o_valid => wvalid,
    --     i_ready => wready,
    --     o_data  => waddr,
    -- );


end architecture;