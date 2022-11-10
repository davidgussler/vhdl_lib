-- #############################################################################
-- #  -<< Memory for RV CPU >>-
-- # ===========================================================================
-- # Copyright 2022, David Gusser
-- # ===========================================================================
-- # File     : rv32_mem.vhd
-- # Author   : David Gussler - davidnguss@gmail.com 
-- # Language : VHDL '08
-- # ===========================================================================
-- # This file includes the processors low latency internal memory, its caches,
-- # and an external wishbone interface. 
-- # Basic description of the CPU's memory interface: The CPU exepects data to 
-- # returned one cycle after a request pulse. If the memory system
-- # is not ready to return data, then stall is expected to go high until that
-- # data is ready. Error pulses high on erroneous accesses. 
-- # CPU only supports one outstanding transaction at a time (no pipelined / 
-- # overlapping memory accesses)
-- # Seperate data and address busses. No arbitration necessary for internal
-- # memory thanks to dual-port ram. Arbirtation may be necessary on the external
-- # wishbone ports, but that is left up to the end use. 
-- # Internal memory accesses are guarenteed to complete in one cycle. 
-- # External wishbone accesses are not. 
-- # instruction access and data access may happen on the same cyle
-- # dren and dwen are guarenteed mutually exclusive  
-- # Internal memory has a fully shared instruction and data region 
-- # External memory may be split or shared or some overlapping combonaiton
-- # External wishbone accesses are asynchronous. Use the wishbone pipeline
-- # register module external to this if timing needs to be improved.  
-- # 
-- #############################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.gen_utils_pkg.all;

-- Entity ======================================================================
-- =============================================================================
entity rv32_mem is
    generic (
        G_USE_INT_MEM       : boolean                       := TRUE; 
        -- Must be on a 4 byte boundry and must be large enough to support 
        -- G_INT_MEM_SIZE_BYTES
        G_INT_MEM_BASE_ADDR  : std_logic_vector(31 downto 0) := x"0000_0000";
        -- Must be a power of 2
        G_INT_MEM_SIZE_BYTES : positive                      := 4 * 1024; 
        G_INT_MEM_INIT      : slv_array_t(0 to (G_INT_MEM_SIZE_BYTES/4)-1)(31 downto 0)
            := (others=>(others=>'0'));

        -- TODO: 
        G_CACHEABLE_REGION_START : std_logic_vector(31 downto 0) := x"8000_0000";
        G_CACHEABLE_REGION_END   : std_logic_vector(31 downto 0) := x"FFFF_FFFF";
        G_USE_ICACHE : boolean := FALSE;
        G_USE_DCACHE : boolean := FALSE

    );
    port (
        i_clk      : in std_logic;
        i_rst      : in std_logic;

        -- Instruction port from cpu
        i_iren     : in std_logic;
        i_iaddr    : in std_logic_vector(31 downto 0);
        i_ifence   : in std_logic;
        o_irdat    : out std_logic_vector(31 downto 0);
        o_istall   : out std_logic;
        o_ierror   : out std_logic;

        -- Data port from cpu
        i_dren     : in std_logic;
        i_dwen     : in std_logic;
        i_dsel     : in std_logic_vector(3 downto 0); -- byte select
        i_daddr    : in std_logic_vector(31 downto 0);
        i_dfence   : in std_logic;
        i_dwdat    : in std_logic_vector(31 downto 0);
        o_drdat    : out std_logic_vector(31 downto 0);
        o_dstall   : out std_logic;
        o_derror   : out std_logic;


        -- Instruction wishbone port to external interface
        o_wbi_cyc  : out std_logic;
        o_wbi_stb  : out std_logic;
        o_wbi_adr  : out std_logic_vector(31 downto 0);
        --o_wbi_wen : out std_logic;
        o_wbi_sel  : out std_logic_vector(3 downto 0);
        --o_wbi_wdat : out std_logic_vector(31 downto 0);
        i_wbi_stl  : in std_logic; 
        i_wbi_ack  : in std_logic;
        i_wbi_err  : in std_logic;
        i_wbi_rdat : in std_logic_vector(31 downto 0);
        
        -- Data wishbone port to external interface
        o_wbd_cyc  : out std_logic;
        o_wbd_stb  : out std_logic;
        o_wbd_adr  : out std_logic_vector(31 downto 0);
        o_wbd_wen  : out std_logic;
        o_wbd_sel  : out std_logic_vector(3 downto 0);
        o_wbd_wdat : out std_logic_vector(31 downto 0);
        i_wbd_stl  : in std_logic; 
        i_wbd_ack  : in std_logic;
        i_wbd_err  : in std_logic;
        i_wbd_rdat : in std_logic_vector(31 downto 0)     
        
    );
end entity rv32_mem;


-- Entity ======================================================================
-- =============================================================================
architecture rtl of rv32_mem is



    -- Represents the width of the address necessary to hold G_INT_MEM_SIZE_BYTES
    -- number of bytes 
    constant INT_MEM_ADDR_W : integer := clog2(G_INT_MEM_SIZE_BYTES);
    
    -- Since using byte addresses, but each row of internal memory is 4 bytes
    constant INT_MEM_DEPTH_L2 : integer := INT_MEM_ADDR_W-2;

    -- Used to select between internal and external memory
    subtype ADDR_SEL_RANGE is integer range 31 downto INT_MEM_ADDR_W;

    signal int_iren    : std_logic;
    signal int_iaddr   : std_logic_vector(INT_MEM_DEPTH_L2-1 downto 0);
    signal int_irdat   : std_logic_vector(31 downto 0);

    signal int_dren    : std_logic;
    signal int_dwen    : std_logic;
    signal int_daccess : std_logic; 
    signal int_daddr   : std_logic_vector(INT_MEM_DEPTH_L2-1 downto 0);
    signal int_dwdat   : std_logic_vector(31 downto 0);
    signal int_drdat   : std_logic_vector(31 downto 0);

    signal ext_iren    : std_logic;
    signal ext_iaddr   : std_logic_vector(INT_MEM_DEPTH_L2-1 downto 0);
    signal ext_irdat   : std_logic_vector(31 downto 0);

    signal ext_dren    : std_logic;
    signal ext_dwen    : std_logic;
    signal ext_daccess : std_logic; 
    signal ext_drdat   : std_logic_vector(31 downto 0);

    signal reg_int_iread : std_logic; 
    signal reg_ext_iread : std_logic; 
    signal reg_int_dread : std_logic; 
    signal reg_ext_dread : std_logic; 


-- Architecture ================================================================
-- =============================================================================
begin


    -- Caches TODO: --------------------------------------------------------
    -- -------------------------------------------------------------------------





    -- Can only access on 4-byte boundries
    int_iaddr <= i_iaddr(INT_MEM_ADDR_W-1 downto 2);
    int_daddr <= i_daddr(INT_MEM_ADDR_W-1 downto 2);


    -- Memory Selection --------------------------------------------------------
    -- -------------------------------------------------------------------------
    -- Choose between internal and external memory 
    -- 
    -- Requests ----------------------------------------------------------------
    process (all)
    begin
        if i_iaddr(ADDR_SEL_RANGE) = G_INT_MEM_BASE_ADDR(ADDR_SEL_RANGE) then
            int_iren <= i_iren; 
            int_dren <= i_dren; 
            int_dwen <= i_dwen; 

            ext_iren <= '0'; 
            ext_dren <= '0'; 
            ext_dwen <= '0'; 

        else 
            int_iren <= '0'; 
            int_dren <= '0'; 
            int_dwen <= '0'; 

            ext_iren <= i_iren; 
            ext_dren <= i_dren; 
            ext_dwen <= i_dwen; 
        end if; 
    end process;

    -- Responses ---------------------------------------------------------------
    process (i_clk)
    begin
        if rising_edge(i_clk) then
            if (int_iren) then
                reg_int_iread <= '1'; 
                reg_ext_iread <= '0';
            elsif (ext_iren) then
                reg_int_iread <= '0'; 
                reg_ext_iread <= '1';
            end if; 

            if (int_dren) then
                reg_int_dread <= '1'; 
                reg_ext_dread <= '0';
            elsif (ext_dren) then
                reg_int_dread <= '0'; 
                reg_ext_dread <= '1';
            end if; 

        end if;
    end process;

    process (all)
    begin
        if (reg_int_iread) then
            o_irdat  <= int_irdat;
        else
            o_irdat  <= ext_irdat;
        end if; 

        if (reg_int_dread) then
            o_drdat  <= int_drdat;
        else
            o_drdat  <= ext_drdat;
        end if; 
    end process;


    -- Internal memory ---------------------------------------------------------
    -- -------------------------------------------------------------------------
    -- One port for instructions fetches, another for data access
    u_internal_ram : entity work.memory_generator 
    generic map(
        G_BYTES_PER_ROW => 4,
        G_BYTE_WIDTH    => 8,
        G_DEPTH_L2      => INT_MEM_DEPTH_L2,
        G_MEM_STYLE     => "",
        G_MEM_INIT      => G_INT_MEM_INIT,
        G_A_RD_LATENCY  => 1,
        G_B_RD_LATENCY  => 1,
        G_A_RD_MODE     => 1,
        G_B_RD_MODE     => 1    
    )
    port map(
        -- Port A (Instruction fetch)
        i_a_clk  => i_clk,
        i_a_en   => int_iren,
        i_a_addr => int_iaddr,
        o_a_rdat => int_irdat,

        -- Port B (Data access)
        i_b_clk  => i_clk,
        i_b_en   => int_dren or int_dwen,
        i_b_we   => int_dwen and i_dsel,
        i_b_addr => int_daddr,
        i_b_wdat => i_dwdat,
        o_b_rdat => int_drdat
    );
     

    -- Wishbone Interfaces -----------------------------------------------------
    -- -------------------------------------------------------------------------
    -- Instruction
    u_wb_instr_if : entity work.rv32_wishbone_if
    port map (
        i_clk      => i_clk,
        i_rst      => i_rst,

        -- CPU Interface
        i_ren     => ext_iren,
        i_wen     => '0',
        i_sel     => (others=>'1'),
        i_addr    => i_iaddr,
        i_wdat    => (others=>'0'),
        o_rdat    => ext_irdat,
        o_stall   => o_istall,
        o_error   => o_ierror,
        
        -- Wishbone Interface
        o_wb_cyc  => o_wbi_cyc,
        o_wb_stb  => o_wbi_stb, 
        o_wb_adr  => o_wbi_adr, 
        o_wb_wen  => open, 
        o_wb_sel  => o_wbi_sel, 
        o_wb_wdat => open,
        i_wb_stl  => i_wbi_stl, 
        i_wb_ack  => i_wbi_ack, 
        i_wb_err  => i_wbi_err, 
        i_wb_rdat => i_wbi_rdat
    );

    -- Data
    u_wb_data_if : entity work.rv32_wishbone_if
    port map (
        i_clk      => i_clk,
        i_rst      => i_rst,

        -- CPU Interface
        i_ren     => ext_dren,
        i_wen     => ext_dwen,
        i_sel     => i_dsel,
        i_addr    => i_daddr,
        i_wdat    => i_dwdat,
        o_rdat    => ext_drdat,
        o_stall   => o_dstall,
        o_error   => o_derror,
        
        -- Wishbone Interface
        o_wb_cyc  => o_wbd_cyc,
        o_wb_stb  => o_wbd_stb, 
        o_wb_adr  => o_wbd_adr, 
        o_wb_wen  => o_wbd_wen, 
        o_wb_sel  => o_wbd_sel, 
        o_wb_wdat => o_wbd_wdat,
        i_wb_stl  => i_wbd_stl, 
        i_wb_ack  => i_wbd_ack, 
        i_wb_err  => i_wbd_err, 
        i_wb_rdat => i_wbd_rdat
    );


end architecture;

