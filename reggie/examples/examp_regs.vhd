-- This file (and others like it) will eventually be generated by reggie

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.gen_utils_pkg.all;
use work.examp_regs_pkg.all; 

entity examp_regs is
    port (
        i_clk : in std_logic;
        i_rst : in std_logic;

        -- Bus Interface
        i_s_bus : in  bus_req_t; 
        o_s_bus : out bus_resp_t;

        -- Register Interface
        o_ctl : out examp_regs_ctl_t;
        i_sts : in  examp_regs_sts_t;

        -- Register R/W Indication Interface
        o_wr : out examp_regs_wr_t;
        o_rd : out examp_regs_rd_t
    );
end entity examp_regs;

architecture rtl of examp_regs is
    
    constant NUM_REGS : positive := 5;
    constant ADR_BITS : positive := 8;
    constant REG_ADR : slv_array_t(NUM_REGS-1 downto 0)(ADR_BITS-1 downto 0) := (
        0 => X"00",
        1 => X"04",
        2 => X"08",
        3 => X"0C",
        4 => X"68"
    ); 
    constant REG_RST_VAL : slv_array_t(NUM_REGS-1 downto 0)(31 downto 0) := (
        0 => X"0000_1234",
        1 => X"0000_0000",
        2 => X"0000_0000",
        3 => X"0000_0000",
        4 => X"0000_0000"
    );

    signal ctl : slv_array_t(NUM_REGS-1 downto 0)(31 downto 0);
    signal sts : slv_array_t(NUM_REGS-1 downto 0)(31 downto 0) := (others=>(others=>'0'));
    signal rd : std_logic_vector(NUM_REGS-1 downto 0);
    signal wr : std_logic_vector(NUM_REGS-1 downto 0); 

begin

    u_examp_regs_reg_bank : entity work.reg_bank
    generic map (
        G_NUM_REGS     => NUM_REGS,
        G_ADR_BITS     => ADR_BITS,
        G_REG_ADR      => REG_ADR,
        G_REG_RST_VAL  => REG_RST_VAL
    )
    port map (
        i_clk   => i_clk,
        i_rst   => i_rst,
        i_s_bus => i_s_bus,
        o_s_bus => o_s_bus,
        o_ctl   => ctl,
        i_sts   => sts,
        o_wr    => wr,
        o_rd    => rd
    );

    -- RW
    o_ctl.reg0.fld0 <= ctl(0)(0);
    o_ctl.reg0.fld1 <= ctl(0)(11 downto 8);
    o_ctl.reg1_arr(0).fld0 <= ctl(1)(0);
    o_ctl.reg1_arr(0).fld1 <= ctl(1)(15 downto 8);
    o_ctl.reg1_arr(1).fld0 <= ctl(2)(0);
    o_ctl.reg1_arr(1).fld1 <= ctl(2)(15 downto 8);
    sts(0)(0) <= ctl(0)(0);
    sts(0)(11 downto 8) <= ctl(0)(11 downto 8);
    sts(1)(0) <= ctl(1)(0);
    sts(1)(15 downto 8) <= ctl(1)(15 downto 8);
    sts(2)(0) <= ctl(2)(0);
    sts(2)(15 downto 8) <= ctl(2)(15 downto 8);

    -- RO
    sts(3)(31 downto 0) <= i_sts.reg2.fld0; 

    -- RWV
    o_ctl.reg3.fld0 <= ctl(4)(23 downto 0);
    sts(4)(23 downto 0) <= i_sts.reg3.fld0; 

    -- Read indication pulses
    o_rd.reg0 <= rd(0);
    o_rd.reg1_arr(0) <= rd(1);
    o_rd.reg1_arr(1) <= rd(2);
    o_rd.reg2 <= rd(3);
    o_rd.reg3 <= rd(4);

    -- Write indication pulses
    o_wr.reg0 <= wr(0);
    o_wr.reg1_arr(0) <= wr(1);
    o_wr.reg1_arr(1) <= wr(2);
    o_wr.reg3 <= wr(4);

end architecture;