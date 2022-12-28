-- #############################################################################
-- #  << Wishbone Register Bank >>
-- # ===========================================================================
-- # File     : wb_regs.vhd
-- # Author   : David Gussler - david.gussler@proton.me
-- # Language : VHDL '08
-- # ===========================================================================
-- # BSD 2-Clause License
-- # 
-- # Copyright (c) 2022, David Gussler. All rights reserved.
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
-- # Generic Wishbone B4 Pipelined register bank. This creates an array of
-- # read-write / read-only registers along with the interfaces to access them 
-- # on the user-logic side and the wishbone side. In other words, this creates 
-- # a generic wishbone slave.
-- #
-- # Note about the IO of this module: 
-- # Synthesizer will optomize out unused i_regs and o_regs indexes. Assuming a 
-- # mix of RO and RW type regs, not all i_regs, o_regs, o_rd_pulse, and 
-- # o_wr_pulse signals will be used due to the nature of how this module is 
-- # organized. Some synthesizers and simulators will give warnings about this, 
-- # but it isn't a real issue. 
-- #
-- # assumes little endian bit accesses accross the board 
-- # assumes all accesses are aligned to G_DAT_WIDTH_L2
-- # assumes byte granularity
-- # 
-- #############################################################################

-- Consider adding another cycle in to possibly speed up timing
-- TODO: Actually do this instead: make an external wishbone pipeline module 

-- TODO: add assertion checks at the bottom

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.gen_utils_pkg.all;

entity wb_regs is 
    generic(
        -- Log-base-2 of the number of data bits. For example, a value of 5 for 
        -- this generic will produce a data width of 32 because 2^5 = 32
        G_DAT_WIDTH_L2   : positive range 3 to 6 := 5;

        -- Number of registers in the bank
        G_NUM_REGS       : positive := 32;

        -- Number of address bits to allocate for this register bank. 
        -- Formula to find the minimum value for for G_NUM_ADR_BITS: 
        -- clog2(G_NUM_REGS)+G_DAT_WIDTH_LOG2-3. 
        -- If the value used here is lower than the minumum, then the registers 
        -- that fall outside of this region will be unaccessable. 
        -- Instead of calculating this value inside the module, this is a generic 
        -- in case the user wants an address space larger than the number of 
        -- registers. This is so that the user can skip addresses and have
        -- manual control over which register maps to which address.
        G_NUM_ADR_BITS   : positive := 7;

        -- Address offset for each register in the array. 
        G_REG_ADR        : slv_array_t(G_NUM_REGS-1 downto 0)(G_NUM_ADR_BITS-1 downto 0);

        -- Either RO_REG for read-only or RW_REG for read-write. read-only and 
        -- read-write designations can only be made at the word-level as opposed
        -- to the bit-level. This means that a RW register cannot contain RO bits
        -- and vice versa. 
        G_REG_TYPE       : regtype_array_t(G_NUM_REGS-1 downto 0);

        -- Reset value for all of the RW registers. RO registers do not have a 
        -- reset value. 
        G_REG_RST_VAL    : slv_array_t(G_NUM_REGS-1 downto 0)((2 ** G_DAT_WIDTH_L2)-1 downto 0);

        -- Define the used bits for each of the registers. Unused bits will be 
        -- optomized out and tied to a constant zero. 
        G_REG_USED_BITS  : slv_array_t(G_NUM_REGS-1 downto 0)((2 ** G_DAT_WIDTH_L2)-1 downto 0);

        -- Enable warnings about generic values
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

        -- Register R/W Indication Interface
        o_rd_pulse : out std_logic_vector(G_NUM_REGS-1 downto 0);
        o_wr_pulse : out std_logic_vector(G_NUM_REGS-1 downto 0)

    );
end entity;


architecture rtl of wb_regs is 

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


    -- Simple Comb Logic -------------------------------------------------------
    -- -------------------------------------------------------------------------
    idx <= to_integer(unsigned(i_wbs_adr(G_NUM_ADR_BITS-1 downto G_DAT_WIDTH_L2-3)));
    valid_wb_write <= i_wbs_cyc and i_wbs_stb and i_wbs_wen;
    valid_wb_read  <= i_wbs_cyc and i_wbs_stb and not i_wbs_wen;

    -- Expand the select signal out to a byte mask 
    process (all)
    begin
        for sel_bit in i_wbs_sel'range loop
            sel_mask(sel_bit*8+7 downto sel_bit*8) <= (others=>i_wbs_sel(sel_bit));
        end loop;
    end process;


    -- Register Processes ------------------------------------------------------
    -- -------------------------------------------------------------------------
    -- Only use flip-flops on used bits. Hard-wire others to 0. 
    lg_rw_regs_loop : for reg_idx in 0 to G_NUM_REGS-1 generate
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

        ig_rw_regs_if : if (G_REG_TYPE(reg_idx) = RW_REG) generate
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

            lg_rw_bits_loop : for bit_idx in 0 to (2 ** G_DAT_WIDTH_L2)-1 generate
                ig_rw_bits_if : if G_REG_USED_BITS(reg_idx)(bit_idx) = '1' generate
                    sp_regs_out : process (i_clk) begin
                        if (rising_edge(i_clk)) then
                            if (i_rst) then
                                o_regs(reg_idx)(bit_idx) <= G_REG_RST_VAL(reg_idx)(bit_idx);
                            elsif (valid_wb_write = '1' and reg_idx = idx) then
                                o_regs(reg_idx)(bit_idx) <= i_wbs_dat(bit_idx) and sel_mask(bit_idx);
                            end if; 
                        end if; 
                    end process;

                else generate
                    o_regs(reg_idx)(bit_idx) <= '0';

                end generate; 
            end generate;
        else generate 
            o_wr_pulse(reg_idx) <= '0';
            o_regs(reg_idx) <= (others=>'0');

        end generate;
    end generate;


    -- WBS Process -------------------------------------------------------------
    -- -------------------------------------------------------------------------
    sp_wbs : process (i_clk) begin
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
                        o_wbs_dat <= o_regs(idx) and sel_mask; 
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

end architecture;