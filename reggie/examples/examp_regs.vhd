library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.gen_utils_pkg.all;
use work.examp_regs_pkg.all; 

entity examp_regs is
    port (
        i_clk : in std_logic;
        i_rst : in std_logic;

        -- AXI4-Lite Slave Interface
        i_s_axil : in  axil_req_t; 
        o_s_axil : out axil_resp_t;

        -- Register Interface
        o_ctl : out examp_regs_ctl_t;
        i_sts : in  examp_regs_sts_t;
        i_irq : in  examp_regs_irq_t;

        -- Register R/W Indication Interface
        o_rd : out examp_regs_rw_t;
        o_wr : out examp_regs_rw_t
    );
end entity examp_regs;

architecture rtl of examp_regs is

    constant REG_ADR : := 
    constant REG_TYPE : := 
    constant REG_RST_VAL : := 

    signal bus_req : bus_req_t; 
    signal bus_resp : bus_resp_t;

begin

    u_examp_regs_axil_to_bus : entity work.axil_to_bus
    port map (
        i_clk      => i_clk,
        i_rst      => i_rst,
        i_s_axil   => i_s_axil,
        o_s_axil   => o_s_axil,
        i_m_bus    => bus_resp,
        o_m_bus    => bus_req
    );

    u_examp_regs_reggie : entity work.reggie
    generic map (
        G_NUM_REGS     => 11,
        G_REG_ADR      => REG_ADR,
        G_REG_TYPE     => REG_TYPE,
        G_REG_RST_VAL  => REG_RST_VAL
    )
    port map (
        i_clk   => i_clk,
        i_rst   => i_rst,
        i_s_bus => bus_req,
        o_s_bus => bus_resp,
        o_ctl   => o_ctl,
        i_sts   => i_sts,
        i_irq   => i_irq,
        o_rd    => o_rd,
        o_wr    => o_wr
    );
end architecture;