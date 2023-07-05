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
-- # Can add a configurable number of stages using G_NUM_STAGES.
-- # No bubbles. ie: can maintain 100% thruput.
-- #############################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.gen_utils_pkg.all;

entity axil_pipe is
    generic(
        -- Number of pipeline stages. More stages = more registers and more latency.
        -- If 0 is used, then this module does nothing and just acts as a passthru.
        G_NUM_STAGES : natural := 1
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

    signal req : axil_req_array_t(0 to G_NUM_STAGES);
    signal resp : axil_resp_array_t(0 to G_NUM_STAGES);

begin 

    req(0) <= i_s_axil; 
    resp(0) <= i_m_axil;
    o_s_axil <= resp(G_NUM_STAGES); 
    o_m_axil <= req(G_NUM_STAGES); 

    gen_stages_if : if G_NUM_STAGES > 0 generate
        gen_stages_for : for i in 0 to G_NUM_STAGES-1 generate

            signal aw_reg : std_logic_vector(i_s_axil.awaddr'LENGTH + i_s_axil.awprot'LENGTH - 1 downto 0);
            signal ar_reg : std_logic_vector(i_s_axil.araddr'LENGTH + i_s_axil.arprot'LENGTH - 1 downto 0);
            signal r_reg  : std_logic_vector(i_m_axil.rdata'LENGTH + i_m_axil.rresp'LENGTH - 1 downto 0);
            signal w_reg : std_logic_vector(i_s_axil.wdata'LENGTH + i_s_axil.wstrb'LENGTH - 1 downto 0);

        begin

            u_aw_skid_buff : entity work.skid_buff
            generic map (
                G_WIDTH    => i_s_axil.awaddr'LENGTH + i_s_axil.awprot'LENGTH,
                G_REG_OUTS => TRUE
            )
            port map (
                i_clk   => i_clk,
                i_rst   => i_rst,

                i_valid => req(i).awvalid,
                o_ready => resp(i+1).awready,
                i_data  => req(i).awaddr & req(i).awprot, 

                o_valid => req(i+1).awvalid,
                i_ready => resp(i).awready,
                o_data  => aw_reg 
            );
            req(i+1).awaddr <= aw_reg(i_s_axil.awaddr'LENGTH + i_s_axil.awprot'LENGTH - 1 downto i_s_axil.awprot'LENGTH);
            req(i+1).awprot <= aw_reg(i_s_axil.awprot'LENGTH-1 downto 0);


            u_w_skid_buff : entity work.skid_buff
            generic map (
                G_WIDTH    => i_s_axil.wdata'LENGTH + i_s_axil.wstrb'LENGTH,
                G_REG_OUTS => TRUE
            )
            port map (
                i_clk   => i_clk,
                i_rst   => i_rst,

                i_valid => req(i).wvalid,
                o_ready => resp(i+1).wready,
                i_data  => req(i).wdata & req(i).wstrb,

                o_valid => req(i+1).wvalid,
                i_ready => resp(i).wready,
                o_data  => w_reg 
            );
            req(i+1).wdata <= w_reg(i_s_axil.wdata'LENGTH + i_s_axil.wstrb'LENGTH-1 downto i_s_axil.wstrb'LENGTH);
            req(i+1).wstrb <= w_reg(i_s_axil.wstrb'LENGTH-1 downto 0);


            u_ar_skid_buff : entity work.skid_buff
            generic map (
                G_WIDTH    => i_s_axil.araddr'LENGTH + i_s_axil.arprot'LENGTH,
                G_REG_OUTS => TRUE
            )
            port map (
                i_clk   => i_clk,
                i_rst   => i_rst,

                i_valid => req(i).arvalid,
                o_ready => resp(i+1).arready,
                i_data  => req(i).araddr & req(i).arprot,

                o_valid => req(i+1).arvalid,
                i_ready => resp(i).arready,
                o_data  => ar_reg
            );
            req(i+1).araddr <= ar_reg(i_s_axil.araddr'LENGTH + i_s_axil.arprot'LENGTH-1 downto i_s_axil.arprot'LENGTH);
            req(i+1).arprot <= ar_reg(i_s_axil.arprot'LENGTH-1 downto 0);


            u_r_skid_buff : entity work.skid_buff
            generic map (
                G_WIDTH    => i_m_axil.rdata'LENGTH + i_m_axil.rresp'LENGTH,
                G_REG_OUTS => TRUE
            )
            port map (
                i_clk   => i_clk,
                i_rst   => i_rst,

                i_valid => resp(i).rvalid,
                o_ready => req(i+1).rready,
                i_data  => resp(i).rdata & i_m_axil.rresp,

                o_valid => resp(i+1).rvalid,
                i_ready => req(i).rready,
                o_data  => r_reg
            );
            resp(i+1).rdata <= r_reg(i_m_axil.rdata'LENGTH + i_m_axil.rresp'LENGTH-1 downto i_m_axil.rresp'LENGTH);
            resp(i+1).rresp <= r_reg(i_m_axil.rresp'LENGTH-1 downto 0);


            u_b_skid_buff : entity work.skid_buff
            generic map (
                G_WIDTH    => i_m_axil.bresp'LENGTH,
                G_REG_OUTS => TRUE
            )
            port map (
                i_clk   => i_clk,
                i_rst   => i_rst,

                i_valid => resp(i).bvalid,
                o_ready => req(i+1).bready,
                i_data  => resp(i).bresp,

                o_valid => resp(i+1).bvalid,
                i_ready => req(i).bready,
                o_data  => resp(i+1).bresp
            );

        end generate;
    end generate;

end architecture;
