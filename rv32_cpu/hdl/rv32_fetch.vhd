-- #############################################################################
-- #  -<< RISC-V CPU Instruction Fetch Unit >>-
-- # ===========================================================================
-- # Copyright 2022, David Gusser
-- # ===========================================================================
-- # File     : rv32_fetch.vhd
-- # Author   : David Gussler - david.gussler@proton.me
-- # Language : VHDL '08
-- # ===========================================================================
-- # This module fetches the instructions from memory. It also handles 
-- # changes in control flow by invalidating instruction accesses that are 
-- # still "in fly" at the time of the jump request. In essense, this 
-- # module guarentees that the next instruction output is the valid.  
-- # There can be up to two pipelined instruction memory accesses "in fly" at 
-- # the same time. This allows our memory interface to be fully synchronous 
-- # while also maintaining a maximum throughput of one instruction per cycle.
-- # I eventually decided to make this fetch unit its own seperate module 
-- # because it was starting to get more complicated than I initally imagined.
-- #############################################################################

-- TODO: Add the two instruction errors in here too


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.gen_utils_pkg.all;
use work.rv32_pkg.all;

entity rv32_fetch is
    generic (
        G_RESET_ADDR : std_logic_vector(31 downto 0) := x"0000_0000"
    );
    port (
        -- Clock & Reset
        i_clk       : in  std_logic; 
        i_rst       : in  std_logic; 
        
        -- Instruction Memory Interface 
        o_iren      : out  std_logic; 
        o_iaddr     : out  std_logic_vector(31 downto 0);
        i_iack      : in  std_logic; 
        i_idata     : in  std_logic_vector(31 downto 0);
        i_ierr      : in  std_logic; 


        -- CPU Interface
        i_jump        : in  std_logic; 
        i_jump_addr   : in  std_logic_vector(31 downto 0);
        o_pc          : out std_logic_vector(31 downto 0);
        o_instr       : out std_logic_vector(31 downto 0);
        o_valid       : out std_logic; 
        i_ready       : in  std_logic;
        o_iaddr_ma    : out std_logic; 
        o_iaccess_err : out std_logic 
    );
end entity;


architecture rtl of rv32_fetch is

   signal iren_en : std_logic;
   signal iren_latch : std_logic;
   signal istall : std_logic;

   signal fifo_iaddr : std_logic_vector(31 downto 0);
   signal valid_not_killed : std_logic;
   signal fifo2_empty : std_logic;
   signal fifo2_idat : std_logic_vector(63 downto 0);
   signal fifo2_odat : std_logic_vector(63 downto 0);
   signal fifo2_cnt  : std_logic_vector(1 downto 0);
   signal jump_latch: std_logic;
   signal jump_addr_latch: std_logic_vector(31 downto 0);

   type state_t is (S_IDLE, S_KILL1, S_KILL2);
   signal state, nxt_state : state_t;

begin 

    o_iaddr_ma   <= '0'; -- TODO: 
    o_iaccess_err <= '0'; -- TODO: 

    -- Instruction read enable -------------------------------------------------
    -- -------------------------------------------------------------------------
    -- Read request to external memory
    sp_iren : process (i_clk)
    begin
        if rising_edge(i_clk) then
            if (i_rst) then
                o_iren <= '1';
            elsif (iren_en) then
                o_iren <= '1';
            else 
                o_iren <= '0';
            end if;
        end if;
    end process;

    -- Memory request has been initiated and is in-progress while this bit is 
    -- high
    sp_iren_latch : process (i_clk)
    begin
        if rising_edge(i_clk) then
            if (i_rst) then
                iren_latch <= '0';
            elsif (o_iren) then
                iren_latch <= '1';
            elsif (i_iack or i_ierr) then
                iren_latch <= '0';
            end if;
        end if;
    end process;

    -- Need to stall if we dont receive a response from memory the cycle after
    -- the first request was made. 
    istall <= iren_latch and not i_iack; 

    -- Stop sending memory requests if we didnt receive a response on the 
    -- cycle after the request or if later pipeline stages are stalled (due to 
    -- data or structural hazards). But continue memory requests as usual if 
    -- the pipeline must be stalled because a jump has been unfufilled. 
    iren_en <= not istall and i_ready; 


    -- Instruction address -----------------------------------------------------
    -- -------------------------------------------------------------------------
    -- Memory request address. Increment it every time the previous addr is sent
    sp_iaddr : process (i_clk)
    begin
        if rising_edge(i_clk) then
            if (i_rst) then
                o_iaddr <= G_RESET_ADDR;
            else 
                if (iren_en) then --o_iren
                    if (i_jump) then
                        o_iaddr <= i_jump_addr; 
                    elsif (jump_latch) then
                        o_iaddr <= jump_addr_latch; 
                    else 
                        o_iaddr <= std_logic_vector(unsigned(o_iaddr) + 4);
                    end if; 
                end if; 
            end if;
        end if;
    end process;

    -- If we receive a jump request, but are not able to immediatly fufill it, 
    -- then save the jump address untill we make the request from memory 
    sp_jmp_store : process (i_clk)
    begin
        if rising_edge(i_clk) then
            if (i_rst) then
                jump_latch <= '0';
                jump_addr_latch <= (others=>'-'); 
            else 
                if (i_jump and not iren_en) then
                    jump_latch <= '1'; 
                    jump_addr_latch <= i_jump_addr; 
                elsif (jump_latch and iren_en) then
                    jump_latch <= '0';
                end if; 
            end if;
        end if;
    end process;



    -- Elastic Pipeline FIFOs --------------------------------------------------
    -- -------------------------------------------------------------------------
    -- Since up to two requests may be sent without immediatly receiving a response
    -- pass the request addresses (aka PCs) thru a fifo. 
    -- address gets read out and stored to the next fifo when a memory response 
    -- arrives. Note that this is a fallthru fifo, meaning that first write data
    -- becomes available at the output the cycle after the write. 
    u_fifo1 : entity work.fifo
    generic map (
        G_WIDTH     => 32,
        G_DEPTH_L2  => 2, -- depth = 2^2-1 = 3
        G_MEM_STYLE => "auto",
        G_FALLTHRU  => TRUE
    )
    port map (
        i_clk    => i_clk, 
        i_rst    => i_rst, 
    
        -- Write Port
        i_wr           => o_iren,
        i_dat          => o_iaddr,
        o_full_nxt     => open, 
        o_full         => open, 
    
        -- Read Port
        i_rd           => i_iack,
        o_dat          => fifo_iaddr, 
        o_empty_nxt    => open, 
        o_empty        => open--,

        --o_fill_cnt => open
    );


    -- Build and split the vectors into and out of fifo2
    fifo2_idat <= i_idata & fifo_iaddr; 
    o_instr <= fifo2_odat(63 downto 32);
    o_pc  <= fifo2_odat(31 downto 0);
    
    -- Memory response (i_idata) is validated by i_ack. The memory response's 
    -- corresponding request address comes from fifo1. If a cpu pipeline stage 
    -- after this one stalls this stage (by de-asserting ready_i) while we are 
    -- waiting on outstanding requests, then the responses will get stored in
    -- this buffer untill ready_i goes high again.
    u_fifo2 : entity work.fifo
    generic map (
        G_WIDTH     => 64,
        G_DEPTH_L2  => 2, -- depth = 2^2-1 = 3
        G_MEM_STYLE => "auto",
        G_FALLTHRU  => TRUE
    )
    port map (
        i_clk    => i_clk, 
        i_rst    => i_rst, 

        -- Write Port
        i_wr                => i_iack,
        i_dat               => fifo2_idat, 
        o_full_nxt          => open, 
        o_full              => open, 

        -- Read Port
        i_rd                => i_ready,
        o_dat               => fifo2_odat, 
        o_empty_nxt         => open, 
        o_empty             => fifo2_empty--,

        --o_fill_cnt => fifo2_cnt
    );

    valid_not_killed <= not fifo2_empty;

    -- next instruction is valid if there was a read to non-empty fifo2
    -- if the rest of the pipeline is not ready for new instructions, then 
    -- valid should maintain its last value. 
    -- process (i_clk)
    -- begin
    --     if rising_edge(i_clk) then
    --         if (i_rst) then
    --             valid_not_killed <= '0';
    --         elsif (i_ready) then 
    --             valid_not_killed <= not fifo2_empty;
    --         end if;
    --     end if;
    -- end process;


    -- Jump Invalidations ------------------------------------------------------
    -- -------------------------------------------------------------------------
    -- If a change in program flow has been requested by a later pipeline stage,
    -- then we need to kill any instructions that were speculatively fetched 
    -- before the branch/jump/interrupt/exception happened. There could be as 
    -- many as two and as few as zero depending on the CPU's state. 


    -- count the number of outstanding transactions from decode stage's perspective 
    process (i_clk)
    begin
        if rising_edge(i_clk) then
            if (i_rst) then
                valid_not_killed <= '0';
            elsif (i_ready) then 
                valid_not_killed <= not fifo2_empty;
            end if;
        end if;
    end process;


    -- FSM Next State
    process (all)
    begin
        -- Default to staying in current state
        nxt_state <= state;

        case (state) is
            when S_IDLE =>
                -- Business as usual 
                o_valid <= valid_not_killed;

                -- If jump request & the pipeline is ready for a new instruction,
                -- then kill the next two "in-fly" instructions
                if ((i_jump or jump_latch) and i_ready) then 
                    nxt_state <= S_KILL1;
                end if;

            when S_KILL1 =>
                o_valid <= '0'; 
                if (valid_not_killed and i_ready) then 
                    nxt_state <= S_KILL2;
                end if;

            when S_KILL2 =>
                o_valid <= '0'; 
                if (valid_not_killed and i_ready) then 
                    nxt_state <= S_IDLE;
                end if;

            when others =>
                null; -- ILLEGAL STATE REACHED

        end case;
    end process;


    -- FSM State Register
    process (i_clk)
    begin
        if rising_edge(i_clk) then
            if i_rst then
                state <= S_IDLE;
            else 
                state <= nxt_state;
            end if;
        end if;
    end process;

end architecture;
