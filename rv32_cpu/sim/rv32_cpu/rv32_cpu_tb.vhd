library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.vc_context;
use work.gen_utils_pkg.all;
use work.rv32_pkg.all;
use work.rv32_testbench_pkg.all;
library neorv32;
use neorv32.neorv32_package.all;


entity rv32_cpu_tb is
    generic (runner_cfg : string);
end entity;

architecture tb of rv32_cpu_tb is

    -- Simulation Signals / Constants ------------------------------------------
    -- -------------------------------------------------------------------------
    constant CLK_PERIOD : time := 10 ns; 
    constant CLK_TO_Q   : time := 1 ns;

    constant MEM_LATENCY : positive := 2; 

    signal clk            : std_logic := '0';
    signal rst            : std_logic := '1';
    signal rstn           : std_logic := '0';


    -- DUT Signals / Constants -------------------------------------------------
    -- ------------------------------------------------------------------------- 

    constant HART_ID    : std_logic_vector(31 downto 0) := x"0000_0000";
    constant RESET_ADDR : std_logic_vector(31 downto 0) := x"0000_0000";
    constant TRAP_ADDR  : std_logic_vector(31 downto 0) := x"0000_0800";
    
    type cpu_t is record 
        iren     : std_logic; 
        iaddr    : std_logic_vector(31 downto 0);
        fencei   : std_logic; 
        irdat    : std_logic_vector(31 downto 0);
        iack     : std_logic; 
        ierr     : std_logic; 
        dren     : std_logic; 
        dwen     : std_logic; 
        dben     : std_logic_vector(3 downto 0);
        daddr    : std_logic_vector(31 downto 0);
        fence    : std_logic; 
        dwdat    : std_logic_vector(31 downto 0);
        drdat    : std_logic_vector(31 downto 0);
        dack     : std_logic; 
        derr     : std_logic; 
        ms_irq   : std_logic; 
        me_irq   : std_logic; 
        mt_irq   : std_logic; 
        sleep    : std_logic; 
        debug    : std_logic; 
        db_halt  : std_logic; 
        mtime    : std_logic_vector(31 downto 0); 
    end record; 

    type golden_t is record 
        addr : std_logic_vector(31 downto 0);
        rdat : std_logic_vector(31 downto 0);
        wdat : std_logic_vector(31 downto 0);
        ben  : std_logic_vector(3 downto 0);
        wen  : std_logic; 
        ren  : std_logic; 
        ack  : std_logic; 
        err  : std_logic; 
    end record;

    signal dut    : cpu_t;
    signal neorv  : cpu_t;
    signal golden : golden_t; 


    -- Used for memory latency
    signal iadr  : slv_array_t(0 to MEM_LATENCY-1)(31 downto 0);
    signal irack : std_logic_vector(0 to MEM_LATENCY-1); 
    signal dadr  : slv_array_t(0 to MEM_LATENCY-1)(31 downto 0); 
    signal drack : std_logic_vector(0 to MEM_LATENCY-1);
    signal dwack : std_logic_vector(0 to MEM_LATENCY-1);
    signal dwdat : slv_array_t(0 to MEM_LATENCY-1)(31 downto 0);
    signal dwben : slv_array_t(0 to MEM_LATENCY-1)(3 downto 0);

    signal iadr_dly  , iadr_sig  : std_logic_vector(31 downto 0);
    signal irack_dly , irack_sig : std_logic; 
    signal dadr_dly  , dadr_sig  : std_logic_vector(31 downto 0);
    signal drack_dly , drack_sig : std_logic; 
    signal dwack_dly , dwack_sig : std_logic; 
    signal dwdat_dly , dwdat_sig : std_logic_vector(31 downto 0);
    signal dwben_dly , dwben_sig : std_logic_vector(3 downto 0);


    -- CPU Memories 
    constant MEM_DEPTH     : natural := 1024; -- number of 32-bit words
    constant MEM_DEPTH_L2  : natural := clog2(MEM_DEPTH); 
    constant NUM_BYTES     : natural := MEM_DEPTH*4;
    constant ADDR_WIDTH    : natural := MEM_DEPTH_L2+2; 
    constant memory_dut    : memory_t := new_memory;
    constant mem1_buff     : buffer_t := allocate(memory_dut, NUM_BYTES);
    constant memory_golden : memory_t := new_memory;
    constant mem2_buff     : buffer_t := allocate(memory_golden, NUM_BYTES);


    -- Simple test programs ----------------------------------------------------
    -- -------------------------------------------------------------------------
    -- Simple programs for initial debug and testing. Will move to testing with 
    -- C-code once these basic assembly simulations pass. It is simpler to use
    -- this framework for testing individual instructions or small code chunks.
    -- It will make sense to start testing with C when I'm ready to move to larger
    -- programs. This is just nice because it lets us stay in the VHDL world 
    -- without having to rely on any external toolchains

    constant ITYPE_TEST : slv_array_t(0 to MEM_DEPTH-1)(31 downto 0) := (
        rv_addi(1, 0, 1),  -- 1
        rv_addi(2, 0, 2),  -- 2
        rv_slti(3, 2, 3),  -- 1
        rv_slti(4, 2,-3),  -- 0
        rv_sltui(5, 2, 3), -- 1
        rv_sltui(6, 2, 2), -- 0
        rv_xori(7, 2, 2),  -- 0
        rv_ori(8, 0, 123), -- 123
        rv_andi(9, 1, 3),  -- 1
        rv_slli(10, 2, 4), -- 32
        rv_srli(11, 2, 1), -- 1
        rv_srai(12, 2, 2), -- 0
        rv_lui(13, 29),
        rv_auipc(14, -23),

        rv_sw (0, 1,  1024),
        rv_sw (0, 2,  1024+1*4), 
        rv_sw (0, 3,  1024+2*4), 
        rv_sw (0, 4,  1024+3*4), 
        rv_sw (0, 5,  1024+4*4), 
        rv_sw (0, 6,  1024+5*4), 
        rv_sw (0, 7,  1024+6*4), 
        rv_sw (0, 8,  1024+7*4), 
        rv_sw (0, 9,  1024+8*4), 
        rv_sw (0, 10, 1024+9*4), 
        rv_sw (0, 11, 1024+10*4),
        rv_sw (0, 12, 1024+11*4),
        rv_sw (0, 13, 1024+12*4),
        rv_sw (0, 14, 1024+13*4),

        rv_jal (0, 0),

        others => (others=>'0')
    );


    constant RTYPE_TEST : slv_array_t(0 to MEM_DEPTH-1)(31 downto 0) := (
        rv_addi(1, 0, 4),   -- 0
        rv_addi(2, 0, -13), -- 4
        rv_sub(3, 1, 2),    -- 8
        rv_sll(1, 3, 2),    -- C
        rv_slt(1, 3, 2),-- 10
        rv_sltu(4, 1, 3),-- 14
        rv_xor(5, 1, 2),-- 18
        rv_srl(2, 3, 2),-- 1C
        rv_sra(2, 3, 2),-- 20
        rv_or(6,5,1),-- 24
        rv_and(7,6,4),-- 28

        rv_sw (0, 1,  1024),-- 2c
        rv_sw (0, 2,  1024+1*4), -- 30
        rv_sw (0, 3,  1024+2*4), -- 34
        rv_sw (0, 4,  1024+3*4), -- 38
        rv_sw (0, 5,  1024+4*4), -- 3c
        rv_sw (0, 6,  1024+5*4), -- 40
        rv_sw (0, 7,  1024+6*4), -- 44
        
        rv_jal (0, 0),--48
    
        others => (others=>'0')
    );


    constant BRANCH_TEST : slv_array_t(0 to MEM_DEPTH-1)(31 downto 0) := (
        rv_addi(1, 0, 14),  -- 0
        rv_addi(2, 0, 25), -- 4
        rv_addi(3, 0, -36), -- 8

        rv_beq(2, 2, 8/2), -- c   branch to 14
        rv_addi(4, 0, 1), -- 10  skipped
        rv_beq(2, 3, 8/2), -- 14 no branch, 18 is next instruction
        rv_addi(5, 0, 1),  -- 18

        rv_bne(2, 3, 8/2), --1c    branch to 24
        rv_addi(6, 0, 1), -- 20 -- skipped
        rv_bne(1, 1, 8/2), -- 24  -- no branch, 28 is next
        rv_addi(7, 0, 1), --28

        rv_blt(3, 2, 8/2), --2c
        rv_addi(8, 0, 1),  -- 30
        rv_blt(2, 3, 8/2), --34
        rv_addi(9, 0, 1), --38

        rv_bge(2, 1, 8/2), --3c
        rv_addi(10, 0, 1), --40
        rv_bge(1, 2, 8/2), --44
        rv_addi(11, 0, 1), -- 48

        rv_bltu(3, 2, 8/2), --4c
        rv_addi(12, 0, 1), --50 
        rv_bltu(2, 3, 8/2), --54 -- branch to 5c
        rv_addi(13, 0, 1), --58

        rv_bgeu(2, 1, 8/2), --5c
        rv_addi(14, 0, 1), -- 60
        rv_bgeu(1, 2, 8/2), --64
        rv_addi(15, 0, 1), --68

        rv_sw (0, 1,  1024), --6c (400)
        rv_sw (0, 2,  1024+1*4), 
        rv_sw (0, 3,  1024+2*4), 
        rv_sw (0, 4,  1024+3*4), 
        rv_sw (0, 5,  1024+4*4), 
        rv_sw (0, 6,  1024+5*4), 
        rv_sw (0, 7,  1024+6*4), 
        rv_sw (0, 8,  1024+7*4), 
        rv_sw (0, 9,  1024+8*4), 
        rv_sw (0, 10, 1024+9*4), 
        rv_sw (0, 11, 1024+10*4), 
        rv_sw (0, 12, 1024+11*4), 
        rv_sw (0, 13, 1024+12*4), 
        rv_sw (0, 14, 1024+13*4), 

        rv_jal (0, 0),
    
        others => (others=>'0')
    );


    constant JALR_TEST : slv_array_t(0 to MEM_DEPTH-1)(31 downto 0) := (
        0  => rv_addi(1, 0, 4), 

        1  => rv_addi(5, 0, 5),
        2  => rv_jalr(3, 1, 1000-4),
        3  => rv_addi(5, 0, 6),
        4  => rv_sw(0, 5, 1024+1*4),

        5  => rv_jal (0, 0),

        1000/4 => rv_sw(0, 5, 1024),
        1004/4 => rv_jalr(0, 3, 0),

        others => (others=>'0')
    );


    constant CSR_TEST : slv_array_t(0 to MEM_DEPTH-1)(31 downto 0) := (
        rv_addi(1, 0, 444),
        rv_addi(2, 0, 4), 

        rv_csrrw(3, 1, to_integer(unsigned(CSR_MEPC))),
        rv_csrrc(4, 2, to_integer(unsigned(CSR_MEPC))),
        rv_csrrs(4, 0, to_integer(unsigned(CSR_MEPC))),

        rv_csrrwi(5, 12, to_integer(unsigned(CSR_MEPC))),
        rv_csrrci(6, 4, to_integer(unsigned(CSR_MEPC))),
        rv_csrrsi(7, 0, to_integer(unsigned(CSR_MEPC))),

        rv_sw (0, 1,  1024),
        rv_sw (0, 2,  1024+1*4), 
        rv_sw (0, 3,  1024+2*4), 
        rv_sw (0, 4,  1024+3*4), 
        rv_sw (0, 5,  1024+4*4), 
        rv_sw (0, 6,  1024+5*4), 
        rv_sw (0, 7,  1024+6*4), 

        rv_jal (0, 0),

        others => (others=>'0')
    );


    constant LOAD_STORE_TEST : slv_array_t(0 to MEM_DEPTH-1)(31 downto 0) := (
        0  => rv_addi(1, 0, 1000),
        1  => rv_lw(2, 1, 0),
        2  => rv_lh(3, 1, 4),
        3  => rv_lb(4, 1, 0),
        4  => rv_lw(5, 1, 8),
        5  => rv_lhu(6, 1, 8),
        6  => rv_lbu(7, 1, 8),

        7  => rv_addi(8, 0, 1024),
        8  => rv_sw(8, 1, 0),
        9  => rv_sw(8, 2, 4*1),
        10 => rv_sw(8, 3, 4*2),
        11 => rv_sw(8, 4, 4*3),
        12 => rv_sw(8, 5, 4*4),
        13 => rv_sw(8, 6, 4*5),
        14 => rv_sw(8, 7, 4*6),

        15 => rv_sh(8, 1, 4*7),
        16 => rv_sh(8, 2, 4*8),
        17 => rv_sh(8, 3, 4*9),
        18 => rv_sh(8, 4, 4*10),
        19 => rv_sh(8, 5, 4*11),
        20 => rv_sh(8, 6, 4*12),
        21 => rv_sh(8, 7, 4*13),

        22 => rv_sb(8, 1, 4*14),
        23 => rv_sb(8, 2, 4*15),
        24 => rv_sb(8, 3, 4*16),
        25 => rv_sb(8, 4, 4*17),
        26 => rv_sb(8, 5, 4*18),
        27 => rv_sb(8, 6, 4*19),
        28 => rv_sb(8, 7, 4*20),

        29 => rv_jal (0, 0),

        -- data
        1000/4 => x"1234_5678",
        1004/4 => x"9ABC_DEF0",
        1008/4 => x"F101_DEFA",

        others => (others=>'0')
    );


    constant EXCEPTION_TEST : slv_array_t(0 to MEM_DEPTH-1)(31 downto 0) := (
        0  => rv_addi(10, 0, to_integer(unsigned(TRAP_ADDR))), 
        1  => rv_csrrw(0, 10, to_integer(unsigned(CSR_MTVEC))), -- set the trap handler address    

        2  => rv_addi(1, 0, 3), 
        3  => rv_addi(2, 0, 4),  
        4  => rv_addi(8, 0, 1024),
        5  => rv_ecall,

        6  => rv_addi(1, 0, 5), 
        7  => rv_addi(2, 0, 6),
        8  => rv_addi(8, 0, 1024+8),
        9  => rv_ebreak,

        10 => rv_addi(1, 0, 7), 
        11 => rv_addi(2, 0, 8),
        12 => rv_addi(8, 0, 1024+16),
        13 => rv_sw(8, 1, 0),
        14 => rv_sw(8, 2, 4), 

        15 => rv_jal (0, 0),

        -- ecall/ebreak irq handler
        (to_integer(unsigned(TRAP_ADDR)))/4     => rv_sw(8, 1, 0),
        (to_integer(unsigned(TRAP_ADDR))+4)/4   => rv_sw(8, 2, 4), 
        (to_integer(unsigned(TRAP_ADDR))+4*2)/4 => rv_csrrci(15, 0, to_integer(unsigned(CSR_MEPC))),
        (to_integer(unsigned(TRAP_ADDR))+4*3)/4 => rv_addi(15, 15, 4),  
        (to_integer(unsigned(TRAP_ADDR))+4*4)/4 => rv_csrrw(0, 15, to_integer(unsigned(CSR_MEPC))),
        (to_integer(unsigned(TRAP_ADDR))+4*5)/4 => rv_mret,

        others => (others=>'0')
    );

    constant STALL_HAZARD_TEST : slv_array_t(0 to MEM_DEPTH-1)(31 downto 0) := (
        0  => rv_addi(1, 0, 1000),
        1  => rv_lw(2, 1, 0),
        2  => rv_lw(3, 1, 4),
        3  => rv_add(4, 2, 3),
        4  => rv_add(5, 2, 3),

        5  => rv_addi(8, 0, 111),
        6  => rv_lw(6, 1, 8),
        7  => rv_lw(7, 1, 8),
        8  => rv_beq(6, 7, 4*4),

        9  => rv_addi(8, 0, 1),
        10 => rv_addi(8, 0, 2),
        11 => rv_addi(8, 0, 3),

        12 => rv_addi(10, 0, 111),
        13 => rv_lw(9, 1, 8),
        14 => rv_bne(9, 9, 4*4),

        15 => rv_addi(10, 0, 1),
        16 => rv_addi(10, 0, 2),
        17 => rv_addi(10, 0, 3),

        18 => rv_addi(11, 0, 56),
        19 => rv_bge(10,11, 4),

        20 => rv_lw(12, 1, 4*3),
        21 => rv_jalr(13, 12, 1012-4),

        22 => rv_sw(0, 1,  1024),
        23 => rv_sw(0, 2,  1024+1*4), 
        24 => rv_sw(0, 3,  1024+2*4), 
        25 => rv_sw(0, 4,  1024+3*4), 
        26 => rv_sw(0, 5,  1024+4*4), 
        27 => rv_sw(0, 6,  1024+5*4), 
        28 => rv_sw(0, 7,  1024+6*4), 
        29 => rv_sw(0, 8,  1024+7*4), 
        30 => rv_sw(0, 9,  1024+8*4), 
        31 => rv_sw(0, 10, 1024+9*4), 
        32 => rv_sw(0, 11, 1024+10*4), 
        33 => rv_sw(0, 12, 1024+11*4), 
        34 => rv_sw(0, 13, 1024+12*4), 

        35 => rv_jal(0, 0),

        -- data
        1000/4 => x"1234_5678",
        1004/4 => x"9ABC_DEF0",
        1008/4 => x"F101_DEFA",
        1012/4 => x"0000_0004",

        -- jalr location
        1016/4 => rv_sw(0, 5, 1024),
        1020/4 => rv_jalr(0, 13, 0),

        others => (others=>'0')
    );


    -- Generate a random sequence of instructions
    -- TODO: 
    constant RANDOM_TEST : slv_array_t(0 to MEM_DEPTH-1)(31 downto 0) := (
        rv_addi(10, 0, 223),

        rv_jal (0, 0),

        others => (others=>'0')
    );


    -- TODO: Re-run all tests, but inject random data and instruction memory stalls


    -- Memory Procedures -------------------------------------------------------
    -- -------------------------------------------------------------------------
    procedure mem_init (memory : memory_t; program : slv_array_t) is
    begin
        for i in 0 to MEM_DEPTH-1 loop
            write_word(memory, i*4, program(i));
        end loop;
    end procedure;


    procedure mem_print(memory : memory_t) is 
        variable v_mem_word : std_logic_vector(31 downto 0); 
    begin 
        for i in 0 to MEM_DEPTH-1 loop
            v_mem_word := read_word(memory, i*4, 4);
            info("Address:" & to_string(i*4) & "  |  Data:" & to_string(v_mem_word));
        end loop;
    end procedure; 


    procedure mem_check(memory1 : memory_t; memory2 : memory_t) is 
        variable v_mem1_word : std_logic_vector(31 downto 0); 
        variable v_mem2_word : std_logic_vector(31 downto 0); 
    begin 
        for i in 0 to MEM_DEPTH-1 loop
            v_mem1_word := read_word(memory1, i*4, 4);
            v_mem2_word := read_word(memory2, i*4, 4);
            check_equal(v_mem1_word, v_mem2_word, "Memory does not match at address 0x" & to_hstring(to_signed(i*4, 32)));
        end loop;
    end procedure; 


begin
    -- Main TB Process ---------------------------------------------------------
    -- -------------------------------------------------------------------------
    main : process
    begin
        test_runner_setup(runner, runner_cfg);
        while test_suite loop
            if run("i-type") then
                info("Loading i-type test program into memories...");
                mem_init(memory_dut, ITYPE_TEST); 
                --mem_print(memory_dut);
                mem_init(memory_golden, ITYPE_TEST); 

                info("Resetting DUT and model...");
                wait until rising_edge(clk);
                
                info("Runing test program...");
                rst <= '1', '0' after 16 * CLK_PERIOD + CLK_TO_Q;
                wait for 500 * CLK_PERIOD;

                info("Checking results...");
                mem_check(memory_dut, memory_golden);

                info("I-Type Test Success!");



            elsif run("r-type") then
                info("Loading r-type test program into memories...");
                mem_init(memory_dut, RTYPE_TEST); 
                mem_init(memory_golden, RTYPE_TEST); 

                info("Resetting DUT and model...");
                wait until rising_edge(clk);
                
                info("Runing test program...");
                rst <= '1', '0' after 16 * CLK_PERIOD + CLK_TO_Q;
                wait for 500 * CLK_PERIOD;

                info("Checking results...");
                mem_check(memory_dut, memory_golden);

                info("R-Type Test Success!");



            elsif run("branch") then
                info("Loading branch test program into memories...");
                mem_init(memory_dut, BRANCH_TEST); 
                mem_init(memory_golden, BRANCH_TEST); 

                info("Resetting DUT and model...");
                wait until rising_edge(clk);
                
                info("Runing test program...");
                rst <= '1', '0' after 16 * CLK_PERIOD + CLK_TO_Q;
                wait for 500 * CLK_PERIOD;

                info("Checking results...");
                mem_check(memory_dut, memory_golden);

                info("Branch Test Success!");
            


            elsif run("jalr") then
                info("Loading jalr test program into memories...");
                mem_init(memory_dut, JALR_TEST); 
                mem_init(memory_golden, JALR_TEST); 

                info("Resetting DUT and model...");
                wait until rising_edge(clk);
                
                info("Runing test program...");
                rst <= '1', '0' after 16 * CLK_PERIOD + CLK_TO_Q;
                wait for 500 * CLK_PERIOD;

                info("Checking results...");
                mem_check(memory_dut, memory_golden);

                info("JALR Test Success!");



            elsif run("csr") then
                info("Loading csr test program into memories...");
                mem_init(memory_dut, CSR_TEST); 
                mem_init(memory_golden, CSR_TEST); 

                info("Resetting DUT and model...");
                wait until rising_edge(clk);
                
                info("Runing test program...");
                rst <= '1', '0' after 16 * CLK_PERIOD + CLK_TO_Q;
                wait for 500 * CLK_PERIOD;

                info("Checking results...");
                mem_check(memory_dut, memory_golden);

                info("CSR Test Success!");



            elsif run("load_store") then
                info("Loading load/store test program into memories...");
                mem_init(memory_dut, LOAD_STORE_TEST); 
                mem_init(memory_golden, LOAD_STORE_TEST); 

                info("Resetting DUT and model...");
                wait until rising_edge(clk);
                
                info("Runing test program...");
                rst <= '1', '0' after 16 * CLK_PERIOD + CLK_TO_Q;
                wait for 500 * CLK_PERIOD;

                info("Checking results...");
                mem_check(memory_dut, memory_golden);

                info("Load/Store Test Success!");


            
            elsif run("exception") then
                info("Loading exception test program into memories...");
                mem_init(memory_dut, EXCEPTION_TEST); 
                mem_init(memory_golden, EXCEPTION_TEST); 

                info("Resetting DUT and model...");
                wait until rising_edge(clk);
                
                info("Runing test program...");
                rst <= '1', '0' after 16 * CLK_PERIOD + CLK_TO_Q;
                wait for 500 * CLK_PERIOD;

                info("Checking results...");
                mem_check(memory_dut, memory_golden);

                info("Exception Test Success!");



            elsif run("stall-hazard") then
                info("Loading stall-hazard test program into memories...");
                mem_init(memory_dut, STALL_HAZARD_TEST); 
                mem_init(memory_golden, STALL_HAZARD_TEST); 

                info("Resetting DUT and model...");
                wait until rising_edge(clk);
                
                info("Runing test program...");
                rst <= '1', '0' after 16 * CLK_PERIOD + CLK_TO_Q;
                wait for 500 * CLK_PERIOD;

                info("Checking results...");
                mem_check(memory_dut, memory_golden);

                info("Stall-Hazard Test Success!");


            elsif run("random") then
                info("Loading random instruction sequence into memories...");
                mem_init(memory_dut, RANDOM_TEST); 
                mem_init(memory_golden, RANDOM_TEST); 

                info("Resetting DUT and model...");
                wait until rising_edge(clk);
                
                info("Runing test program...");
                rst <= '1', '0' after 16 * CLK_PERIOD + CLK_TO_Q;
                wait for 500 * CLK_PERIOD;

                info("Checking results...");
                mem_check(memory_dut, memory_golden);

                info("Random Instrunction Sequence Test Success!");


            end if;
        end loop;

        test_runner_cleanup(runner);
    end process;



    -- TB Signals --------------------------------------------------------------
    -- -------------------------------------------------------------------------
    clk  <= not clk after CLK_PERIOD / 2;
    rstn <= not rst;





    -- =========================================================================
    -- DUT =====================================================================
    -- =========================================================================
    u_dut_cpu : entity work.rv32_cpu
    generic map (
        G_HART_ID    => HART_ID,
        G_RESET_ADDR => RESET_ADDR
    )
    port map (
        -- Clock & Reset
        i_clk       => clk,
        i_rst       => rst,
        
        -- Instruction  Interface 
        o_iren   => dut.iren  ,
        o_iaddr  => dut.iaddr ,
        o_fencei => dut.fencei,
        i_irdat  => dut.irdat ,
        i_iack   => dut.iack,
        i_ierror => dut.ierr,

        -- Data Interface 

        o_dren   => dut.dren  ,
        o_dwen   => dut.dwen  ,
        o_dben   => dut.dben  ,
        o_daddr  => dut.daddr ,
        o_dwdat  => dut.dwdat ,
        o_fence  => dut.fence ,
        i_drdat  => dut.drdat ,
        i_dack   => dut.dack,
        i_derror => dut.derr,   

        -- Interrupts
        i_ms_irq    => dut.ms_irq,
        i_me_irq    => dut.me_irq,
        i_mt_irq    => dut.mt_irq,

        -- Other
        o_sleep     => dut.sleep,
        o_debug     => dut.debug,
        i_db_halt   => dut.db_halt,
        i_mtime     => dut.mtime  
    );
    

    -- DUT Memory --------------------------------------------------------------
    -- -------------------------------------------------------------------------
    
    sp_reg_mem : process (all)
    begin
        irack_sig <= '0';
        drack_sig <= '0'; 
        dwack_sig <= '0'; 

        iadr_sig  <= (others=>'X');
        dadr_sig  <= (others=>'X');
        dwdat_sig <= (others=>'X');
        dwben_sig <= (others=>'X');

        if (dut.iren) then 
            iadr_sig  <= dut.iaddr; 
            irack_sig <= not rst; 
        end if;

        if (dut.dren) then 
            dadr_sig  <= dut.daddr; 
            drack_sig <= not rst; 
        end if;

        if (dut.dwen) then 
            dadr_sig  <= dut.daddr; 
            dwdat_sig <= dut.dwdat; 
            dwben_sig <= dut.dben; 
            dwack_sig <= not rst; 
        end if;
    end process;

    ig_latency1 : if MEM_LATENCY = 1 generate
        iadr_dly  <= iadr_sig;
        irack_dly <= irack_sig;
        dadr_dly  <= dadr_sig;
        drack_dly <= drack_sig;
        dwack_dly <= dwack_sig;
        dwdat_dly <= dwdat_sig;
        dwben_dly <= dwben_sig;
    end generate; 

    ig_latency2 : if MEM_LATENCY = 2 generate
        process (clk)
        begin
            if rising_edge(clk) then
                iadr_dly  <= iadr_sig;
                irack_dly <= irack_sig;
                dadr_dly  <= dadr_sig;
                drack_dly <= drack_sig;
                dwack_dly <= dwack_sig;
                dwdat_dly <= dwdat_sig;
                dwben_dly <= dwben_sig;
            end if;
        end process;
    end generate; 

    ig_latency3 : if MEM_LATENCY > 2 generate
        process (clk)
        begin
            if rising_edge(clk) then

                iadr(0)  <= iadr_sig;
                irack(0) <= irack_sig;
                dadr(0)  <= dadr_sig;
                drack(0) <= drack_sig;
                dwack(0) <= dwack_sig;
                dwdat(0) <= dwdat_sig;
                dwben(0) <= dwben_sig;

                for i in 1 to MEM_LATENCY-2 loop
                    iadr(i)  <= iadr(i-1); 
                    irack(i) <= irack(i-1);
                    dadr(i)  <= dadr(i-1); 
                    drack(i) <= drack(i-1);
                    dwack(i) <= dwack(i-1);
                    dwdat(i) <= dwdat(i-1);
                    dwben(i) <= dwben(i-1); 
                end loop;
            end if;
        end process;

        iadr_dly  <= iadr(MEM_LATENCY-2) ;
        irack_dly <= irack(MEM_LATENCY-2);
        dadr_dly  <= dadr(MEM_LATENCY-2) ;
        drack_dly <= drack(MEM_LATENCY-2);
        dwack_dly <= dwack(MEM_LATENCY-2);
        dwdat_dly <= dwdat(MEM_LATENCY-2);
        dwben_dly <= dwben(MEM_LATENCY-2);

    end generate;


        

    np_iread : process
        variable v_dat : std_logic_vector(31 downto 0);
    begin
        wait until rising_edge(clk);
        if (irack_dly) then 
            dut.iack <= '1';
            v_dat := read_word(memory_dut, to_integer(unsigned(iadr_dly(ADDR_WIDTH-1 downto 0))), 4);
            dut.irdat <= v_dat;
        else 
            dut.iack <= '0';
            dut.irdat <= (others=>'X');
        end if; 
    end process;

    np_dread : process
        variable v_dat : std_logic_vector(31 downto 0);
    begin
        wait until rising_edge(clk);
        if (drack_dly) then 
            v_dat := read_word(memory_dut, to_integer(unsigned(dadr_dly(ADDR_WIDTH-1 downto 0))), 4);
            dut.drdat <= v_dat;
        else 
            dut.drdat <= (others=>'X');
        end if; 
    end process;

    np_dwrite : process
    begin
        wait until rising_edge(clk);
        if (dwack_dly) then 
            if (dwben_dly(0)) then 
                write_word(memory_dut, to_integer(unsigned(dadr_dly(ADDR_WIDTH-1 downto 0)) + 0), dwdat_dly(7 downto 0));
            end if; 
            if (dwben_dly(1)) then 
                write_word(memory_dut, to_integer(unsigned(dadr_dly(ADDR_WIDTH-1 downto 0)) + 1), dwdat_dly(15 downto 8));
            end if; 
            if (dwben_dly(2)) then 
                write_word(memory_dut, to_integer(unsigned(dadr_dly(ADDR_WIDTH-1 downto 0)) + 2), dwdat_dly(23 downto 16));
            end if; 
            if (dwben_dly(3)) then 
                write_word(memory_dut, to_integer(unsigned(dadr_dly(ADDR_WIDTH-1 downto 0)) + 3), dwdat_dly(31 downto 24));
            end if;
        end if;  
    end process;

    np_dack : process
    begin
        wait until rising_edge(clk);
        if (drack_dly or dwack_dly) then 
            dut.dack <= '1';
        else 
            dut.dack <= '0';
        end if; 
    end process;
    
    dut.ierr   <= '0';
    dut.derr   <= '0';


    -- Interrupts --------------------------------------------------------------
    -- -------------------------------------------------------------------------
    dut.ms_irq  <= '0';
    dut.me_irq  <= '0';
    dut.mt_irq  <= '0';
    dut.db_halt <= '0';
    dut.mtime   <= x"1234_5678";









    -- =========================================================================
    -- Golden Model ============================================================
    -- =========================================================================
    u_neorv32_cpu : entity neorv32.neorv32_cpu
    generic map (
        -- General --
        HW_THREAD_ID                 => to_integer(unsigned(HART_ID)),                 -- hardware thread id
        CPU_BOOT_ADDR                => RESET_ADDR,              -- cpu boot address
        CPU_DEBUG_ADDR               => TRAP_ADDR,                    -- cpu debug mode start address
        -- RISC-V CPU Extensions --
        CPU_EXTENSION_RISCV_B        => FALSE,        -- implement bit-manipulation extension?
        CPU_EXTENSION_RISCV_C        => FALSE,        -- implement compressed extension?
        CPU_EXTENSION_RISCV_E        => FALSE,        -- implement embedded RF extension?
        CPU_EXTENSION_RISCV_M        => FALSE,        -- implement mul/div extension?
        CPU_EXTENSION_RISCV_U        => FALSE,        -- implement user mode extension?
        CPU_EXTENSION_RISCV_Zfinx    => FALSE,    -- implement 32-bit floating-point extension (using INT reg!)
        CPU_EXTENSION_RISCV_Zicsr    => TRUE,    -- implement CSR system?
        CPU_EXTENSION_RISCV_Zicntr   => TRUE,   -- implement base counters?
        CPU_EXTENSION_RISCV_Zihpm    => TRUE,    -- implement hardware performance monitors?
        CPU_EXTENSION_RISCV_Zifencei => TRUE, -- implement instruction stream sync.?
        CPU_EXTENSION_RISCV_Zmmul    => FALSE,    -- implement multiply-only M sub-extension?
        CPU_EXTENSION_RISCV_Zxcfu    => FALSE,    -- implement custom (instr.) functions unit?
        CPU_EXTENSION_RISCV_DEBUG    => FALSE,          -- implement CPU debug mode?
        -- Extension Options --
        FAST_MUL_EN                  => FALSE,                  -- use DSPs for M extension's multiplier
        FAST_SHIFT_EN                => TRUE,                -- use barrel shifter for shift operations
        CPU_IPB_ENTRIES              => 8,              -- entries is instruction prefetch buffer, has to be a power of 2
        -- Physical Memory Protection (PMP) --
        PMP_NUM_REGIONS              => 16,              -- number of regions (0..16)
        PMP_MIN_GRANULARITY          => 16,          -- minimal region granularity in bytes, has to be a power of 2, min 4 bytes
        -- Hardware Performance Monitors (HPM) --
        HPM_NUM_CNTS                 => 0,                 -- number of implemented HPM counters (0..29)
        HPM_CNT_WIDTH                => 32                 -- total size of HPM counters (0..64)
    )
    port map (
        -- global control --
        clk_i         => clk,       -- global clock, rising edge
        rstn_i        => rstn,    -- global reset, low-active, async
        sleep_o       => neorv.sleep, -- cpu is in sleep mode when set
        debug_o       => open, -- cpu is in debug mode when set
        -- instruction bus interface --
        i_bus_addr_o  => neorv.iaddr,  -- bus access address
        i_bus_rdata_i => neorv.irdat, -- bus read data
        i_bus_re_o    => neorv.iren,    -- read request
        i_bus_ack_i   => neorv.iack,   -- bus transfer acknowledge
        i_bus_err_i   => neorv.ierr,   -- bus transfer error
        i_bus_fence_o => neorv.fencei, -- executed FENCEI operation
        i_bus_priv_o  => open,  -- current effective privilege level
        -- data bus interface --
        d_bus_addr_o  => neorv.daddr,  -- bus access address
        d_bus_rdata_i => neorv.drdat, -- bus read data
        d_bus_wdata_o => neorv.dwdat, -- bus write data
        d_bus_ben_o   => neorv.dben,   -- byte enable
        d_bus_we_o    => neorv.dwen,    -- write request
        d_bus_re_o    => neorv.dren,    -- read request
        d_bus_ack_i   => neorv.dack,   -- bus transfer acknowledge
        d_bus_err_i   => neorv.derr,   -- bus transfer error
        d_bus_fence_o => neorv.fence, -- executed FENCE operation
        d_bus_priv_o  => open,  -- current effective privilege level
        -- system time input from MTIME --
        time_i(63 downto 32) => (others=>'0'),  -- current system time
        time_i(31 downto 0)  => neorv.mtime,    -- current system time
        -- non-maskable interrupt --
        msw_irq_i     => neorv.ms_irq,  -- machine software interrupt
        mext_irq_i    => neorv.me_irq,  -- machine external interrupt request
        mtime_irq_i   => neorv.mt_irq,  -- machine timer interrupt
        -- fast interrupts (custom) --
        firq_i        => (others=>'0'),    -- fast interrupt trigger
        -- debug mode (halt) request --
        db_halt_req_i => neorv.db_halt
    );


    u_neorv32_busswitch: entity neorv32.neorv32_busswitch
    generic map (
      PORT_CA_READ_ONLY => false, -- set if controller port A is read-only
      PORT_CB_READ_ONLY => true   -- set if controller port B is read-only
    )
    port map (
      -- global control --
      clk_i           => clk,          -- global clock, rising edge
      rstn_i          => rstn,       -- global reset, low-active, async
      -- controller interface a --
      ca_bus_priv_i   => '0',     -- current privilege level
      ca_bus_cached_i => '0',   -- set if cached transfer
      ca_bus_addr_i   => neorv.daddr,     -- bus access address
      ca_bus_rdata_o  => neorv.drdat,    -- bus read data
      ca_bus_wdata_i  => neorv.dwdat,    -- bus write data
      ca_bus_ben_i    => neorv.dben,      -- byte enable
      ca_bus_we_i     => neorv.dwen,       -- write enable
      ca_bus_re_i     => neorv.dren,       -- read enable
      ca_bus_ack_o    => neorv.dack,      -- bus transfer acknowledge
      ca_bus_err_o    => neorv.derr,      -- bus transfer error
      -- controller interface b --
      cb_bus_priv_i   => '0',   -- current privilege level
      cb_bus_cached_i => '0', -- set if cached transfer
      cb_bus_addr_i   => neorv.iaddr,   -- bus access address
      cb_bus_rdata_o  => neorv.irdat,  -- bus read data
      cb_bus_wdata_i  => (others => '0'),
      cb_bus_ben_i    => (others => '0'),
      cb_bus_we_i     => '0',
      cb_bus_re_i     => neorv.iren,     -- read enable
      cb_bus_ack_o    => neorv.iack,    -- bus transfer acknowledge
      cb_bus_err_o    => neorv.ierr,    -- bus transfer error
      -- peripheral bus --
      p_bus_priv_o    => open,     -- current privilege level
      p_bus_cached_o  => open,   -- set if cached transfer
      p_bus_src_o     => open,      -- access source: 0 = A (data), 1 = B (instructions)
      p_bus_addr_o    => golden.addr,     -- bus access address
      p_bus_rdata_i   => golden.rdat,    -- bus read data
      p_bus_wdata_o   => golden.wdat,    -- bus write data
      p_bus_ben_o     => golden.ben,      -- byte enable
      p_bus_we_o      => golden.wen,       -- write enable
      p_bus_re_o      => golden.ren,       -- read enable
      p_bus_ack_i     => golden.ack,      -- bus transfer acknowledge
      p_bus_err_i     => golden.err       -- bus transfer error
    );



    -- Golden Model Memory -----------------------------------------------------
    -- -------------------------------------------------------------------------
    np_golden_read : process
        variable v_dat : std_logic_vector(31 downto 0);
    begin
        wait until rising_edge(clk) and golden.ren = '1';
        v_dat := read_word(memory_golden, to_integer(unsigned(golden.addr(ADDR_WIDTH-1 downto 0))), 4);
        golden.rdat <= v_dat;
    end process;

    np_golden_write : process
    begin
        wait until rising_edge(clk) and golden.wen = '1';
        if (golden.ben(0)) then 
            write_word(memory_golden, to_integer(unsigned(golden.addr(ADDR_WIDTH-1 downto 0)) + 0), golden.wdat(7 downto 0));
        end if; 
        if (golden.ben(1)) then 
            write_word(memory_golden, to_integer(unsigned(golden.addr(ADDR_WIDTH-1 downto 0)) + 1), golden.wdat(15 downto 8));
        end if; 
        if (golden.ben(2)) then 
            write_word(memory_golden, to_integer(unsigned(golden.addr(ADDR_WIDTH-1 downto 0)) + 2), golden.wdat(23 downto 16));
        end if; 
        if (golden.ben(3)) then 
            write_word(memory_golden, to_integer(unsigned(golden.addr(ADDR_WIDTH-1 downto 0)) + 3), golden.wdat(31 downto 24));
        end if; 
    end process;

    sp_golden_ack : process (clk)
    begin
        if rising_edge(clk) then
            if (rst) then 
                golden.ack <= '0'; 
            else 
                if (golden.ren or golden.wen) then
                    golden.ack <= '1';
                else 
                    golden.ack <= '0';
                end if; 
            end if; 
        end if;
    end process;

    golden.err <= '0';


    -- Golden Model Interrupts -------------------------------------------------
    -- -------------------------------------------------------------------------
    neorv.ms_irq  <= '0';
    neorv.me_irq  <= '0';
    neorv.mt_irq  <= '0';
    neorv.db_halt <= '0';
    neorv.mtime   <= x"1234_5678";


end architecture;
