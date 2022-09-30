-- #############################################################################
-- # << Wishbone Crossbar Interconnect >> #
-- *****************************************************************************
-- Copyright David N. Gussler 2022
-- *****************************************************************************
-- File     : wbregs.vhd
-- Author   : David Gussler - davidnguss@gmail.com 
-- Language : VHDL '08
-- History  :  Date      | Version | Comments 
--            --------------------------------
--            09-30-2022 | 1.0     | Initial 
-- *****************************************************************************
-- Description : 
--    Any master to any slave crossbar interface
--
-- Generics
-- 
-- #############################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.gen_utils_pkg.all;

-- Entity
-- -----------------------------------------------------------------------------
entity wb_xbar is
    generic (
        G_NUM_MASTERS : positive range 1 to 16 := 2;
        G_NUM_SLAVES  : positive range 1 to 16 := 2;
        G_DATA_WIDTH_L2 : positive range 3 to 6 := 5; 
        -- low address for a slave 
        G_BASE_ADR   : slv_array_t(G_NUM_SLAVES-1 downto 0)(63 downto 0) := (X"1000", X"2000");
        -- Number of bits that the slave uses. G_BASE_ADR should use at least 1 
        -- more bit than the number of slave bits so that the interconnect 
        -- is able to mux between different slaves
        G_NUM_ADR_BITS    : int_array_t range 0 to 64 := (12,12);
        -- return a bus error if the slave doesn't respond with an ack within 
        -- G_TIMEOUT_CLKS number of cycles
        G_TIMEOUT_CLKS : positive := 128;
        -- Use round robin arbitration between masters if true
        -- Use priority if false
        G_ARB_PRIORITY : int_array_t(G_NUM_MASTERS-1 downto 0) := (0, 0);
        -- Describes which masters are connected to which slaves
        -- used to optimize out unused connections
        G_CONNECTION_MATRIX : slv_array_t(G_NUM_MASTERS-1 downto 0)(G_NUM_SLAVES-1 downto 0) := (B"11","11");
        -- maximum length (in clockcycles) of a block transfer
        -- bus will return an error and drop the transaction if a master tries 
        -- to do a bus cycle transaction longer than this 
        G_MAX_CYC_LENGTH_L2 : positive range 1 to 8 := 6
    );
    port (
        i_wbm_cyc : std_logic_vector(G_NUM_MASTERS-1 downto 0);
        i_wbm_stb : std_logic_vector(G_NUM_MASTERS-1 downto 0);
        i_wbm_adr : slv_array_t     (G_NUM_MASTERS-1 downto 0)(63 downto 0); 
        i_wbm_wen : std_logic_vector(G_NUM_MASTERS-1 downto 0);
        i_wbm_sel : slv_array_t     (G_NUM_MASTERS-1 downto 0)((2 ** (G_DAT_WIDTH_L2-3))-1 downto 0); 
        i_wbm_dat : slv_array_t     (G_NUM_MASTERS-1 downto 0)((2 ** G_DAT_WIDTH_L2)-1 downto 0);
        o_wbm_stl : std_logic_vector(G_NUM_MASTERS-1 downto 0); 
        o_wbm_ack : std_logic_vector(G_NUM_MASTERS-1 downto 0); 
        o_wbm_err : std_logic_vector(G_NUM_MASTERS-1 downto 0); 
        o_wbm_dat : slv_array_t     (G_NUM_MASTERS-1 downto 0)((2 ** G_DAT_WIDTH_L2)-1 downto 0);

        o_wbs_cyc : std_logic_vector(G_NUM_SLAVES-1 downto 0);
        o_wbs_stb : std_logic_vector(G_NUM_SLAVES-1 downto 0);
        o_wbs_adr : slv_array_t     (G_NUM_SLAVES-1 downto 0)(63 downto 0);
        o_wbs_wen : std_logic_vector(G_NUM_SLAVES-1 downto 0);
        o_wbs_sel : slv_array_t     (G_NUM_SLAVES-1 downto 0)((2 ** (G_DAT_WIDTH_L2-3))-1 downto 0);
        o_wbs_dat : slv_array_t     (G_NUM_SLAVES-1 downto 0)((2 ** G_DAT_WIDTH_L2)-1 downto 0);
        i_wbs_stl : std_logic_vector(G_NUM_SLAVES-1 downto 0); 
        i_wbs_ack : std_logic_vector(G_NUM_SLAVES-1 downto 0); 
        i_wbs_err : std_logic_vector(G_NUM_SLAVES-1 downto 0); 
        i_wbs_dat : slv_array_t     (G_NUM_SLAVES-1 downto 0)((2 ** G_DAT_WIDTH_L2)-1 downto 0);
    );
end entity wb_xbar;


-- Architecture
-- -----------------------------------------------------------------------------
architecture rtl of wb_xbar is


begin




end architecture rtl;