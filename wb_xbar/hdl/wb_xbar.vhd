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
--   Any master to any slave crossbar interconnect. 
--   Follows the Wishbone B4 Pipelined specification:
--     https://cdn.opencores.org/downloads/wbspec_b4.pdf
--   Use this to build a Wishbone-based SoC 
--
-- #############################################################################

-- TODO: further pipeline the internals to acheive better timing 


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.gen_utils_pkg.all;

-- Entity ======================================================================
-- =============================================================================
entity wb_xbar is
    generic (
        -- Number of masters
        G_NM : positive range 1 to 16 := 2;

        -- Number of slaves
        G_NS : positive range 1 to 16 := 2;

        -- Data width = 2^G_DAT_W_L2
        G_DAT_W_L2 : positive range 3 to 6 := 4; 

        -- Maximum width of the address bus. Must be large enough to accomodate
        -- the largest master or slave
        G_ADR_W : positive range 1 to 64 := 16;

        -- Base address of each slave
        -- Used by the interconnect as a slave select index
        G_S_BASE_ADR : slv_array_t(0 to G_NS-1)(G_ADR_W-1 downto 0) := (X"1000", X"2000");

        -- Number of address bits for each slave
        -- For example, if this value is 12, then adr(G_S_BASE_ADR-1 downto 12) 
        -- is used to determine which slave is being addressed and 
        -- adr(11 downto 0) is routed to that slave. 
        G_S_ADR_W : int_array_t(0 to G_NS-1) := (12, 12);

        -- Return a bus error if a master sends G_MAX_OUTSTAND of transactions 
        -- during a bus cycle without receiving any acks
        G_MAX_OUTSTAND : positive := 64; 

        -- Return a bus error if a master has been granted a slave and the master
        -- doesn't receive an ack from that slave within G_WATCHDOG_CLKS clockcycles
        G_WATCHDOG_CLKS : positive := 64;

        -- Describes which masters are connected to which slaves
        -- Used to optimize out connections that aren't needed
        -- TODO: Don't worry about implementing this optomization till I've 
        -- verified functionality without it
        G_CONN_MATRIX : slv_array_t(G_NM-1 downto 0)(0 to G_NS-1) := (B"11", B"11");

        -- If false, then M0 has highest priority, M1 has second highest, etc
        -- If true, priority starts with M0, and shifts to M1 after M0 gets a 
        -- bus cycle thru. Proirity shifts every time the highest priority
        -- master completes a transaction. Actually, not sure about this.
        -- I need plan out how round robin mode will be implemented. 
        -- TODO: Don't worry about implementing this enhancement till I've  
        -- verified functionality without it
        G_ROUND_ROBIN : boolean := FALSE
    );
    port (
        i_clk : std_logic; 
        i_rst : std_logic; 

        -- Slave Interface(s)
        i_wbs_cyc : in  std_logic_vector(G_NM-1 downto 0);
        i_wbs_stb : in  std_logic_vector(G_NM-1 downto 0);
        i_wbs_adr : in  slv_array_t     (G_NM-1 downto 0)(G_ADR_W-1 downto 0); 
        i_wbs_wen : in  std_logic_vector(G_NM-1 downto 0);
        i_wbs_sel : in  slv_array_t     (G_NM-1 downto 0)((2 ** (G_DAT_W_L2-3))-1 downto 0); 
        i_wbs_dat : in  slv_array_t     (G_NM-1 downto 0)((2 ** G_DAT_W_L2)-1 downto 0);
        o_wbs_stl : out std_logic_vector(G_NM-1 downto 0); 
        o_wbs_ack : out std_logic_vector(G_NM-1 downto 0); 
        o_wbs_err : out std_logic_vector(G_NM-1 downto 0); 
        o_wbs_dat : out slv_array_t     (G_NM-1 downto 0)((2 ** G_DAT_W_L2)-1 downto 0);

        -- Master Interface(s)
        o_wbm_cyc : out std_logic_vector(G_NS-1 downto 0);
        o_wbm_stb : out std_logic_vector(G_NS-1 downto 0);
        o_wbm_adr : out slv_array_t     (G_NS-1 downto 0)(G_ADR_W-1 downto 0);
        o_wbm_wen : out std_logic_vector(G_NS-1 downto 0);
        o_wbm_sel : out slv_array_t     (G_NS-1 downto 0)((2 ** (G_DAT_W_L2-3))-1 downto 0);
        o_wbm_dat : out slv_array_t     (G_NS-1 downto 0)((2 ** G_DAT_W_L2)-1 downto 0);
        i_wbm_stl : in  std_logic_vector(G_NS-1 downto 0); 
        i_wbm_ack : in  std_logic_vector(G_NS-1 downto 0); 
        i_wbm_err : in  std_logic_vector(G_NS-1 downto 0); 
        i_wbm_dat : in  slv_array_t     (G_NS-1 downto 0)((2 ** G_DAT_W_L2)-1 downto 0)
    );
end entity wb_xbar;


-- Architecture ================================================================
-- =============================================================================
architecture rtl of wb_xbar is

    signal wbs_buff_stb : std_logic_vector(G_NM-1 downto 0);
    signal wbs_buff_adr : slv_array_t     (G_NM-1 downto 0)(G_ADR_W-1 downto 0); 
    signal wbs_buff_wen : std_logic_vector(G_NM-1 downto 0);
    signal wbs_buff_sel : slv_array_t     (G_NM-1 downto 0)((2 ** (G_DAT_W_L2-3))-1 downto 0); 
    signal wbs_buff_dat : slv_array_t     (G_NM-1 downto 0)((2 ** G_DAT_W_L2)-1 downto 0);
    signal buff_s_idx   : int_array_t(0 to G_NM-1);

    -- NOTE: This initial value is needed for simulation
    -- Once / if I register the address decoder output I shouldnt need this anymore
    signal s_idx      : int_array_t(0 to G_NM-1) := (others=>0); 

    signal sgrant : std_logic_vector(G_NS-1 downto 0);
    
    signal bus_grant : std_logic_vector(G_NM-1 downto 0);

    signal request : std_logic_vector(G_NM-1 downto 0);

begin

    gen_slaves : for s in 0 to G_NS-1 generate
        signal mgrant : std_logic_vector(G_NM-1 downto 0);
        signal m_idx : integer range 0 to G_NM;
    begin     
        -- Any Master Granted This Slave ---------------------------------------
        -- ---------------------------------------------------------------------
        -- sgrant(s) = 1 when any master has been granted slave s
        --   many sgrant bits may be set (eg: 2 different masters may access 
        --   2 different slaves)
        -- mgrant(m) = 1 when master m has been granted this slave
        --   only one mgrant bit is set at a time (eg: only one master may access
        --   this specific slave at a time)
        process (all)
        begin
            for m in 0 to G_NM-1 loop
                if bus_grant(m) = '1' and s = buff_s_idx(m) then
                    mgrant(m) <= '1';
                else 
                    mgrant(m) <= '0';
                end if; 
            end loop;
        end process;
        
        sgrant(s) <= or(mgrant); 


        -- Master Index ------------------------------------------------------
        -- ---------------------------------------------------------------------
        -- Determine the index of the master that is accessing this slave
        -- This process assumes that only one master is granted this slave at 
        -- a time (should be guarenteed by the bus fsm)
        -- If m_idx = G_NM then this indicates that NO master is accessing this 
        -- slave
        process (all)
        begin
            m_idx <= G_NM;
            for m in 0 to G_NM-1 loop
                if mgrant(m) then
                    m_idx <= m;
                end if; 
            end loop;
        end process;
        

        -- Master to Slave Routing ---------------------------------------------
        -- ---------------------------------------------------------------------
        -- Notice the special case with the address. Since slave address width
        -- can be different for each slave we set the slave io signals to the 
        -- maximum possible width (G_ADR_W) and hardwire unused bits to 0.
        -- Simply leave unused address bits disconnected at the output port and
        -- synthesizer will strip those away. May get a warning but that can 
        -- be ignored. 
        -- Also notice the special case with the cyc. Unlike the others, we don't
        -- want this signal to be buffered. It should drop low immediatly on 
        -- the last ack. 
        process (all)
        begin
            -- If a master has been granted this slave
            if sgrant(s) then
                o_wbm_cyc(s) <= i_wbs_cyc(m_idx); 
                o_wbm_stb(s) <= wbs_buff_stb(m_idx); 
                o_wbm_wen(s) <= wbs_buff_wen(m_idx); 
                o_wbm_sel(s) <= wbs_buff_sel(m_idx); 
                o_wbm_dat(s) <= wbs_buff_dat(m_idx); 
                o_wbm_adr(s)(G_S_ADR_W(s)-1 downto 0) <= wbs_buff_adr(m_idx)(G_S_ADR_W(s)-1 downto 0); 

            -- If this slave is disconnected
            else 
                o_wbm_cyc(s) <= '0';
                o_wbm_stb(s) <= '0';
                o_wbm_wen(s) <= '-';
                o_wbm_sel(s) <= (others=>'-');
                o_wbm_dat(s) <= (others=>'-');
                o_wbm_adr(s)(G_S_ADR_W(s)-1 downto 0) <= (others=>'-');
            end if;
        end process;
        o_wbm_adr(s)(G_ADR_W-1 downto G_S_ADR_W(s)) <= (others=>'0');

    end generate;



    gen_masters : for m in 0 to G_NM-1 generate
    
        constant C_ADR_DECODE_HI : integer := G_ADR_W;
        constant C_ADR_DECODE_LO : integer := find_max(G_S_ADR_W); 
        subtype C_ADR_DECODE_RANGE is integer range C_ADR_DECODE_HI-1 downto C_ADR_DECODE_LO;
        constant C_ADR_DECODE_W  : integer := C_ADR_DECODE_HI - C_ADR_DECODE_LO;

        signal decoder_adr : std_logic_vector(C_ADR_DECODE_W-1 downto 0);
        
        signal last_s_idx : integer range 0 to G_NS;
        signal no_valid_slave_selected : std_logic; 
        signal s_idx_changed : std_logic; 

        signal higher_priority_request : std_logic;

        signal outstand_xactions : natural range 0 to G_MAX_OUTSTAND-1;
        signal no_outstand_xactions : std_logic;
        signal max_outstand_xactions : std_logic;
        
        signal wd_cnt : natural range 0 to G_WATCHDOG_CLKS-1;
        signal wd_timeout : std_logic;

        type bus_state_t is (S_IDLE, S_STALL, S_GRANT, S_FLUSH, S_ERROR);
        signal bus_state, nxt_bus_state : bus_state_t;

        signal bus_stall : std_logic;
        signal bus_error : std_logic;
        signal bus_flush : std_logic;

    begin 
        -- Address decoding ----------------------------------------------------
        -- ---------------------------------------------------------------------
        -- Grab the upper bits of the incomming address that should be used to 
        -- determine which slave the master is requesting.
        -- This process assumes that each slave is assigned a unique address region
        -- If this is not the case, then this logic will always select the salve 
        -- with the largest index.
        decoder_adr <= i_wbs_adr(m)(C_ADR_DECODE_RANGE);
        process (all)
        begin
            -- G_NS means that master m is not addressing a valid slave s
            -- FIXME: This is just to get a basic simulation running
            s_idx(m) <= 0;-- G_NS; 
            --s_idx(m) <= G_NS; 
            for s in 0 to G_NS-1 loop
                if (G_S_BASE_ADR(s)(C_ADR_DECODE_RANGE) = decoder_adr) then
                    s_idx(m) <= s;
                end if;
            end loop;
        end process;

        no_valid_slave_selected <= '1' when s_idx(m) = G_NS else '0'; 


        -- Register the last index on a new request. This is used in the FSM
        -- to determine if the slave index illegally changed mid cyc transaction
        process (i_clk)
        begin
            if rising_edge(i_clk) then
                if i_rst then
                    last_s_idx <= G_NS; 
                elsif request(m) then
                    last_s_idx <= s_idx(m); 
                end if;
            end if;
        end process;

        s_idx_changed <= '1' when last_s_idx /= s_idx(m) else '0';

  
        -- Bus Requests --------------------------------------------------------
        -- ---------------------------------------------------------------------
        -- This master is requesting any slave
        request(m) <= i_wbs_cyc(m) and i_wbs_stb(m); 

        -- A master with higher priority is requesting the same slave as this 
        -- master.. ie: a bus conflict / contention over the same resource
        gen_if_one_master : if G_NM <= 1 generate

            higher_priority_request <= '0';

        else generate

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

        end generate;

        
        -- Master Buffer ---------------------------------------------
        -- ---------------------------------------------------------------------
        -- This is needed because the FSM takes one cycle to determine if the master
        -- request will be granted or stalled. Since we want to maintain 100%
        -- thruput for non-stalled transactions we need to buffer the master
        -- inputs. The first transaction will be stored here so it doesnt get
        -- dropped in the case of a stall.
        process (i_clk)
        begin
            if rising_edge(i_clk) then
                if i_rst then 
                    wbs_buff_stb(m) <= '0'; 
                    wbs_buff_adr(m) <= (others=>'-'); 
                    wbs_buff_wen(m) <= '-';
                    wbs_buff_sel(m) <= (others=>'-'); 
                    wbs_buff_dat(m) <= (others=>'-'); 
                    buff_s_idx(m)   <= G_NS; 
                else
                    if request(m) and o_wbs_stl(m) then
                        wbs_buff_stb(m) <= wbs_buff_stb(m);
                        wbs_buff_adr(m) <= wbs_buff_adr(m);
                        wbs_buff_wen(m) <= wbs_buff_wen(m);
                        wbs_buff_sel(m) <= wbs_buff_sel(m);
                        wbs_buff_dat(m) <= wbs_buff_dat(m);
                        buff_s_idx(m)   <= buff_s_idx(m);
                    else 
                        wbs_buff_stb(m) <= i_wbs_stb(m);
                        wbs_buff_adr(m) <= i_wbs_adr(m);
                        wbs_buff_wen(m) <= i_wbs_wen(m);
                        wbs_buff_sel(m) <= i_wbs_sel(m);
                        wbs_buff_dat(m) <= i_wbs_dat(m);
                        buff_s_idx(m)   <= s_idx(m); 
                    end if; 
                end if; 
            end if;
        end process;


        -- Slave to Master Routing ---------------------------------------------
        -- ---------------------------------------------------------------------
        process (all)
        begin
            if bus_grant(m) then
                o_wbs_stl(m) <= i_wbm_stl(buff_s_idx(m)); 
                o_wbs_ack(m) <= i_wbm_ack(buff_s_idx(m));
                o_wbs_err(m) <= i_wbm_err(buff_s_idx(m));
                o_wbs_dat(m) <= i_wbm_dat(buff_s_idx(m));
            else 
                o_wbs_stl(m) <= bus_stall;
                o_wbs_ack(m) <= '0';
                o_wbs_err(m) <= bus_error;
                o_wbs_dat(m) <= (others=>'-');
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
                        if (wbs_buff_stb(m) and not o_wbs_stl(m)) and o_wbs_ack(m) then
                            outstand_xactions <= outstand_xactions;

                        -- We stop accepting new transactions during a flush. We 
                        -- only wait for the outstanding transactions that were 
                        -- initiated before the error to complete. Therefore 
                        -- stop counting new transactions (that occur after the)
                        -- error towards the total during a flush.  
                        elsif (wbs_buff_stb(m) and not o_wbs_stl(m)) and not o_wbs_ack(m) and not bus_flush then
                            outstand_xactions <= outstand_xactions + 1;

                        elsif o_wbs_ack(m) then
                            outstand_xactions <= outstand_xactions - 1;

                        end if;
                    else 
                        outstand_xactions <= 0;
                    end if;
                end if;
            end if;
        end process;

        -- TODO: add assertion to make sure that outstand_xactions doesnt go negative
        -- this would indicate we got more acks than requests. a sure sign something
        -- aint right. 

        no_outstand_xactions <= '1' when outstand_xactions = 0 else '0';
        max_outstand_xactions <= '1' when outstand_xactions = G_MAX_OUTSTAND-1 else '0'; 


        -- Slave Watchdog Timer ------------------------------------------------
        -- ---------------------------------------------------------------------
        process (i_clk)
        begin
            if rising_edge(i_clk) then
                if i_rst then
                    wd_cnt <= 0;
                else 
                    if bus_grant(m) then
                        if o_wbs_ack(m) then
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

        wd_timeout <= '1' when wd_cnt = G_WATCHDOG_CLKS-1 else '0';



        -- FSM -----------------------------------------------------------------
        -- ---------------------------------------------------------------------
        -- FSM Next State
        process (all)
        begin
            -- Default to staying in current state
            nxt_bus_state <= bus_state;

            case bus_state is
            -- -------------------------------------------------------------
            when S_IDLE =>
            -- -------------------------------------------------------------
                -- If the master is requesting a non-existant slave
                if request(m) and no_valid_slave_selected then 
                    nxt_bus_state <= S_ERROR;

                -- If a higher priority master inits a request or
                -- another master has already been granted this slave
                elsif request(m) and (higher_priority_request or sgrant(s_idx(m))) then
                    nxt_bus_state <= S_STALL;

                -- No errors or bus contention
                elsif request(m) then
                    nxt_bus_state <= S_GRANT;

                end if;

            -- -------------------------------------------------------------
            when S_STALL =>
            -- -------------------------------------------------------------
                -- If master aborts transaction
                if not i_wbs_cyc(m) then
                    nxt_bus_state <= S_IDLE;

                -- If master tries to switch to a different slave mid-cyc
                elsif request(m) and s_idx_changed then 
                    nxt_bus_state <= S_ERROR;

                -- If a higher priority master inits a request or
                -- another master has already been granted this slave
                elsif request(m) and (higher_priority_request or sgrant(s_idx(m))) then
                    nxt_bus_state <= S_STALL;

                -- No errors or bus contention
                elsif request(m) then
                    nxt_bus_state <= S_GRANT;

                end if;

            -- -------------------------------------------------------------
            when S_GRANT =>
            -- -------------------------------------------------------------
                -- If master releases this slave or aborts
                if not i_wbs_cyc(m) then
                    nxt_bus_state <= S_IDLE;
                
                -- If unresponsive slave
                elsif wd_timeout or max_outstand_xactions then 
                    nxt_bus_state <= S_ERROR;

                -- If master tries to switch to a different slave mid-cyc
                elsif request(m) and s_idx_changed then 

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

                end if;

            -- -------------------------------------------------------------
            when S_FLUSH =>    
            -- -------------------------------------------------------------
                -- If master aborts
                if not i_wbs_cyc(m) then
                    nxt_bus_state <= S_IDLE;
    
                -- If unresponsive slave
                elsif wd_timeout or max_outstand_xactions then 
                    nxt_bus_state <= S_ERROR;

                -- If slave has responded to all outstanding (legal) requests
                -- then we can now route the outstanding error to the master.
                elsif no_outstand_xactions then
                    nxt_bus_state <= S_ERROR;

                end if;

            -- -------------------------------------------------------------
            when S_ERROR => 
            -- -------------------------------------------------------------
                nxt_bus_state <= S_IDLE;

            when others =>
                null;
                -- assert ILLEGAL STATE REACHED

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
                        -- assert ILLEGAL STATE REACHED

                    end case;
                end if;
            end if;
        end process;

    end generate;

end architecture rtl;
