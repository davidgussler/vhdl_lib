library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.vc_context;
use work.gen_utils_pkg.all;
use work.rv32_testbench_pkg.all;
library neorv32;
use neorv32.neorv32_package.all;


entity rv32_cpu_tb is
    generic (runner_cfg : string);
end entity;

architecture tb of rv32_cpu_tb is

    -- Simulation Signals / Constants
    constant C_CLK_PERIOD : time := 10 ns; 
    constant C_CLK2Q      : time := 1 ns;

    signal clk            : std_logic := '0';
    signal rst            : std_logic := '1';
    signal rstn           : std_logic := '0';


    -- DUT Constants / Signals 
    constant HART_ID    : std_logic_vector(31 downto 0) := x"0000_0000";
    constant RESET_ADDR : std_logic_vector(31 downto 0) := x"0000_0000";
    constant TRAP_ADDR  : std_logic_vector(31 downto 0) := x"0000_0800";
    
    type cpu_t is record 
        iren     : std_logic; 
        iaddr    : std_logic_vector(31 downto 0);
        fencei   : std_logic; 
        irdat    : std_logic_vector(31 downto 0);
        istall   : std_logic; 
        iack     : std_logic; 
        ierr     : std_logic; 
        dren     : std_logic; 
        dwen     : std_logic; 
        dben     : std_logic_vector(3 downto 0);
        daddr    : std_logic_vector(31 downto 0);
        fence    : std_logic; 
        dwdat    : std_logic_vector(31 downto 0);
        drdat    : std_logic_vector(31 downto 0);
        dstall   : std_logic; 
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
    




    -- CPU Memories 
    constant MEM_DEPTH     : natural := 1024; -- number of 32-bit words
    constant MEM_DEPTH_L2  : natural := clog2(MEM_DEPTH); 
    constant NUM_BYTES     : natural := MEM_DEPTH*4;
    constant ADDR_WIDTH    : natural := MEM_DEPTH_L2+2; 
    constant memory_dut    : memory_t := new_memory;
    constant mem1_buff     : buffer_t := allocate(memory_dut, NUM_BYTES);
    constant memory_golden : memory_t := new_memory;
    constant mem2_buff     : buffer_t := allocate(memory_golden, NUM_BYTES);


    -- Simple test programs
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
        rv_sw (0, 11, 1024+10*4) ,
        rv_sw (0, 12, 1024+11*4) ,

        others => (others=>'0')
    );



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
            if run("test_0") then

                info("Loading i-type test program into memories...");
                mem_init(memory_dut, ITYPE_TEST); 
                mem_init(memory_golden, ITYPE_TEST); 

                info("Resetting DUT and model...");
                wait until rising_edge(clk);
                
                info("Runing test program...");
                rst <= '1', '0' after 16 * C_CLK_PERIOD;
                wait for 500 * C_CLK_PERIOD;

                info("Checking results...");
                --mem_check(memory_dut, memory_golden);
                mem_print(memory_golden);
            end if;
        end loop;

        test_runner_cleanup(runner);
    end process;



    -- TB Signals --------------------------------------------------------------
    -- -------------------------------------------------------------------------
    clk  <= not clk after C_CLK_PERIOD / 2;
    rstn <= not rst;





    -- =========================================================================
    -- DUT =====================================================================
    -- =========================================================================
    u_dut_cpu : entity work.rv32_cpu
    generic map (
        G_HART_ID    => HART_ID,
        G_RESET_ADDR => RESET_ADDR,
        G_TRAP_ADDR  => TRAP_ADDR
    )
    port map (
        -- Clock & Reset
        i_clk       => clk,
        i_rst       => rst,
        
        -- Instruction  Interface 
        o_iren      => dut.iren  ,
        o_iaddr     => dut.iaddr ,
        o_fencei    => dut.fencei,
        i_irdat     => dut.irdat ,
        i_istall    => dut.istall,
        i_ierror    => dut.ierr,

        -- Data Interface 
        o_dren      => dut.dren  ,
        o_dwen      => dut.dwen  ,
        o_dben      => dut.dben  ,
        o_daddr     => dut.daddr ,
        o_fence     => dut.fence,
        o_dwdat     => dut.dwdat ,
        i_drdat     => dut.drdat ,
        i_dstall    => dut.dstall,
        i_derror    => dut.derr,

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
    np_iread : process
        variable v_dat : std_logic_vector(31 downto 0);
    begin
        wait until rising_edge(clk) and dut.iren = '1';
        v_dat := read_word(memory_dut, to_integer(unsigned(dut.iaddr(ADDR_WIDTH-1 downto 0))), 4);
        dut.irdat <= v_dat;
    end process;

    np_dread : process
        variable v_dat : std_logic_vector(31 downto 0);
    begin
        wait until rising_edge(clk) and dut.dren = '1';
        v_dat := read_word(memory_dut, to_integer(unsigned(dut.daddr(ADDR_WIDTH-1 downto 0))), 4);
        dut.drdat <= v_dat;
    end process;

    np_dwrite : process
    begin
        wait until rising_edge(clk) and dut.dwen = '1';
        if (dut.dben(0)) then 
            write_word(memory_dut, to_integer(unsigned(dut.daddr(ADDR_WIDTH-1 downto 0)) + 0), dut.dwdat(7 downto 0));
        end if; 
        if (dut.dben(1)) then 
            write_word(memory_dut, to_integer(unsigned(dut.daddr(ADDR_WIDTH-1 downto 0)) + 1), dut.dwdat(15 downto 8));
        end if; 
        if (dut.dben(2)) then 
            write_word(memory_dut, to_integer(unsigned(dut.daddr(ADDR_WIDTH-1 downto 0)) + 2), dut.dwdat(23 downto 16));
        end if; 
        if (dut.dben(3)) then 
            write_word(memory_dut, to_integer(unsigned(dut.daddr(ADDR_WIDTH-1 downto 0)) + 3), dut.dwdat(31 downto 24));
        end if; 
    end process;

    dut.istall <= '0';
    dut.ierr   <= '0';
    dut.dstall <= '0';
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
        CPU_DEBUG_ADDR               => RESET_ADDR,                    -- cpu debug mode start address
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
    np_golden_iread : process
        variable v_dat : std_logic_vector(31 downto 0);
    begin
        wait until rising_edge(clk) and neorv.iren = '1';
        v_dat := read_word(memory_golden, to_integer(unsigned(neorv.iaddr(ADDR_WIDTH-1 downto 0))), 4);
        neorv.irdat <= v_dat;
    end process;

    np_golden_dread : process
        variable v_dat : std_logic_vector(31 downto 0);
    begin
        wait until rising_edge(clk) and neorv.dren = '1';
        v_dat := read_word(memory_golden, to_integer(unsigned(neorv.daddr(ADDR_WIDTH-1 downto 0))), 4);
        neorv.drdat <= v_dat;
    end process;

    np_golden_dwrite : process
    begin
        wait until rising_edge(clk) and neorv.dwen = '1';
        if (neorv.dben(0)) then 
            write_word(memory_golden, to_integer(unsigned(neorv.daddr(ADDR_WIDTH-1 downto 0)) + 0), neorv.dwdat(7 downto 0));
        end if; 
        if (neorv.dben(1)) then 
            write_word(memory_golden, to_integer(unsigned(neorv.daddr(ADDR_WIDTH-1 downto 0)) + 1), neorv.dwdat(15 downto 8));
        end if; 
        if (neorv.dben(2)) then 
            write_word(memory_golden, to_integer(unsigned(neorv.daddr(ADDR_WIDTH-1 downto 0)) + 2), neorv.dwdat(23 downto 16));
        end if; 
        if (neorv.dben(3)) then 
            write_word(memory_golden, to_integer(unsigned(neorv.daddr(ADDR_WIDTH-1 downto 0)) + 3), neorv.dwdat(31 downto 24));
        end if; 
    end process;

    sp_golden_ack : process (clk)
    begin
        if rising_edge(clk) then
            if (rst) then
                neorv.iack <= '0'; 
                neorv.dack <= '0'; 
            else 
                if (neorv.iren) then
                    neorv.iack <= '1';
                else 
                    neorv.iack <= '0';
                end if; 

                if (neorv.dren) then
                    neorv.dack <= '1';
                else 
                    neorv.dack <= '0';
                end if; 
            end if; 
        end if;
    end process;

    neorv.ierr <= '0';
    neorv.derr <= '0';


    -- Golden Model Interrupts -------------------------------------------------
    -- -------------------------------------------------------------------------
    neorv.ms_irq  <= '0';
    neorv.me_irq  <= '0';
    neorv.mt_irq  <= '0';
    neorv.db_halt <= '0';
    neorv.mtime   <= x"1234_5678";


end architecture;
