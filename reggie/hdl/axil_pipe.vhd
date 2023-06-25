-- #############################################################################
-- #  << AXI4-Lite Pipe >>
-- # ===========================================================================
-- # File     : axil_pipe.vhd
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
-- # Pipeline module for an AXI-Lite Bus. This can be used to improve timing for
-- # long paths by breaking them up with registers and incurring a latency penalty.
-- # Can add a configurable number of stages using G_NUM_STAGES
-- #############################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.gen_utils_pkg.all;

entity axil_pipe is
    generic(
        G_NUM_STAGES : positive := 1
    );
    port(
        i_clk : in std_logic;
        i_rst : in std_logic;

        -- AXI4-Lite Slave
        i_s_axil : in  axil_req_t;
        o_s_axil : out axil_resp_t;

        -- AXI4-Lite Master
        i_m_axil : in  axil_resp_t; 
        o_m_axil : out axil_req_t
    );
end entity;

architecture rtl of axil_pipe is 
begin 
    u_aw_skid_buff : entity work.skid_buff
    generic map (
        G_WIDTH    => i_s_axil.awaddr'LENGTH + i_s_axil.awprot'LENGTH,
        G_REG_OUTS => TRUE
    )
    port map (
        i_clk   => i_clk,
        i_rst   => i_rst,

        i_valid => i_s_axil.awvalid,
        o_ready => o_s_axil.awready,
        i_data  => i_s_axil.awaddr & i_s_axil.awprot, 

        o_valid => o_m_axil.awvalid,
        i_ready => i_m_axil.awready,
        o_data  => o_m_axil.awaddr & o_m_axil.awprot
    );

    u_w_skid_buff : entity work.skid_buff
    generic map (
        G_WIDTH    => i_s_axil.wdata'LENGTH,
        G_REG_OUTS => TRUE
    )
    port map (
        i_clk   => i_clk,
        i_rst   => i_rst,

        i_valid => i_s_axil.wvalid,
        o_ready => o_s_axil.wready,
        i_data  => i_s_axil.wdata,

        o_valid => o_m_axil.wvalid,
        i_ready => i_m_axil.wready,
        o_data  => o_m_axil.wdata
    );

    u_ar_skid_buff : entity work.skid_buff
    generic map (
        G_WIDTH    => i_s_axil.araddr'LENGTH + i_s_axil.arprot'LENGTH,
        G_REG_OUTS => TRUE
    )
    port map (
        i_clk   => i_clk,
        i_rst   => i_rst,

        i_valid => i_s_axil.arvalid,
        o_ready => o_s_axil.arready,
        i_data  => i_s_axil.araddr & i_s_axil.arprot,

        o_valid => o_m_axil.arvalid,
        i_ready => i_m_axil.arready,
        o_data  => o_m_axil.araddr & o_m_axil.arprot
    );

    u_r_skid_buff : entity work.skid_buff
    generic map (
        G_WIDTH    => i_m_axil.rdata'LENGTH + i_m_axil.rresp'LENGTH,
        G_REG_OUTS => TRUE
    )
    port map (
        i_clk   => i_clk,
        i_rst   => i_rst,

        i_valid => i_m_axil.rvalid,
        o_ready => o_m_axil.rready,
        i_data  => i_m_axil.rdata & i_m_axil.rresp,

        o_valid => o_s_axil.rvalid,
        i_ready => i_s_axil.rready,
        o_data  => o_s_axil.rdata & o_s_axil.rresp
    );

    u_b_skid_buff : entity work.skid_buff
    generic map (
        G_WIDTH    => i_m_axil.bresp'LENGTH,
        G_REG_OUTS => TRUE
    )
    port map (
        i_clk   => i_clk,
        i_rst   => i_rst,

        i_valid => i_m_axil.bvalid,
        o_ready => o_m_axil.bready,
        i_data  => i_m_axil.bresp,

        o_valid => o_s_axil.bvalid,
        i_ready => i_s_axil.bready,
        o_data  => o_s_axil.bresp
    );
end architecture;