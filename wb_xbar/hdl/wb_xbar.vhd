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
        i_clk : std_logic; 
        i_rst : std_logic; 

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

    gen_masters : for m in G_NM'range generate
    
        constant C_ADR_DECODE_HI : integer := G_ADR_W;
        constant C_ADR_DECODE_LO : integer := find_max(G_S_ADR_W); 
        subtype C_ADR_DECODE_RANGE is integer range C_ADR_DECODE_HI-1 downto C_ADR_DECODE_LO;
        constant C_ADR_DECODE_W  : integer := C_ADR_DECODE_HI - C_ADR_DECODE_LO;

        signal decoder_adr : std_logic_vector(C_ADR_DECODE_W-1 downto 0);
        signal s_idx : integer range 0 to G_NS;

    begin 

        -- -- Buffers
        -- u_skid_buff: entity work.skid_buff(rtl)
        -- generic map (
        --     G_WIDTH    => 32,
        --     G_REG_OUTS => false
        -- )
        -- port map (
        --     i_clk   => i_clk,
        --     i_rst   => i_rst,
        --     i_valid => 
        --     o_ready => 
        --     i_data  => 
        --     o_valid => 
        --     i_ready => 
        --     o_data  => 
        -- );

        -- Address decoding ----------------------------------------------------
        
        -- Grab the upper bits of the incomming address that should be used to 
        -- determine which slave the master is requesting.
        decoder_adr <= i_wbm_adr(m)(C_ADR_DECODE_RANGE);
        process (all)
        begin
            -- G_NS means that master m is not addressing a valid slave s
            s_idx <= G_NS; 
            for s in G_NS'range loop
                if (G_S_BASE_ADR(s)(C_ADR_DECODE_RANGE) = decoder_adr) then
                    s_idx <= s;
                end if;
            end loop;
        end process;

        -- register the index on a valid transaction
        process (i_clk)
        begin
            if rising_edge(i_clk) then
                if (i_rst) then
                    r_s_idx <= 0; 
                else 
                    if i_wbm_cyc(m) and i_wbm_stb(m) then
                        r_s_idx <= s_idx; 
                    end if;
                end if; 
            end if;
        end process;











        if (i_wbm_cyc(m) and i_wbm_stb(m) and ) and 
        

        -- requests
        request(m)(r_s_idx) <= r_wbm_cyc(m);
        request_m <= r_wbm_cyc(m);
        
        -- grants
        higher_pri_req(0) <= '0'; 
        higher_pri_req(m+1) <= higher_pri_req(m) or request_m;

        process (all)
        begin
            other_master_has_slave <= '0';
            for m2 in G_NM'range loop
                if (m /= m2) then
                    if (grant(m2)(s_idx)) then
                        other_master_has_slave <= '1';
                    end if; 
                end if;
            end loop;
        end process;

        grant(m)(s_idx) <= 
                request_m and ((not higher_pri_req(m) and not other_master_has_slave) or s_idx = G_NS);
        

        -- route responses from slaves back to masters
        process (all)
        begin
            if grant(m)(s_idx) then
                if (s_idx = G_NS) then
                    o_wbm_stl(m) <= '0'; 
                    o_wbm_ack(m) <= '0'; 
                    o_wbm_err(m) <= intercon_wbs_err;
                    o_wbm_dat(m) <= (others=>'-');
                else 
                    o_wbm_stl(m) <= (request_m and not grant(m)(s_idx)) or i_wbm_stl(s_idx); 
                    o_wbm_ack(m) <= i_wbs_ack(s_idx);
                    o_wbm_err(m) <= i_wbs_err(s_idx);
                    o_wbm_dat(m) <= i_wbs_dat(s_idx);
                end if;
        end process;

        -- route from master to selected slave
        process (all)
        begin
            if grant(m)(s_idx) then
                o_wbs_cyc(s_idx) <= i_wbm_cyc(m); 
                o_wbs_stb(s_idx) <= i_wbm_stb(m); 
                o_wbs_adr(s_idx) <= i_wbm_adr(m); 
                o_wbs_wen(s_idx) <= i_wbm_wen(m); 
                o_wbs_sel(s_idx) <= i_wbm_sel(m); 
                o_wbs_dat(s_idx) <= i_wbm_dat(m); 
            end if;
        end process;
        
        
        -- Errors
        -- 1. crossing slave boundry 
        --      if (stb and cyc and s_idx_current /= s_idx_last)
        -- 2. addressing non-existant slave
        --      if (stb and cyc and s_idx_current = G_NS)
        -- 3. watchdog timeout 
        --      timer starts on stb and cyc
        --      timer clears on that stb and cyc's ack
        process (i_clk)
        begin
            if rising_edge(i_clk) then
                if (i_rst) then
                    intercon_wbs_err <= '0'; 
                else 
                    if s_idx = G_NS and i_wbm_cyc(m) and i_wbm_stb(m) then
                        intercon_wbs_err <= '1'; 
                    else 
                        intercon_wbs_err <= '0'; 
                    end if;
                end if; 
            end if;
        end process;

        

        
        

    end generate;




















    gen_slaves : for s in G_NS'range generate
        signal higher_pri_req : std_logic_vector(G_NM-1 downto 0);
    begin
        
        -- grants
        
        higher_pri_req(0) <= '0'; 
        process (all)
        begin
            for m in 0 to G_NM-2 loop
                higher_pri_req(m+1) <= higher_pri_req(m) or request(m)(s);
            end loop;
        end process;

        process (all)
        begin
            for m in G_NM'range loop
                grant(m)(s) <= request(m)(s) and not higher_pri_req(m); 
            end loop;
        end process;

        -- responses 
        

    end generate;

end architecture rtl;