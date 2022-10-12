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
-- REG_RESET_VAL will do nothing to RO_REG, only RW_REGS need to be reset 
-- G_REG_USED_BITS will optomize out unused RW flipflops. Does no optomization
-- on RO bits (because they arent actually registered)
-- Synthesizer will optomize out unused i_regs and o_regs indexes 

-- assumes little endian accross the board 
-- assumes all accesses are aligned to G_DAT_WIDTH_LOG2
-- assumes byte granularity

-- #############################################################################

-- Consider adding another cycle in to possibly speed up timing
-- Make an external wishbone pipeline module 

-- TODO: add assertion checks at the bottom

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.gen_utils_pkg.all;

entity wbregs is 
    generic(
        G_DAT_WIDTH_L2   : positive range 3 to 6 := 5;
        G_NUM_REGS       : positive := 32;
        G_NUM_ADR_BITS   : positive := 7;
        G_REG_ADR        : slv_array_t(G_NUM_REGS-1 downto 0)(G_NUM_ADR_BITS-1 downto 0);
        G_REG_TYPE       : regtype_array_t(G_NUM_REGS-1 downto 0);
        G_REG_RST_VAL    : slv_array_t(G_NUM_REGS-1 downto 0)((2 ** G_DAT_WIDTH_L2)-1 downto 0);
        G_REG_USED_BITS  : slv_array_t(G_NUM_REGS-1 downto 0)((2 ** G_DAT_WIDTH_L2)-1 downto 0);
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
        i_wbs_sel : in  std_logic_vector((2 ** (G_DAT_WIDTH_L2-3))-1 downto 0);
        i_wbs_dat : in  std_logic_vector((2 ** G_DAT_WIDTH_L2)-1 downto 0);
        o_wbs_stl : out std_logic; 
        o_wbs_ack : out std_logic;
        o_wbs_err : out std_logic;
        o_wbs_dat : out std_logic_vector((2 ** G_DAT_WIDTH_L2)-1 downto 0);

        -- Register Interface
        i_regs : in  slv_array_t(G_NUM_REGS-1 downto 0)((2 ** G_DAT_WIDTH_L2)-1 downto 0);
        o_regs : out slv_array_t(G_NUM_REGS-1 downto 0)((2 ** G_DAT_WIDTH_L2)-1 downto 0);

        -- Register R/W Interface
        o_rd_pulse : out std_logic_vector(G_NUM_REGS-1 downto 0);
        o_wr_pulse : out std_logic_vector(G_NUM_REGS-1 downto 0)

    );
end wbregs;


architecture rtl of wbregs is 
    -- Registers / Wires (depends on generics)
    signal regs_out : slv_array_t(G_NUM_REGS-1 downto 0)((2 ** G_DAT_WIDTH_L2)-1 downto 0);

    -- Wires
    signal idx : integer;
    signal sel_mask : std_logic_vector((2 ** G_DAT_WIDTH_L2)-1 downto 0);
    signal valid_wb_write : std_logic;
    signal valid_wb_read  : std_logic;

begin
    -- Assign Outputs ----------------------------------------------------------
    -- -------------------------------------------------------------------------
    o_wbs_stl <= '0';
    o_wbs_err <= '0';
    o_regs <= regs_out;


    -- Simple Comb Logic -------------------------------------------------------
    -- -------------------------------------------------------------------------
    idx <= to_integer(unsigned(i_wbs_adr(G_NUM_ADR_BITS-1 downto G_DAT_WIDTH_L2-3)));
    valid_wb_write <= '1' when i_wbs_cyc and i_wbs_stb and i_wbs_wen else '0';
    valid_wb_read  <= '1' when i_wbs_cyc and i_wbs_stb and not i_wbs_wen else '0';


    -- Expand the select signal out to a byte mask 
    process (all)
    begin
        for sel_bit in i_wbs_sel'range loop
            sel_mask(sel_bit*8+7 downto sel_bit*8) <= (others=>i_wbs_sel(sel_bit));
        end loop;
    end process;

    -- Only use flip-flops on used bits. Wire others to 0. 
    gen_rw_bits_loop : for reg_idx in 0 to G_NUM_REGS-1 generate
        process (i_clk)
        begin
            if rising_edge(i_clk) then
                if (i_rst = '1') then
                    o_rd_pulse(reg_idx) <= '0';
                elsif (valid_wb_read = '1' and reg_idx = idx) then
                    o_rd_pulse(reg_idx) <= '1';
                else 
                    o_rd_pulse(reg_idx) <= '0';
                end if; 
            end if;
        end process;

        gen_rw_bits_if : if G_REG_TYPE(reg_idx) = RW_REG generate
            process (i_clk)
            begin
                if rising_edge(i_clk) then
                    if (i_rst = '1') then
                        o_wr_pulse(reg_idx) <= '0';
                    elsif (valid_wb_write = '1' and reg_idx = idx) then
                        o_wr_pulse(reg_idx) <= '1';
                    else 
                        o_wr_pulse(reg_idx) <= '0';
                    end if; 
                end if;
            end process;

            gen_rw_bits_loop2 : for bit_idx in 0 to (2 ** G_DAT_WIDTH_L2)-1 generate
                gen_rw_bits_if2 : if G_REG_USED_BITS(reg_idx)(bit_idx) = '1' generate
                    prc_regs_out : process (i_clk) begin
                        if (rising_edge(i_clk)) then
                            if (i_rst) then
                                regs_out(reg_idx)(bit_idx) <= G_REG_RST_VAL(reg_idx)(bit_idx);
                            elsif (valid_wb_write = '1' and reg_idx = idx) then
                                regs_out(reg_idx)(bit_idx) <= i_wbs_dat(bit_idx) and sel_mask(bit_idx);
                            end if; 
                        end if; 
                    end process;

                else generate
                    regs_out(reg_idx)(bit_idx) <= '0';

                end generate; 
            end generate;
        else generate 
            o_wr_pulse(reg_idx) <= '0';
            regs_out(reg_idx) <= (others=>'0');

        end generate;
    end generate;


    -- WBS Process -------------------------------------------------------------
    -- -------------------------------------------------------------------------
    prc_wbs : process (i_clk) begin
        if (rising_edge(i_clk)) then
            if (i_rst = '1') then
                o_wbs_dat <= (others=>'-');
                o_wbs_ack <= '0';
            else
                if (valid_wb_write) then
                    o_wbs_ack <= '1';
                elsif (valid_wb_read) then
                    o_wbs_ack <= '1';

                    if (G_REG_TYPE(idx) = RO_REG) then
                        o_wbs_dat <= i_regs(idx) and sel_mask and G_REG_USED_BITS(idx);
                    else 
                        o_wbs_dat <= regs_out(idx) and sel_mask; 
                    end if;
                else 
                    o_wbs_ack <= '0';
                end if;
            end if;
        end if;
    end process;

    -- 
    -- assert to check that the user assigns an address that is too big to fit
    -- in the address space or is misaligned
    -- assert to check if G_NUM_ADR_BITS-1 < G_DAT_WIDTH_LOG2-3
    --misaligned_err <= '1' when G_DAT_WIDTH_L2 > 3 and to_integer(unsigned(i_wbs_adr(G_DAT_WIDTH_L2-4 downto 0))) > 0 else '0';
    --non_exist_err <= '1' when idx > G_NUM_REGS;
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