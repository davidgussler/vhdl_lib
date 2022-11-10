-- #############################################################################
-- #  -<< CPU to Wishbone Interface >>-
-- # ===========================================================================
-- # Copyright 2022, David Gusser
-- # ===========================================================================
-- # File     : rv32_wishbone_if.vhd
-- # Author   : David Gussler - davidnguss@gmail.com 
-- # Language : VHDL '08
-- # ===========================================================================
-- # Bridge for CPU memory bus master transactions to wishbone bus master
-- # transactions. TODO: add optional wishbone register slice module 
-- # 
-- #############################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.gen_utils_pkg.all;

-- Entity ======================================================================
-- =============================================================================
entity rv32_wishbone_if is
    port (
        i_clk      : in std_logic;
        i_rst      : in std_logic;

        -- CPU Interface
        i_ren     : in std_logic;
        i_wen     : in std_logic;
        i_sel     : in std_logic_vector(3 downto 0);
        i_addr    : in std_logic_vector(31 downto 0);
        i_wdat    : in std_logic_vector(31 downto 0);
        o_rdat    : out std_logic_vector(31 downto 0);
        o_stall   : out std_logic;
        o_error   : out std_logic;
        
        -- Wishbone Interface
        o_wb_cyc  : out std_logic;
        o_wb_stb  : out std_logic;
        o_wb_adr  : out std_logic_vector(31 downto 0);
        o_wb_wen  : out std_logic;
        o_wb_sel  : out std_logic_vector(3 downto 0);
        o_wb_wdat : out std_logic_vector(31 downto 0);
        i_wb_stl  : in std_logic; 
        i_wb_ack  : in std_logic;
        i_wb_err  : in std_logic;
        i_wb_rdat : in std_logic_vector(31 downto 0)     
        
    );
end entity rv32_wishbone_if;

architecture rtl of rv32_wishbone_if is

    signal wb_adr  : std_logic_vector(31 downto 0); 
    signal wb_wen  : std_logic; 
    signal wb_sel  : std_logic_vector(3 downto 0); 
    signal wb_stb  : std_logic; 
    signal wb_wdat : std_logic_vector(31 downto 0); 

    signal reg_wb_cyc : std_logic; 
    signal reg_wb_stl : std_logic; 

    signal reg_wb_adr  : std_logic_vector(31 downto 0); 
    signal reg_wb_wen  : std_logic; 
    signal reg_wb_sel  : std_logic_vector(3 downto 0); 
    signal reg_wb_stb  : std_logic; 
    signal reg_wb_wdat : std_logic_vector(31 downto 0); 

begin

    wb_adr  <= i_addr;
    wb_wen  <= i_wen;
    wb_sel  <= i_sel;
    wb_stb  <= i_ren or i_wen; 
    wb_wdat <= i_wdat; 
    
    process (i_clk) begin
        if rising_edge(i_clk) then
            if (i_rst) then
                reg_wb_cyc <= '0';
            else
                if (o_wb_stb) then
                    reg_wb_cyc <= '1';
                elsif (i_wb_ack or i_wb_err) then
                    reg_wb_cyc <= '0';
                end if; 
            end if;
        end if;
    end process;

    -- Used to select the registered wishbone data as the wishbone outputs 
    -- if wishbone interface is stalling
    process (i_clk) begin
        if rising_edge(i_clk) then
            if (i_rst) then
                reg_wb_stl <= '0';
            else
                reg_wb_stl <= i_wb_stl and o_wb_stb and o_wb_cyc; 
            end if;
        end if;
    end process;

    -- If a wishbone transaction is stalled by the wishbone interface, then
    -- register the transaction information
    -- No reset necessary because these values are guarenteed to never 
    -- be read on the first cycle after reset. 
    process (i_clk) begin
        if rising_edge(i_clk) then
            if (i_wb_stl and o_wb_stb and o_wb_cyc) then
                reg_wb_adr  <= wb_adr;
                reg_wb_wen  <= wb_wen;
                reg_wb_sel  <= wb_sel;
                reg_wb_stb  <= wb_stb;
                reg_wb_wdat <= wb_wdat;
            end if; 
        end if;
    end process;



    -- Outputs to wishbone -----------------------------------------------------
    o_wb_cyc <= reg_wb_cyc or o_wb_stb; 

    process (all) begin
        if (reg_wb_stl) then
            o_wb_adr  <= reg_wb_adr;
            o_wb_wen  <= reg_wb_wen;
            o_wb_sel  <= reg_wb_sel;
            o_wb_stb  <= reg_wb_stb;
            o_wb_wdat <= reg_wb_wdat; 
        else
            o_wb_adr  <= wb_adr;
            o_wb_wen  <= wb_wen;
            o_wb_sel  <= wb_sel;
            o_wb_stb  <= wb_stb;
            o_wb_wdat <= wb_wdat; 
        end if; 
    end process;


    -- Outputs to processor ----------------------------------------------------
    -- rdat is valid at the cpu one cycle after dren unless stall is high,
    -- in which case, data is valid the cycle stall goes low. 
    -- Stall and error will only be affected by the wishbone interface.
    -- Internal memory accesses will not cause a stall or error 
    o_stall <= reg_wb_cyc and not i_wb_ack;
    o_error <= i_wb_err;
    o_rdat  <= i_wb_rdat; 

end architecture;