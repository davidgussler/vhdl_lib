-- #############################################################################
-- # << Wishbone Registers >> #
-- *****************************************************************************
-- Copyright David N. Gussler 2022
-- *****************************************************************************
-- File     : wbregs.vhd
-- Author   : David Gussler - davidnguss@gmail.com 
-- Language : VHDL '08
-- History  :  Date      | Version | Comments 
--            --------------------------------
--            09-23-2022 | 1.0     | Initial 
-- *****************************************************************************
-- Description : 
--    Generic Wishbone B4 Pipelined register space
-- Generics
-- 
-- Formula to find minimum for G_NUM_ADR_BITS: clog2(G_NUM_REGS)+G_DAT_WIDTH_LOG2-3
-- Instead of calculating this internally to the module, this is a user generic 
-- in case the user wants to create an address space larger than the number of 
-- registers. This is so that the user can skip addresses and have more manual 
-- control if desired

-- assumes little endian accross the board 
-- assumes all accesses are aligned to G_DAT_WIDTH_LOG2
-- assumes byte granularity

-- #############################################################################

-- TODO: need to add REG_RESERVED_BITS generic
-- If a RO bit is reserved, i_regs(reserved_bit) will not do anything and
-- o_wbs_dat(reserved_bit) will always read back a 0
--
-- If a RW bit is reserved, i_wbs_dat(reserved_bit) will not do anything and 
-- o_regs(reserved_bit) will always read back a 0. We can optomize out reserved 
-- bits from o_regs (tie output directly to 0 rather than registering the zero
-- before outputting)
--
-- REG_RESET_VAL will do nothing to RO_REG, only RW_REGS need to be reset 
-- (assuming I stop registering the input 2D vector i_regs)



library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.gen_utils_pkg.all;

entity wbregs is 
    generic(
        G_DAT_WIDTH_LOG2 : positive range 3 to 6 := 5;
        G_NUM_REGS       : positive := 32;
        G_NUM_ADR_BITS   : positive := 7;
        G_REG_ADR        : slv_array_t(G_NUM_REGS-1 downto 0)(G_NUM_ADR_BITS-1 downto 0);
        G_REG_TYPE       : regtype_array_t(G_NUM_REGS-1 downto 0);
        G_REG_RST_VAL    : slv_array_t(G_NUM_REGS-1 downto 0)((2 ** G_DAT_WIDTH_LOG2)-1 downto 0);
        G_EN_ASSERT      : boolean := TRUE
    );
    port(
        i_clk : in std_logic;
        i_rst : in std_logic;

        -- Wishbone Slave Interface
        i_wbs_cyc : in  std_logic;
        i_wbs_stb : in  std_logic;
        i_wbs_adr : in  std_logic_vector(G_NUM_ADR_BITS-1 downto 0);
        i_wbs_wen : in  std_logic;
        i_wbs_sel : in  std_logic_vector((2 ** (G_DAT_WIDTH_LOG2-3))-1 downto 0);
        i_wbs_dat : in  std_logic_vector((2 ** G_DAT_WIDTH_LOG2)-1 downto 0);
        o_wbs_stl : out std_logic; 
        o_wbs_ack : out std_logic;
        o_wbs_err : out std_logic;
        o_wbs_dat : out std_logic_vector((2 ** G_DAT_WIDTH_LOG2)-1 downto 0);

        -- Register Interface
        i_regs : in  slv_array_t(G_NUM_REGS-1 downto 0)((2 ** G_DAT_WIDTH_LOG2)-1 downto 0);
        o_regs : out slv_array_t(G_NUM_REGS-1 downto 0)((2 ** G_DAT_WIDTH_LOG2)-1 downto 0);

        -- Register R/W Interface
        o_rd_stb : out std_logic_vector(G_NUM_REGS-1 downto 0);
        o_wr_stb : out std_logic_vector(G_NUM_REGS-1 downto 0)

    );
end wbregs;


architecture rtl of wbregs is 
    signal regs_in_r : slv_array_t(G_NUM_REGS-1 downto 0)((2 ** G_DAT_WIDTH_LOG2)-1 downto 0) := (others=>(others=>'0'));
    signal regs_out_r : slv_array_t(G_NUM_REGS-1 downto 0)((2 ** G_DAT_WIDTH_LOG2)-1 downto 0) := (others=>(others=>'0'));

    signal idx : integer;
    signal misaligned_err : std_logic;
    signal non_exist_err : std_logic;

begin
    -- Assign Outputs ----------------------------------------------------------
    -- -------------------------------------------------------------------------
    o_wbs_stl <= '0';
    o_regs <= regs_out_r;

    -- Simple Comb Logic -------------------------------------------------------
    -- -------------------------------------------------------------------------
    idx <= to_integer(unsigned(i_wbs_adr(G_NUM_ADR_BITS-1 downto G_DAT_WIDTH_LOG2-3)));
    misaligned_err <= '1' when G_DAT_WIDTH_LOG2 > 3 and unsigned(i_wbs_adr(G_DAT_WIDTH_LOG2-4 downto 0)) > unsigned('0') else '0';
    non_exist_err <= '1' when idx > G_NUM_REGS;


    -- Register Inputs ---------------------------------------------------------
    -- -------------------------------------------------------------------------
    -- I dont think I REALLY need to register these
    -- TODO: Remove this 
    prc_regs : process (i_clk) begin
        if (rising_edge(i_clk)) then
            for reg_idx in 0 to G_NUM_REGS-1 loop
                if (G_REG_TYPE = RO_REG) then
                    if (i_rst = '1') then
                        regs_in_r(reg_idx) <= G_REG_RST_VAL(reg_idx);
                    else 
                        regs_in_r(reg_idx) <= i_regs(reg_idx);
                    end if;
                end if;
            end loop;
        end if;
    end process;


    -- WBS Process -------------------------------------------------------------
    -- -------------------------------------------------------------------------
    prc_wbs : process (i_clk) begin
        if (rising_edge(i_clk)) then
            if (i_rst = '1') then
                o_wbs_dat <= (others=>'0');
                o_wbs_err <= '0';
                o_wbs_ack <= '0';
                o_wr_stb <= (others=>'0');
                o_rd_stb <= (others=>'0');

                for reg_idx in 0 to G_NUM_REGS-1 loop
                    if (G_REG_TYPE = RW_REG) then
                        regs_out_r(reg_idx) <= G_REG_RST_VAL(reg_idx);
                    end if;
                end loop;

            else
                -- If valid WB x-action
                if (i_wbs_cyc = '1' and i_wbs_stb = '1') then
                    if (misaligned_err = '1' or non_exist_err = '1') then
                        o_wbs_err <= '1';

                    -- WB Write
                    elsif (i_wbs_wen = '1') then
                        if (G_REG_TYPE(idx) = RW_REG) then
                            o_wr_stb(idx) <= '1';
                            o_wbs_ack <= '1';

                            for sel in i_wbs_sel'range loop
                                if i_wbs_sel(sel) = '1' then
                                    regs_out_r(sel*8+7 downto sel*8) <= i_wbs_dat(sel*8+7 downto sel*8);
                                else 
                                    regs_out_r(sel*8+7 downto sel*8) <= (others=>'0');
                                end if;
                            end loop;
                        else
                            -- error if attempt to write to a RO_REG
                            o_wbs_err <= '1';
                        end if;

                    -- WB Read 
                    else 
                        o_rd_stb(idx) <= '1';
                        o_wbs_ack <= '1';

                        for sel in i_wbs_sel'range loop
                            if i_wbs_sel(sel) then
                                if (G_REG_TYPE(idx) = RO_REG) then
                                    o_wbs_dat <= regs_in_r(idx)(sel*8+7 downto sel*8);
                                else 
                                    o_wbs_dat <= regs_in_r(idx)(sel*8+7 downto sel*8);
                                end if; 
                            else 
                                o_wbs_dat(sel*8+7 downto sel*8) <= (others=>'0');
                            end if;
                        end loop;
                    end if;
                else 
                    o_wr_stb <= (others=>'0');
                    o_rd_stb <= (others=>'0');

                    o_wbs_err <= '0';
                    o_wbs_ack <= '0';
                end if;
            end if;
        end if;
    end process;

    -- 
    -- assert to check that the user assigns an address that is too big to fit
    -- in the address space or is misaligned
    -- assert to check if G_NUM_ADR_BITS-1 < G_DAT_WIDTH_LOG2-3
    -- 
    -- Assertions --------------------------------------------------------------
    -- -------------------------------------------------------------------------
    -- gen_assertions : if (G_EN_ASSERT = TRUE) generate
    --     -- pragma translate_off 
    --     assert not (G_RD_LATENCY = 0 and (G_MEM_STYLE="block" or G_MEM_STYLE="ultra")) 
    --        report "Not able to instantiate the requested device specific memory primitive." &
    --           " G_RD_LATENCY must be at least 1." 
    --        severity warning; 
    --     assert (not (to_integer(unsigned(i_adr)) > G_DEPTH))
    --        report "Address is out of range (this could happen if G_DEPTH is not a power of 2" &
    --           " and an address larger than G_DEPTH was used). This will produce unexpected behavior"
    --        severity warning; 
    --     -- pragma translate_on 
    --  end generate;    

end rtl;