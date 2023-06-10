library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.gen_utils_pkg.all;

package examp_regs_pkg is
    -- -------------------------------------------------------------------------
    -- Control Registers
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
    -- Offset: 0x04
    type examp_regs_reg1_arr_fld_t is record
        fld0 : std_logic; -- Desc
        fld1 : std_logic_vector(7 downto 0); -- Desc
    end record;
    type examp_regs_reg1_arr_fld_array_t is array (natural range 0 to 8-1) of examp_regs_reg1_arr_fld_t;

    -- Record of all control registers
    type examp_regs_ctl_t is record
        reg0 : examp_regs_reg0_fld_t; 
        reg1_arr : examp_regs_reg1_arr_fld_array_t;
    end record;


    -- -------------------------------------------------------------------------
    -- Status Registers
    -- -------------------------------------------------------------------------

    -- Desc: My first control register 
    -- Access: RW
    -- Offset: 0x08
    type examp_regs_reg2_fld_t is record 
        fld0 : std_logic_vector(31 downto 0); -- Desc
    end record;

    -- Record of all status registers
    type examp_regs_sts_t is record
        reg2 : examp_regs_reg2_fld_t; 
    end record;


    -- -------------------------------------------------------------------------
    -- Interrupt Registers
    -- -------------------------------------------------------------------------

    -- Desc: My first interrupt register 
    -- Access: RW1C
    -- Offset: 0x0C
    type examp_regs_reg3_fld_t is record 
        irq0 : std_logic; -- Desc
        irq1 : std_logic; -- Desc
        irq2 : std_logic; -- Desc
        irq3 : std_logic; -- Desc
    end record;

    -- Record of all interrupt registers
    type examp_regs_irq_t is record
        reg3 : examp_regs_reg2_fld_t; 
    end record;


    -- -------------------------------------------------------------------------
    -- Read / Write indication
    -- -------------------------------------------------------------------------
    type examp_regs_rw_t is record 
        reg0 : std_logic; 
        reg1_arr : std_logic_vector(8-1 downto 0); 
        reg2 : std_logic; 
        reg3 : std_logic; 
    end record; 


end package;