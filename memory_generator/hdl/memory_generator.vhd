-- #############################################################################
-- #  -<< Memory Generator >>-
-- # ===========================================================================
-- # Copyright 2022, David Gusser
-- # ===========================================================================
-- # File     : memory_generator.vhd
-- # Author   : David Gussler - davidnguss@gmail.com 
-- # Language : VHDL '08
-- # ===========================================================================
-- # A highly configurable FPGA memory block. Has only been tested for Xilinx 
-- # devices, but it should work with any vendor's device. See example folder 
-- # for uses. 
-- # 
-- #############################################################################

-- Libraries -------------------------------------------------------------------
-- -----------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.gen_utils_pkg.all;


-- Entity ======================================================================
-- =============================================================================
entity memory_generator is 
    generic(
        -- Number of "bytes" per memory word; Each "byte" can be exclusivly 
        -- written; Set to 1 if indivudial bytes within each memory word do not 
        -- need to be exclusively written.
        -- Typically this generic is set in conjunction with G_BYTE_WIDTH when byte write
        -- granularity is required. For example: a RAM with 32 bit words and byte
        -- writes would set G_BYTES_PER_ROW=4 and G_BYTE_WIDTH=8. If byte writes are not
        -- required for the same 32 bit RAM, then DAT_N_COL=1 and DAT_COL_W=32
        G_BYTES_PER_ROW : integer range 1 to 64 := 4;

        -- Bit width of each "byte." "Byte" is in quotations because it does not 
        -- necessirially mean 8 bits in this context (but this would typically be
        -- set to 8 if interfacing with a microprocessor).
        G_BYTE_WIDTH    : integer range 1 to 64 := 8;

        -- Log base 2 of the memory depth; ie: 
        -- total size of the memory in bits = (2**DEPTH) * (G_BYTES_PER_ROW * G_BYTE_WIDTH)
        G_DEPTH_L2      : positive := 10;
        
        -- Ram synthesis attribute; Will suggest the style of memory to the synthesizer
        -- but if other generics are set in a way that is incompatible with the 
        -- suggested memory type, then the synthsizer will make the final style 
        -- decision.
        -- If this generic is left blank or if an unknown string is passed in,  
        -- then the synthesizer will decide what to do. 
        -- See Xilinx UG901 - Vivado Synthesis for more information on dedicated BRAMs
        -- Options: "block", "ultra", "distributed", "registers"
        G_MEM_STYLE     : string  := "";

        -- This generic makes use of VHDL '08 features, so it may not be supported 
        -- by all tools.
        -- If memory does not need to be initialized then there is no need to set
        -- generic and it can be left at its default value of (others=>(others=>'0')
        -- If memory does need to be initialized, then a constant should be defined:
        -- constant MEM_INIT  : slv_array_t(0 to DEPTH-1)(WIDTH-1 downto 0) := 
        -- (X"<init_val0>", X"<init_val1>", X"<init_val2>", X"<init_val3>", 
        --  X"<init_val4>", X"<init_val5>", X"<init_val6>", X"<init_val7>", ...etc)
        -- and passed to G_MEM_INIT  
        G_MEM_INIT      : slv_array_t(0 to (2**G_DEPTH_L2)-1)(G_BYTES_PER_ROW*G_BYTE_WIDTH-1 downto 0)
                := (others=>(others=>'0'));

        -- Read lataney. A value of 0 means that the read data output value is combinationally
        -- dependent on the address input. Registers will be used for the memories in this case.
        -- A value of 1 means that block rams can be used. 
        -- A value of 2 will add an extra register to the output of the BRAM, possibly 
        -- increasing the maximum frequency of the design. 
        G_A_RD_LATENCY  : natural range 0 to 4 := 2; 
        G_B_RD_LATENCY  : natural range 0 to 4 := 2; 

        -- 0: No change reads - During a write to an address, the data output by 
        -- the ram will be equal to the last value output by the ram during writes, 
        -- regardless of address input. Has the lower power performance.
        -- 1: Read before write - During a write to an address, The data oputput by the ram
        -- will be equal to the value stored in ram before the write took place. - Mitigates 
        -- read / write collisions. 
        -- See Xilinx Memory Resources User Guide for more information
        G_A_RD_MODE     : natural range 0 to 1 := 0; 
        G_B_RD_MODE     : natural range 0 to 1 := 0
    );
    port(
        -- Port A
        i_a_clk  : in std_logic := '0';
        i_a_en   : in std_logic := '1';
        i_a_we   : in std_logic_vector(G_BYTES_PER_ROW-1 downto 0) := (others=>'0');
        i_a_addr : in std_logic_vector(G_DEPTH_L2-1 downto 0) := (others=>'0');
        i_a_wdat : in std_logic_vector(G_BYTES_PER_ROW*G_BYTE_WIDTH-1 downto 0) := (others=>'0');
        o_a_rdat : out std_logic_vector(G_BYTES_PER_ROW*G_BYTE_WIDTH-1 downto 0);

        -- Port B
        i_b_clk  : in std_logic := '0';
        i_b_en   : in std_logic := '1';
        i_b_we   : in std_logic_vector(G_BYTES_PER_ROW-1 downto 0) := (others=>'0');
        i_b_addr : in std_logic_vector(G_DEPTH_L2-1 downto 0) := (others=>'0');
        i_b_wdat : in std_logic_vector(G_BYTES_PER_ROW*G_BYTE_WIDTH-1 downto 0) := (others=>'0');
        o_b_rdat : out std_logic_vector(G_BYTES_PER_ROW*G_BYTE_WIDTH-1 downto 0)
    );
end entity;


-- Architecture ================================================================
-- =============================================================================
architecture rtl of memory_generator is 
    -- Constants 
    constant DATA_WIDTH : integer := G_BYTES_PER_ROW * G_BYTE_WIDTH;
    constant NO_WRITE : std_logic_vector(G_BYTES_PER_ROW-1 downto 0) := (others=>'0');
    
    -- Wires
    signal a_idx : natural range 0 to 2**G_DEPTH_L2-1; 
    signal b_idx : natural range 0 to 2**G_DEPTH_L2-1;
    
    -- Ram
    -- NOTE: Using an unprotected shared vairable is NOT compliant with VHDL 08, BUT
    -- this is still how Xilinx recommends implementing a DPRAM... Sigh...
    -- You will get a synthesis warning but this can be ignored.
    shared variable ram : slv_array_t(0 to 2**G_DEPTH_L2-1)(DATA_WIDTH-1 downto 0) := G_MEM_INIT;


    -- Synthesis Attributes ------------------------------------------------------------------------
    -- ---------------------------------------------------------------------------------------------
    -- Viavado 
    attribute ram_style : string;
    attribute ram_style of ram : variable is G_MEM_STYLE;

begin

    -- Port A ======================================================================================
    -- =============================================================================================

    -- Assignments
    a_idx <= to_integer(unsigned(i_a_addr));

    -- Writes --------------------------------------------------------------------------------------
    -- ---------------------------------------------------------------------------------------------
    sp_a_write : process (i_a_clk)
    begin
        if rising_edge(i_a_clk) then 
            if i_a_en then 
                for i in 0 to G_BYTES_PER_ROW-1 loop
                    if i_a_we(i) then 
                        ram(a_idx)(i*G_BYTE_WIDTH+G_BYTE_WIDTH-1 downto i*G_BYTE_WIDTH) := 
                            i_a_wdat(i*G_BYTE_WIDTH+G_BYTE_WIDTH-1 downto i*G_BYTE_WIDTH); 
                    end if;
                end loop;
            end if; 
        end if;
    end process;


    -- Asynchronous Reads --------------------------------------------------------------------------
    -- ---------------------------------------------------------------------------------------------
    ig_a_async_read : if G_A_RD_LATENCY = 0 generate 
        o_a_rdat <= ram(a_idx); 
    end generate;


    -- No Change Reads -----------------------------------------------------------------------------
    -- ---------------------------------------------------------------------------------------------
    ig_a_no_change : if (G_A_RD_MODE = 0) generate

        -- Synchronous Reads 
        ig_a_sync_read : if (G_A_RD_LATENCY = 1) generate 
            sp_a_sync_read: process (i_a_clk)
            begin
                if rising_edge(i_a_clk) then 
                    if i_a_en = '1' and i_a_we = NO_WRITE then 
                        o_a_rdat <= ram(a_idx); 
                    end if;
                end if; 
            end process;
        end generate;

        -- Synchronous Reads & Output Pipeline Registers 
        ig_a_sync_read_pipes : if (G_A_RD_LATENCY > 1) generate 

            signal dat_pipe : slv_array_t(0 to G_A_RD_LATENCY-1)(DATA_WIDTH-1 downto 0);

        begin
            sp_a_sync_read: process (i_a_clk)
            begin
                if rising_edge(i_a_clk) then 
                    if i_a_en = '1' and i_a_we = NO_WRITE then 
                        dat_pipe(0) <= ram(a_idx); 
                    end if;

                    for i in 1 to G_A_RD_LATENCY-1 loop 
                        dat_pipe(i) <= dat_pipe(i-1); 
                    end loop; 
                end if; 
            end process; 
            o_a_rdat <= dat_pipe(G_A_RD_LATENCY-1); 
        end generate;
    end generate;




    -- Read First Reads ----------------------------------------------------------------------------
    -- ---------------------------------------------------------------------------------------------
    ig_a_read_first : if (G_A_RD_MODE = 1) generate

        -- Synchronous Reads 
        ig_a_sync_read : if (G_A_RD_LATENCY = 1) generate 
            sp_a_sync_read: process (i_a_clk)
            begin
                if rising_edge(i_a_clk) then 
                    if i_a_en then 
                        o_a_rdat <= ram(a_idx); 
                    end if;
                end if; 
            end process;
        end generate;

        -- Synchronous Reads & Output Pipeline Registers 
        ig_a_sync_read_pipes : if (G_A_RD_LATENCY > 1) generate 

            signal dat_pipe : slv_array_t(0 to G_A_RD_LATENCY-1)(DATA_WIDTH-1 downto 0);

        begin
            sp_a_sync_read: process (i_a_clk)
            begin
                if rising_edge(i_a_clk) then 
                    if i_a_en then 
                        dat_pipe(0) <= ram(a_idx); 
                    end if; 

                    for i in 1 to G_A_RD_LATENCY-1 loop 
                        dat_pipe(i) <= dat_pipe(i-1); 
                    end loop; 

                end if; 
            end process; 
            o_a_rdat <= dat_pipe(G_A_RD_LATENCY-1); 
        end generate;
    end generate;  





    -- Port B ======================================================================================
    -- =============================================================================================

    -- Assignments
    b_idx <= to_integer(unsigned(i_b_addr));

    -- Writes --------------------------------------------------------------------------------------
    -- ---------------------------------------------------------------------------------------------
    sp_b_write : process (i_b_clk)
    begin
        if rising_edge(i_b_clk) then 
            if i_b_en then 
                for i in 0 to G_BYTES_PER_ROW-1 loop
                    if i_b_we(i) then 
                        ram(b_idx)(i*G_BYTE_WIDTH+G_BYTE_WIDTH-1 downto i*G_BYTE_WIDTH) := 
                            i_b_wdat(i*G_BYTE_WIDTH+G_BYTE_WIDTH-1 downto i*G_BYTE_WIDTH); 
                    end if;
                end loop;
            end if; 
        end if;
    end process;


    -- Asynchronous Reads --------------------------------------------------------------------------
    -- ---------------------------------------------------------------------------------------------
    ig_b_async_read : if G_B_RD_LATENCY = 0 generate 
        o_b_rdat <= ram(b_idx); 
    end generate;


    -- No Change Reads -----------------------------------------------------------------------------
    -- ---------------------------------------------------------------------------------------------
    ig_b_no_change : if (G_B_RD_MODE = 0) generate

        -- Synchronous Reads 
        ig_b_sync_read : if (G_B_RD_LATENCY = 1) generate 
            sp_b_sync_read: process (i_b_clk)
            begin
                if rising_edge(i_b_clk) then 
                    if i_b_en = '1' and i_b_we = NO_WRITE then 
                        o_b_rdat <= ram(b_idx); 
                    end if;
                end if; 
            end process;
        end generate;

        -- Synchronous Reads & Output Pipeline Registers 
        ig_b_sync_read_pipes : if (G_B_RD_LATENCY > 1) generate 

            signal dat_pipe : slv_array_t(0 to G_B_RD_LATENCY-1)(DATA_WIDTH-1 downto 0);

        begin
            sp_b_sync_read: process (i_b_clk)
            begin
                if rising_edge(i_b_clk) then 
                    if i_b_en = '1' and i_b_we = NO_WRITE then 
                        dat_pipe(0) <= ram(b_idx); 
                    end if;

                    for i in 1 to G_B_RD_LATENCY-1 loop 
                        dat_pipe(i) <= dat_pipe(i-1); 
                    end loop; 

                end if; 
            end process; 
            o_b_rdat <= dat_pipe(G_B_RD_LATENCY-1); 
        end generate;
    end generate;


    -- Read First Reads ----------------------------------------------------------------------------
    -- ---------------------------------------------------------------------------------------------
    ig_b_read_first : if (G_B_RD_MODE = 1) generate

        -- Synchronous Reads 
        ig_b_sync_read : if (G_B_RD_LATENCY = 1) generate 
            sp_b_sync_read: process (i_b_clk)
            begin
                if rising_edge(i_b_clk) then 
                    if i_b_en then 
                        o_b_rdat <= ram(b_idx); 
                    end if;
                end if; 
            end process;
        end generate;

        -- Synchronous Reads & Output Pipeline Registers 
        ig_b_sync_read_pipes : if (G_B_RD_LATENCY > 1) generate 

            signal dat_pipe : slv_array_t(0 to G_B_RD_LATENCY-1)(DATA_WIDTH-1 downto 0);

        begin
            sp_b_sync_read: process (i_b_clk)
            begin
                if rising_edge(i_b_clk) then 
                    if i_b_en then 
                        dat_pipe(0) <= ram(b_idx); 
                    end if;

                    for i in 1 to G_B_RD_LATENCY-1 loop 
                        dat_pipe(i) <= dat_pipe(i-1); 
                    end loop; 

                end if; 
            end process; 
            o_b_rdat <= dat_pipe(G_B_RD_LATENCY-1); 
        end generate;
    end generate;  


end architecture;
