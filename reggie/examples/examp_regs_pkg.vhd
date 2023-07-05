-- This file (and others like it) will eventually be generated by reggie

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.gen_utils_pkg.all;

package examp_regs_pkg is
    -- -------------------------------------------------------------------------
    -- Control Register Fields
    -- -------------------------------------------------------------------------

    -- Desc: My first control register 
    -- Access: RW
    -- Offset: 0x00
    type examp_regs_reg0_fld_t is record 
        fld0 : std_logic; -- Desc
        fld1 : std_logic_vector(3 downto 0); -- Desc
    end record;

    -- Desc: My first array of control registers
    -- Access: RW
    -- Offset: 0x04, 0x08
    type examp_regs_reg1_arr_fld_t is record
        fld0 : std_logic; -- Desc
        fld1 : std_logic_vector(7 downto 0); -- Desc
    end record;
    type examp_regs_reg1_arr_fld_array_t is array (natural range 0 to 1) of examp_regs_reg1_arr_fld_t;


    -- -------------------------------------------------------------------------
    -- Status Register Fields
    -- -------------------------------------------------------------------------

    -- Desc: My first status register 
    -- Access: RO
    -- Offset: 0x0C
    type examp_regs_reg2_fld_t is record 
        fld0 : std_logic_vector(31 downto 0); -- Desc
    end record;


    -- -------------------------------------------------------------------------
    -- Volitile Register Fields
    -- -------------------------------------------------------------------------

    -- Desc: My first volitile register 
    -- Access: RWV
    -- Offset: 0x68
    type examp_regs_reg3_fld_t is record 
        fld0 : std_logic_vector(23 downto 0); -- Desc
    end record;



    -- -------------------------------------------------------------------------
    -- Control Registers
    -- -------------------------------------------------------------------------
    type examp_regs_ctl_t is record
        reg0 : examp_regs_reg0_fld_t; 
        reg1_arr : examp_regs_reg1_arr_fld_array_t;
        reg3 : examp_regs_reg3_fld_t; 
    end record;

    -- -------------------------------------------------------------------------
    -- Status Registers
    -- -------------------------------------------------------------------------
    type examp_regs_sts_t is record
        reg2 : examp_regs_reg2_fld_t; 
        reg3 : examp_regs_reg3_fld_t; 
    end record;

    -- constant EXAMP_REGS_STS_DEFAULT : examp_regs_sts_t := (
    --     reg2 => 
    -- )

    -- -------------------------------------------------------------------------
    -- Read indication pulses
    -- -------------------------------------------------------------------------
    type examp_regs_rd_t is record 
        reg0 : std_logic; 
        reg1_arr : std_logic_vector(1 downto 0); 
        reg2 : std_logic; 
        reg3 : std_logic;
    end record; 

    -- -------------------------------------------------------------------------
    -- Write indication pulses
    -- -------------------------------------------------------------------------
    type examp_regs_wr_t is record 
        reg0 : std_logic; 
        reg1_arr : std_logic_vector(1 downto 0);
        reg3 : std_logic;
    end record; 

end package;