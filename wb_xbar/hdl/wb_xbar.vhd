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
        G_NM : positive range 1 to 16 := 2;
        G_NS : positive range 1 to 16 := 2;
        G_DAT_W_L2 : positive range 3 to 6 := 5; 
        -- width of the address bus. this must be large enough to accomicate
        -- the largest master or slave
        G_ADR_W   : positive range 1 to 64 := 16;
        -- low address for a slave 
        G_S_BASE_ADR   : slv_array_t(G_NS-1 downto 0)(G_ADR_W-1 downto 0) := (X"1000", X"2000");
        -- Number of bits that the slave uses. G_BASE_ADR should use at least 1 
        -- more bit than the number of slave bits so that the interconnect 
        -- is able to mux between different slaves
        G_S_ADR_W    : int_array_t range 1 to 64 := (12,12);
        -- return a bus error if the slave doesn't respond with an ack within 
        -- G_TIMEOUT_CLKS number of cycles
        G_TO_CLKS_L2 : positive := 128;
        -- Describes which masters are connected to which slaves
        -- used to optimize out unused connections
        G_CONN_MATRIX : slv_array_t(G_NM-1 downto 0)(G_NS-1 downto 0) := (B"11","11");
        -- Maximum number of outstanding transactions
        -- If a master sends this number of transactions in a bus cycle without 
        -- receiving any acks, then stall. 
        G_MX_OUTSTANDING_L2 : positive range 1 to 8 := 6; 
        -- if false, then M0 has highest priority, M1 has second highest, etc
        -- if true, priority starts with M0, and shifts to M1 after M0 gets a 
        -- transaction thru. Proirity shifts every time the highest priority
        -- master completes a transaction. Actually, not sure about this.
        -- I need plan out how round robin mode will be implemented. 
        G_ROUND_ROBIN : boolean := FALSE
    );
    port (
        i_wbm_cyc : std_logic_vector(G_NS-1 downto 0);
        i_wbm_stb : std_logic_vector(G_NS-1 downto 0);
        i_wbm_adr : slv_array_t     (G_NS-1 downto 0)(G_ADR_W-1 downto 0); 
        i_wbm_wen : std_logic_vector(G_NS-1 downto 0);
        i_wbm_sel : slv_array_t     (G_NS-1 downto 0)((2 ** (G_DAT_W_L2-3))-1 downto 0); 
        i_wbm_dat : slv_array_t     (G_NS-1 downto 0)((2 ** G_DAT_W_L2)-1 downto 0);
        o_wbm_stl : std_logic_vector(G_NS-1 downto 0); 
        o_wbm_ack : std_logic_vector(G_NS-1 downto 0); 
        o_wbm_err : std_logic_vector(G_NS-1 downto 0); 
        o_wbm_dat : slv_array_t     (G_NS-1 downto 0)((2 ** G_DAT_W_L2)-1 downto 0);

        o_wbs_cyc : std_logic_vector(G_NS-1 downto 0);
        o_wbs_stb : std_logic_vector(G_NS-1 downto 0);
        o_wbs_adr : slv_array_t     (G_NS-1 downto 0)(63 downto 0);
        o_wbs_wen : std_logic_vector(G_NS-1 downto 0);
        o_wbs_sel : slv_array_t     (G_NS-1 downto 0)((2 ** (G_DAT_W_L2-3))-1 downto 0);
        o_wbs_dat : slv_array_t     (G_NS-1 downto 0)((2 ** G_DAT_W_L2)-1 downto 0);
        i_wbs_stl : std_logic_vector(G_NS-1 downto 0); 
        i_wbs_ack : std_logic_vector(G_NS-1 downto 0); 
        i_wbs_err : std_logic_vector(G_NS-1 downto 0); 
        i_wbs_dat : slv_array_t     (G_NS-1 downto 0)((2 ** G_DAT_W_L2)-1 downto 0);
    );
end entity wb_xbar;


-- Architecture
-- -----------------------------------------------------------------------------
architecture rtl of wb_xbar is
    signal request : slv_array_t (G_NM-1 downto 0)(G_NS-1 downto 0);
    signal grant : slv_array_t (G_NM-1 downto 0)(G_NS-1 downto 0);


begin

    gen_masters : for m in G_NUM_MASTERS'range generate
    
        constant C_ADR_DECODE_HI : integer := G_ADR_W
        constant C_ADR_DECODE_LO : integer := find_max(G_S_ADR_W); 
        subtype C_ADR_DECODE_RANGE is integer range C_ADR_DECODE_HI-1 downto C_ADR_DECODE_LO;
        constant C_ADR_DECODE_W  : integer := C_ADR_DECODE_HI - C_ADR_DECODE_LO;

        signal decoder_adr : std_logic_vector(C_ADR_DECODE_W-1 downto 0);
        signal decoded_s_idx : integer range 0 to G_NS;

    begin 
        -- Buffer

        -- Address decoding ----------------------------------------------------
        
        -- Grab the upper bits of the incomming address that should be used to 
        -- determine which slave the master is requesting.
        decoder_adr <= i_wbm_adr(m)(C_ADR_DECODE_RANGE);
        process (all)
        begin
            -- G_NS means that master m is not addressing a valid slave s
            decoded_s_idx <= G_NS; 
            for s in G_NS'range loop
                if (G_S_BASE_ADR(s)(C_ADR_DECODE_RANGE) = decoder_adr)
                    decoded_s_idx = s;
                end if;
            end loop;
        end process;
        
        request(m)(decoded_s_idx) <= '1' when i_wbm_cyc(m) = '1' and i_wbm_stb(m) = '1' else '0';
        
        -- grants
        
        -- grant requests 
        
        -- route responses from slaves back to masters
        
        -- slave watchdog counters
        
        -- outstanding transactions counters
        

    end generate;


    gen_slaves : for s in G_NUM_SLAVES'range generate
        -- responses 
        

    end generate;

end architecture rtl;