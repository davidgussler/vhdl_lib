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
        -- receiving any acks, then error
        G_MAX_OUTSTAND : positive := 64; 
        -- if false, then M0 has highest priority, M1 has second highest, etc
        -- if true, priority starts with M0, and shifts to M1 after M0 gets a 
        -- transaction thru. Proirity shifts every time the highest priority
        -- master completes a transaction. Actually, not sure about this.
        -- I need plan out how round robin mode will be implemented. 
        G_WATCHDOG_CYCLES : positive := 64;
        G_ROUND_ROBIN : boolean := FALSE
    );
    port (
        i_clk : std_logic; 
        i_rst : std_logic; 

        i_wbm_cyc : in  std_logic_vector(G_NM-1 downto 0);
        i_wbm_stb : in  std_logic_vector(G_NM-1 downto 0);
        i_wbm_adr : in  slv_array_t     (G_NM-1 downto 0)(G_ADR_W-1 downto 0); 
        i_wbm_wen : in  std_logic_vector(G_NM-1 downto 0);
        i_wbm_sel : in  slv_array_t     (G_NM-1 downto 0)((2 ** (G_DAT_W_L2-3))-1 downto 0); 
        i_wbm_dat : in  slv_array_t     (G_NM-1 downto 0)((2 ** G_DAT_W_L2)-1 downto 0);
        o_wbm_stl : out std_logic_vector(G_NM-1 downto 0); 
        o_wbm_ack : out std_logic_vector(G_NM-1 downto 0); 
        o_wbm_err : out std_logic_vector(G_NM-1 downto 0); 
        o_wbm_dat : out slv_array_t     (G_NM-1 downto 0)((2 ** G_DAT_W_L2)-1 downto 0);

        o_wbs_cyc : out std_logic_vector(G_NS-1 downto 0);
        o_wbs_stb : out std_logic_vector(G_NS-1 downto 0);
        o_wbs_adr : out slv_array_t     (G_NS-1 downto 0)(63 downto 0);
        o_wbs_wen : out std_logic_vector(G_NS-1 downto 0);
        o_wbs_sel : out slv_array_t     (G_NS-1 downto 0)((2 ** (G_DAT_W_L2-3))-1 downto 0);
        o_wbs_dat : out slv_array_t     (G_NS-1 downto 0)((2 ** G_DAT_W_L2)-1 downto 0);
        i_wbs_stl : in  std_logic_vector(G_NS-1 downto 0); 
        i_wbs_ack : in  std_logic_vector(G_NS-1 downto 0); 
        i_wbs_err : in  std_logic_vector(G_NS-1 downto 0); 
        i_wbs_dat : in  slv_array_t     (G_NS-1 downto 0)((2 ** G_DAT_W_L2)-1 downto 0);
    );
end entity wb_xbar;


-- Architecture
-- -----------------------------------------------------------------------------
architecture rtl of wb_xbar is

    signal r_s_idx, s_idx : int_array_t(0 to G_NM) range 0 to G_NS;

    signal sgrant : std_logic_vector(G_NS-1 downto 0);
    
    signal bus_grant : std_logic_vector(G_NM-1 downto 0);
    signal request : std_logic_vector(G_NM-1 downto 0);

begin

    gen_slaves : for s in G_NS'range generate
        signal mgrant : std_logic_vector(G_NM-1 downto 0);
        signal m_idx : integer range 0 to G_NM;
    begin     
        -- Any Master Granted This Slave ---------------------------------------
        -- ---------------------------------------------------------------------
        -- 
        -- sgrant(s) = 1 when any master has been granted slave s
        --   many sgrant bits may be set (eg: 2 different masters may access 
        --   2 different slaves)
        -- mgrant(m) = 1 when master m has been granted this slave
        --   only one mgrant bit is set at a time (eg: only one master may access
        --   this specific slave at a time)
        process (all)
        begin
            for m in G_NM'range loop
                mgrant(m) <= bus_grant(m) and s = s_idx(m); -- TODO: s_idx needs to be delayed by 1;
            end loop;
        end process;
        sgrant(s) <= or(mgrant); 


        -- Master Index ------------------------------------------------------
        -- ---------------------------------------------------------------------
        -- 
        -- Determine the index of the master that is accessing this slave
        -- This process assumes that only one master is granted this slave at 
        -- a time (should be guarenteed by the bus fsm)
        -- If m_idx = G_NM then this indicates that NO master is accessing this 
        -- slave
        process (all)
        begin
            for m in G_NM'range loop
                m_idx <= G_NM;
                if mgrant(m) then
                    m_idx <= m;
                end if; 
            end loop;
        end process;
        

        -- Master to Slave Routing ---------------------------------------------
        -- ---------------------------------------------------------------------
        process (all)
        begin
            -- If a master has been granted this slave
            if sgrant(s) then
                o_wbs_cyc(s) <= i_wbm_cyc(m_idx); -- TODO: Change these to their delayed by 1 cycle variant
                o_wbs_stb(s) <= i_wbm_stb(m_idx); 
                o_wbs_adr(s) <= i_wbm_adr(m_idx); 
                o_wbs_wen(s) <= i_wbm_wen(m_idx); 
                o_wbs_sel(s) <= i_wbm_sel(m_idx); 
                o_wbs_dat(s) <= i_wbm_dat(m_idx); 

            -- If this slave is disconnected
            else 
                o_wbs_cyc(s) <= '0'; 
                o_wbs_stb(s) <= '0'; 
                o_wbs_adr(s) <= (others=>'-');
                o_wbs_wen(s) <= '-'; 
                o_wbs_sel(s) <= (others=>'-');
                o_wbs_dat(s) <= (others=>'-');
            end if;
        end process;

    end generate;



    gen_masters : for m in G_NM'range generate
    
        constant C_ADR_DECODE_HI : integer := G_ADR_W;
        constant C_ADR_DECODE_LO : integer := find_max(G_S_ADR_W); 
        subtype C_ADR_DECODE_RANGE is integer range C_ADR_DECODE_HI-1 downto C_ADR_DECODE_LO;
        constant C_ADR_DECODE_W  : integer := C_ADR_DECODE_HI - C_ADR_DECODE_LO;

        signal decoder_adr : std_logic_vector(C_ADR_DECODE_W-1 downto 0);

        signal higher_priority_request : std_logic;

        signal outstand_xactions : natural range 0 to G_MAX_OUTSTAND-1;
        signal no_outstand_xactions : std_logic;
        signal error_outstand_xactions : std_logic;
        
        signal wd_cnt : natural range 0 to G_WATCHDOG_CYCLES-1;
        signal wd_timeout : std_logic;

        type bus_state_t is (S_IDLE, S_STALL, S_GRANT, S_FLUSH, S_ERROR);
        signal bus_state, nxt_bus_state : bus_state_t;

        signal bus_stall : std_logic;
        signal bus_error : std_logic;
        signal bus_flush : std_logic;

    begin 
        -- Address decoding ----------------------------------------------------
        -- ---------------------------------------------------------------------
        --
        -- Grab the upper bits of the incomming address that should be used to 
        -- determine which slave the master is requesting.
        -- This process assumes that each slave is assigned a unique address region
        -- If this is not the case, then this logic will always select the salve 
        -- with the larger index.
        decoder_adr <= i_wbm_adr(m)(C_ADR_DECODE_RANGE);
        process (all)
        begin
            -- G_NS means that master m is not addressing a valid slave s
            s_idx(m) <= G_NS; 
            for s in G_NS'range loop
                if (G_S_BASE_ADR(s)(C_ADR_DECODE_RANGE) = decoder_adr) then
                    s_idx(m) <= s;
                end if;
            end loop;
        end process;

        -- Register the last index on a new valid transaction
        process (i_clk)
        begin
            if rising_edge(i_clk) then
                if i_rst then
                    r_s_idx(m) <= G_NS; 
                elsif request(m) then
                    r_s_idx(m) <= s_idx(m); 
                end if;
            end if;
        end process;


        -- Bus Requests --------------------------------------------------------
        -- ---------------------------------------------------------------------
        -- 
        -- This master is requesting any slave
        request(m) <= i_wbm_cyc(m) and i_wbm_stb(m); 

        -- A master with higher priority is requesting the same slave as this 
        -- master.. ie: a bus conflict / contention over the same resource
        process (all)
        begin
            higher_priority_request <= '0';
            if (m = 0) then 
                higher_priority_request <= '0';
            else 
                for m_higher in 0 to m-1 loop
                    if request(m_higher) = '1' and s_idx(m) = s_idx(m_higher) then
                        higher_priority_request <= '1';
                    end if;
                end loop;
            end if; 
        end process;



        -- Slave to Master Routing ------------------------------------
        -- ---------------------------------------------------------------------
        -- route responses from slaves back to masters
        process (all)
        begin
            if bus_grant(m) then
                o_wbm_stl(m) <= bus_stall or i_wbs_stl(r_s_idx); 
                o_wbm_ack(m) <= i_wbs_ack(r_s_idx);
                o_wbm_err(m) <= bus_error or i_wbs_err(r_s_idx);
                o_wbm_dat(m) <= i_wbs_dat(r_s_idx);
            else 
                o_wbm_stl(m) <= '0';
                o_wbm_ack(m) <= '0';
                o_wbm_err(m) <= '0';
                o_wbm_dat(m) <= (others=>'-');
            end if;
        end process;




        -- Outstanding Transactions Tracker ------------------------------------
        -- ---------------------------------------------------------------------
        process (i_clk)
        begin
            if rising_edge(i_clk) then
                if i_rst then
                    outstand_xactions <= 0;
                else 
                    if bus_grant(m) then
                        if wbs_stb and wbs_ack and not wbs_stall then
                            outstand_xactions <= outstand_xactions;
                        elsif wbs_stb and not wbs_stall and not bus_flush then
                            outstand_xactions <= outstand_xactions + 1;
                        elsif wbs_ack then
                            outstand_xactions <= outstand_xactions - 1;
                        end if;
                    else 
                        outstand_xactions <= 0;
                    end if;
                end if;
            end if;
        end process;

        no_outstand_xactions <= '1' when outstand_xactions = 0 else '0';
        error_outstand_xactions <= '1' when outstand_xactions = G_MAX_OUTSTAND-1 else '0'; 



        -- Slave Watchdog ------------------------------------------------------
        -- ---------------------------------------------------------------------
        process (i_clk)
        begin
            if rising_edge(i_clk) then
                if i_rst then
                    wd_cnt <= 0;
                else 
                    if bus_grant(m) then
                        if wbs_ack or (wbs_stb and not wbs_stall) then
                            wd_cnt <= 0;
                        else
                            wd_cnt <= wd_cnt + 1;
                        end if;
                    else 
                        wd_cnt <= 0;
                    end if;
                end if;
            end if;
        end process;

        wd_timeout <= '1' when wd_cnt = G_WATCHDOG_CYCLES else '0';



        -- FSM -----------------------------------------------------------------
        -- ---------------------------------------------------------------------
        -- 
        -- FSM Next State
        process (all)
        begin
            -- Default to staying in current state
            nxt_bus_state <= bus_state;

            case bus_state is
            -- -------------------------------------------------------------
            when S_IDLE =>
            -- -------------------------------------------------------------
                -- If a higher priority master inits a request
                if request(m) and higher_priority_request then
                    nxt_bus_state <= S_STALL;

                -- If another master has already been granted this slave
                elsif request(m) and sgrant(s_idx) then
                    nxt_bus_state <= S_STALL;
                    
                -- If the master is requesting a non-existant slave
                elsif request(m) and s_idx(m) = G_NS then 
                    nxt_bus_state <= S_ERROR;

                -- No errors or bus contention
                elsif request(m) then
                    nxt_bus_state <= S_GRANT;

                end if;

            -- -------------------------------------------------------------
            when S_STALL =>
            -- -------------------------------------------------------------
                -- If master aborts transaction
                if not i_wbm_cyc then
                    nxt_bus_state <= S_IDLE;

                -- If a higher priority master inits a request
                elsif request(m) and higher_priority_request then
                    nxt_bus_state <= S_STALL;

                -- If another master has already been granted this slave
                elsif request(m) and sgrant(s_idx(m)) then
                    nxt_bus_state <= S_STALL;
                    
                -- If the master is requesting a non-existant slave
                elsif request(m) and s_idx(m) = G_NS then 
                    nxt_bus_state <= S_ERROR;

                -- No errors or bus contention
                elsif request(m) then
                    nxt_bus_state <= S_GRANT;

                end if;

            -- -------------------------------------------------------------
            when S_GRANT =>
            -- -------------------------------------------------------------
                -- If master releases this slave
                if not i_wbm_cyc then
                    nxt_bus_state <= S_IDLE;
                    
                -- If master tries to switch to a different slave mid-cyc
                elsif request(m) and (s_idx(m) /= r_s_idx(m)) then

                    -- If erroneous x-action and slave has responded to all previous 
                    -- requests
                    if no_outstand_xactions then
                        nxt_bus_state <= S_ERROR;
                    
                    -- Erroneous x-action BUT there are still outstanding requests
                    -- with the selected slave. To maintain transaction ordering
                    -- we must wait for the slave to ack the outstanding legal requests 
                    -- before issuing an error to the master
                    else 
                        nxt_bus_state <= S_FLUSH;
                    end if;
            
                -- If too many clockcycles have elapsed since the last stb
                -- and the master hasnt received an ack, then the slave is 
                -- not responsive
                elsif wd_timeout then 
                    nxt_bus_state <= S_ERROR;
                
                -- If master has sent the maximum number of outstanding transactions
                -- and not received a response 
                elsif error_outstand_xactions then
                    nxt_bus_state <= S_STALL;
                    -- TODO: maybe make this an error instead of a stall
                


                end if;

            -- -------------------------------------------------------------
            when S_FLUSH =>    
            -- -------------------------------------------------------------
                -- If master releases this slave
                if not i_wbm_cyc then
                    nxt_bus_state <= S_IDLE;
    
                -- If slave has responded to all outstanding (legal) requests
                elsif no_outstand_xactions then
                    nxt_bus_state <= S_ERROR;
                
                -- If master has sent the maximum number of outstanding transactions
                -- and the slave has not responded.  
                elsif error_outstand_xactions then
                    nxt_bus_state <= S_ERROR;

                end if;

            -- -------------------------------------------------------------
            when S_ERROR => 
            -- -------------------------------------------------------------
                nxt_bus_state <= S_IDLE;

            when others =>
                null;

            end case;
        end process;


        -- FSM Output
        process (i_clk)
        begin
            if rising_edge(i_clk) then
                if i_rst then
                    bus_state    <= S_IDLE;

                    bus_grant(m) <= '0';
                    bus_stall    <= '0';
                    bus_error    <= '0';
                    bus_flush    <= '0';
                else 
                    -- Advance the state 
                    bus_state <= nxt_bus_state;

                    -- Assign Outputs
                    case nxt_bus_state is
                    -- -----------------------------------------------------
                    when S_IDLE =>
                    -- -----------------------------------------------------
                        bus_grant(m) <= '0';
                        bus_stall    <= '0';
                        bus_error    <= '0';
                        bus_flush    <= '0';

                    -- -----------------------------------------------------
                    when S_STALL =>
                    -- -----------------------------------------------------
                        bus_grant(m) <= '0';
                        bus_stall    <= '1';
                        bus_error    <= '0';
                        bus_flush    <= '0';

                    -- -----------------------------------------------------
                    when S_GRANT =>
                    -- -----------------------------------------------------
                        bus_grant(m) <= '1';
                        bus_stall    <= '0';
                        bus_error    <= '0';
                        bus_flush    <= '0';

                    -- -----------------------------------------------------
                    when S_FLUSH =>    
                    -- -----------------------------------------------------
                        bus_grant(m) <= '1';
                        bus_stall    <= '0';
                        bus_error    <= '0';
                        bus_flush    <= '1';

                    -- -----------------------------------------------------
                    when S_ERROR => 
                    -- -----------------------------------------------------
                        bus_grant(m) <= '0';
                        bus_stall    <= '0';
                        bus_error    <= '1';
                        bus_flush    <= '0';

                    when others =>
                        null;

                    end case;
                end if;
            end if;
        end process;

        




    end generate;





end architecture rtl;