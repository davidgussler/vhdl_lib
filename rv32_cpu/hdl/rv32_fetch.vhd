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
-- # The same time. This allows our memory interface to be fully synchronous 
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
        o_pc          : out  std_logic_vector(31 downto 0);
        o_instr       : out  std_logic_vector(31 downto 0);
        o_valid       : out  std_logic; 
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

   type state_t is (S_IDLE, S_KILL1, S_KILL2);
   signal state, nxt_state : state_t;

begin 

    o_iaddr_ma   <= '0'; -- TODO: 
    o_iaccess_err <= '0'; -- TODO: 

    -- Instruction read enable -------------------------------------------------
    -- -------------------------------------------------------------------------
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

    sp_iren_latch : process (i_clk)
    begin
        if rising_edge(i_clk) then
            if (i_rst) then
                iren_latch <= '1';
            elsif (o_iren) then
                iren_latch <= '1';
            elsif (i_iack or i_ierr) then
                iren_latch <= '0';
            end if;
        end if;
    end process;

    istall <= iren_latch and not i_iack; 
    iren_en <= not istall and i_ready; 


    -- Instruction address -----------------------------------------------------
    -- -------------------------------------------------------------------------
    sp_iaddr : process (i_clk)
    begin
        if rising_edge(i_clk) then
            if (i_rst) then
                o_iaddr <= G_RESET_ADDR;
            elsif (iren_en) then
                if (i_jump) then
                    o_iaddr <= i_jump_addr; 
                else 
                    o_iaddr <= std_logic_vector(unsigned(o_iaddr) + 4);
                end if; 
            end if;
        end if;
    end process;


    -- Elastic Pipeline FIFOs --------------------------------------------------
    -- -------------------------------------------------------------------------
    u_fifo1 : entity work.fifo
    generic map (
        G_WIDTH        => 32,
        G_DEPTH_L2     => 2,
        G_MEM_STYLE    => "auto",
        G_FALLTHRU   => TRUE
    )
    port map (
        i_clk    => i_clk, 
        i_rst    => i_rst, 
    
        -- Write Port
        i_wr           => o_iren,
        i_dat  => o_iaddr,
        o_full_nxt     => open, 
        o_full         => open, 
    
        -- Read Port
        i_rd           => i_iack,
        o_dat          => fifo_iaddr, 
        o_empty_nxt    => open, 
        o_empty        => open
    );


    fifo2_idat <= i_idata & fifo_iaddr; 
    o_instr <= fifo2_odat(63 downto 32);
    o_pc  <= fifo2_odat(31 downto 0);
    
    u_fifo2 : entity work.fifo
    generic map (
        G_WIDTH        => 64,
        G_DEPTH_L2     => 2,
        G_MEM_STYLE    => "auto",
        G_FALLTHRU     => FALSE
    )
    port map (
        i_clk    => i_clk, 
        i_rst    => i_rst, 

        -- Write Port
        i_wr                => i_iack,
        i_dat => fifo2_idat, 
        o_full_nxt          => open, 
        o_full              => open, 

        -- Read Port
        i_rd                => i_ready,
        o_dat => fifo2_odat, 
        o_empty_nxt         => open, 
        o_empty             => open --fifo2_empty
    );

    -- valid_not_killed <= not fifo2_empty; 



    -- Jump Invalidations ------------------------------------------------------
    -- -------------------------------------------------------------------------

    -- FSM Next State
    process (all)
    begin
        -- Default to staying in current state
        nxt_state <= state;

        case (state) is
            when S_IDLE =>
                o_valid <= valid_not_killed;
                if (i_jump) then 
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
                state    <= S_IDLE;
            else 
                state <= nxt_state;
            end if;
        end if;
    end process;

end architecture;
