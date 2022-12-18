-- #############################################################################
-- #  -<< RISC-V CPU Package File >>-
-- # ===========================================================================
-- # Copyright 2022, David Gusser
-- # ===========================================================================
-- # File     : rv32_pkg.vhd
-- # Author   : David Gussler - david.gussler@proton.me
-- # Language : VHDL '08
-- # ===========================================================================
-- # 
-- #############################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.gen_utils_pkg.all;


package rv32_pkg is 
    -- =========================================================================
    -- Instruction Decoding ====================================================
    -- =========================================================================

    -- Core
    subtype RANGE_OPCODE  is natural range 6  downto 0;
    subtype RANGE_RD      is natural range 11 downto 7;
    subtype RANGE_FUNCT3  is natural range 14 downto 12;
    subtype RANGE_RS1     is natural range 19 downto 15;
    subtype RANGE_RS2     is natural range 24 downto 20;
    subtype RANGE_FUNCT7  is natural range 31 downto 25;
    subtype RANGE_IMM_I   is natural range 31 downto 20;
    subtype RANGE_IMM_U   is natural range 31 downto 12;
    subtype RANGE_SHAMT_I is natural range 24 downto 20;
    --
    -- S-type immediates
    subtype RANGE_IMM_S_11_5 is natural range 31 downto 25;
    subtype RANGE_IMM_S_4_0  is natural range 11  downto 7;
    --
    -- B-type immedaites
    constant RANGE_IMM_B_12    : natural := 31;
    constant RANGE_IMM_B_11    : natural := 7;
    subtype  RANGE_IMM_B_10_5 is natural range 30 downto 25;
    subtype  RANGE_IMM_B_4_1  is natural range 11  downto 8;
    --
    -- J-type immedaites
    constant RANGE_IMM_J_20     : natural := 31; 
    subtype  RANGE_IMM_J_19_12 is natural range 19 downto 12;
    constant RANGE_IMM_J_11     : natural := 20;
    subtype  RANGE_IMM_J_10_1  is natural range 30  downto 21;
    
 
    -- Opcodes -----------------------------------------------------------------
    -- -------------------------------------------------------------------------
    -- Integer ALU
    constant OPCODE_LUI    : std_logic_vector(6 downto 0) := "0110111";
    constant OPCODE_AUIPC  : std_logic_vector(6 downto 0) := "0010111";
    constant OPCODE_ALUI   : std_logic_vector(6 downto 0) := "0010011";
    constant OPCODE_ALUR   : std_logic_vector(6 downto 0) := "0110011";
    --
    -- Control Flow
    constant OPCODE_JAL    : std_logic_vector(6 downto 0) := "1101111";
    constant OPCODE_JALR   : std_logic_vector(6 downto 0) := "1100111";
    constant OPCODE_BRANCH : std_logic_vector(6 downto 0) := "1100011";
    --
    -- Memory Access
    constant OPCODE_LOAD   : std_logic_vector(6 downto 0) := "0000011";
    constant OPCODE_STORE  : std_logic_vector(6 downto 0) := "0100011";
    --
    -- System & CSR Access
    constant OPCODE_FENCE  : std_logic_vector(6 downto 0) := "0001111";
    constant OPCODE_SYSTEM : std_logic_vector(6 downto 0) := "1110011";
    --
    -- Atomic Memory Access - not implementing this yet 
    constant OPCODE_AMO    : std_logic_vector(6 downto 0) := "0101111";
    --
    -- Multiply / Divide - not implementing this yet 
    constant OPCODE_MUL    : std_logic_vector(6 downto 0) := "0110011";
    --
    -- Floating Point - not implementing this yet 
    constant OPCODE_FOP    : std_logic_vector(6 downto 0) := "1010011";


    -- Funct3 ------------------------------------------------------------------
    -- -------------------------------------------------------------------------
    -- OPCODE_JALR
    constant F3_JALR   : std_logic_vector(2 downto 0) := "000"; -- jump and link register
    --
    -- OPCODE_BRANCH
    constant F3_BEQ    : std_logic_vector(2 downto 0) := "000"; -- branch if equal
    constant F3_BNE    : std_logic_vector(2 downto 0) := "001"; -- branch if not equal
    constant F3_BLT    : std_logic_vector(2 downto 0) := "100"; -- branch if less than
    constant F3_BGE    : std_logic_vector(2 downto 0) := "101"; -- branch if greater than or equal
    constant F3_BLTU   : std_logic_vector(2 downto 0) := "110"; -- branch if less than (unsigned)
    constant F3_BGEU   : std_logic_vector(2 downto 0) := "111"; -- branch if greater than or equal (unsigned)
    --
    -- OPCODE_LOAD
    constant F3_LB     : std_logic_vector(2 downto 0) := "000"; -- load byte
    constant F3_LH     : std_logic_vector(2 downto 0) := "001"; -- load half word
    constant F3_LW     : std_logic_vector(2 downto 0) := "010"; -- load word
    constant F3_LBU    : std_logic_vector(2 downto 0) := "100"; -- load byte (unsigned)
    constant F3_LHU    : std_logic_vector(2 downto 0) := "101"; -- load half word (unsigned)
    --
    -- OPCODE_STORE
    constant F3_SB     : std_logic_vector(2 downto 0) := "000"; -- store byte
    constant F3_SH     : std_logic_vector(2 downto 0) := "001"; -- store half word
    constant F3_SW     : std_logic_vector(2 downto 0) := "010"; -- store word
    --
    -- OPCODE_ALUI & OPCODE_ALUR
    constant F3_SUBADD : std_logic_vector(2 downto 0) := "000"; -- sub/add via funct7
    constant F3_SLL    : std_logic_vector(2 downto 0) := "001"; -- shift logical left
    constant F3_SLT    : std_logic_vector(2 downto 0) := "010"; -- set on less than
    constant F3_SLTU   : std_logic_vector(2 downto 0) := "011"; -- set on less than unsigned
    constant F3_XOR    : std_logic_vector(2 downto 0) := "100"; -- xor
    constant F3_SR     : std_logic_vector(2 downto 0) := "101"; -- shift right via funct7 / imm_i
    constant F3_OR     : std_logic_vector(2 downto 0) := "110"; -- or
    constant F3_AND    : std_logic_vector(2 downto 0) := "111"; -- and
    --
    -- OPCODE_SYSTEM
    constant F3_ENV    : std_logic_vector(2 downto 0) := "000"; -- ecall, ebreak, mret, wfi, ... (via imm12)
    constant F3_CSRRW  : std_logic_vector(2 downto 0) := "001"; -- csr r/w
    constant F3_CSRRS  : std_logic_vector(2 downto 0) := "010"; -- csr read & set bit
    constant F3_CSRRC  : std_logic_vector(2 downto 0) := "011"; -- csr read & clear bit
    constant F3_CSRRWI : std_logic_vector(2 downto 0) := "101"; -- csr r/w immediate
    constant F3_CSRRSI : std_logic_vector(2 downto 0) := "110"; -- csr read & set bit immediate
    constant F3_CSRRCI : std_logic_vector(2 downto 0) := "111"; -- csr read & clear bit immediate
    --
    -- OPCODE_FENCE --
    constant F3_FENCE  : std_logic_vector(2 downto 0) := "000"; -- RV32I - fence - order IO/memory access (->NOP)
    constant F3_FENCEI : std_logic_vector(2 downto 0) := "001"; -- Zifencei --fencei - instruction stream sync
 
    -- TODO: here ...
    -- Funct12 -----------------------------------------------------------------
    -- -------------------------------------------------------------------------
    -- OPCODE_SYSTEM: F3_ENV
    constant F12_ECALL  : std_logic_vector(11 downto 0) := x"000"; -- ECALL
    constant F12_EBREAK : std_logic_vector(11 downto 0) := x"001"; -- EBREAK
    constant F12_MRET   : std_logic_vector(11 downto 0) := x"302"; -- MRET   trap retire 
    constant F12_WFI    : std_logic_vector(11 downto 0) := x"105"; -- WFI    wait for interrupt (go to sleep)
    -- 
    -- OPCODE_JALR
    constant F12_JALR : std_logic_vector(11 downto 0) := x"000"; 
 

    -- Funct7  -----------------------------------------------------------------
    -- -------------------------------------------------------------------------
    constant F7_ZERO : std_logic_vector(6 downto 0) := "0000000"; -- shift right / left logical and add
    constant F7_32   : std_logic_vector(6 downto 0) := "0100000"; -- shift right arithmetic and sub
    constant F7_ONE  : std_logic_vector(6 downto 0) := "0000001"; -- multiply extention 
 
 
    -- Funct5 ------------------------------------------------------------------
    -- -------------------------------------------------------------------------
    -- OPCODE_ATOMIC
    constant F5_A_LR : std_logic_vector(4 downto 0) := "00010"; -- LR
    constant F5_A_SC : std_logic_vector(4 downto 0) := "00011"; -- SC
    -- ... TODO: here

 



    -- =========================================================================
    -- CSRs ====================================================================
    -- =========================================================================

    -- Addresses ---------------------------------------------------------------
    -- -------------------------------------------------------------------------
    -- Unprivileged Floating-Point CSRs (URW)
    constant CSR_FFLAGS   : std_logic_vector(11 downto 0) := X"001"; -- Floating-Point Accrued Exceptions
    constant CSR_FRM      : std_logic_vector(11 downto 0) := X"002"; -- Floating-Point Dynamic Rounding Mode
    constant CSR_FCSR     : std_logic_vector(11 downto 0) := X"003"; -- Floating-Point Control and Status Register (frm + fflags).
    --
    -- Unprivileged Counters/Timers (URO)
    constant CSR_CYCLE    : std_logic_vector(11 downto 0) := X"C00"; -- Cycle counter for RDCYCLE instruction
    constant CSR_TIME     : std_logic_vector(11 downto 0) := X"C01"; -- Timer for RDTIME instruction
    constant CSR_INSTRET  : std_logic_vector(11 downto 0) := X"C02"; -- Instructions-retired counter for RDINSTRET instruction
    constant CSR_CYCLEH   : std_logic_vector(11 downto 0) := X"C80"; -- Upper 32 bits of cycle; RV32 only
    constant CSR_TIMEH    : std_logic_vector(11 downto 0) := X"C81"; -- Upper 32 bits of time; RV32 only
    constant CSR_INSTRETH : std_logic_vector(11 downto 0) := X"C82"; -- Upper 32 bits of instret; RV32 only
    --
    -- Machine Information Registers (MRO)
    constant CSR_MVENDID      : std_logic_vector(11 downto 0) := X"F11"; -- Vendor ID
    constant CSR_MARCHID      : std_logic_vector(11 downto 0) := X"F12"; -- Architecture ID
    constant CSR_MIMPID       : std_logic_vector(11 downto 0) := X"F13"; -- Implementation ID
    constant CSR_MHARTID      : std_logic_vector(11 downto 0) := X"F14"; -- Hart (Hardware execution thread) ID
    constant CSR_MCONFIGPTR   : std_logic_vector(11 downto 0) := X"F15"; -- Pointer to configuration data structure
    --
    -- Machine Trap Setup (MRW)
    constant CSR_MSTATUS      : std_logic_vector(11 downto 0) := X"300"; -- Machine status register
    constant CSR_MISA         : std_logic_vector(11 downto 0) := X"301"; -- ISA and extensions
    constant CSR_MEDELEG      : std_logic_vector(11 downto 0) := X"302"; -- Machine exception delegation register
    constant CSR_MIDELEG      : std_logic_vector(11 downto 0) := X"303"; -- Machine interrupt delegation register
    constant CSR_MIE          : std_logic_vector(11 downto 0) := X"304"; -- Machine interrupt enable register
    constant CSR_MTVEC        : std_logic_vector(11 downto 0) := X"305"; -- Machine trap handler base address 
    constant CSR_MCOUNTEREN   : std_logic_vector(11 downto 0) := X"306"; -- Machine counter enable
    constant CSR_MSTATUSH     : std_logic_vector(11 downto 0) := X"310"; -- Upper 32 bits of mstatus; RV32 only
    --
    -- Machine Trap Handling (MRW)
    constant CSR_MSCRATCH     : std_logic_vector(11 downto 0) := X"340"; -- Scratch register for machine trap handlers
    constant CSR_MEPC         : std_logic_vector(11 downto 0) := X"341"; -- Machine exception program counter 
    constant CSR_MCAUSE       : std_logic_vector(11 downto 0) := X"342"; -- Machine trap cause
    constant CSR_MTVAL        : std_logic_vector(11 downto 0) := X"343"; -- Machine bad address or instruction
    constant CSR_MIP          : std_logic_vector(11 downto 0) := X"344"; -- Machine interrupt pending
    constant CSR_MTINST       : std_logic_vector(11 downto 0) := X"34A"; -- Machine bad trap instruction (transformed)
    constant CSR_MTVAL2       : std_logic_vector(11 downto 0) := X"34B"; -- Machine bad guest physical address 
    --
    -- Machine Configuration (MRW)
    constant CSR_MENVCFG      : std_logic_vector(11 downto 0) := X"30A"; -- Machine environment configuration register
    constant CSR_MENVCFGH     : std_logic_vector(11 downto 0) := X"31A"; -- Upper 32 bits of menvcfg; RV32 only 
    constant CSR_MSECCFG      : std_logic_vector(11 downto 0) := X"747"; -- Machine security configuration register 
    constant CSR_MSECCFGH     : std_logic_vector(11 downto 0) := X"757"; -- Upper 32 bits of mseccfg; RV32 only 
    --
    -- Machine Memory Protection
    -- Unused (for now)
    --
    -- Machine Counters/Timers (MRW)
    constant CSR_MCYCLE    : std_logic_vector(11 downto 0) := X"B00"; -- Machine cycle counter
    constant CSR_MINSTRET  : std_logic_vector(11 downto 0) := X"B02"; -- Machine instructions-retired counter
    constant CSR_MCYCLEH   : std_logic_vector(11 downto 0) := X"B80"; -- Upper 32 bits of mcycle; RV32 only
    constant CSR_MINSTRETH : std_logic_vector(11 downto 0) := X"B82"; -- Upper 32 bits of minstret; RV32 only
    --
    -- Machine Counter Setup (MRW)
    constant CSR_MCOUNTINHIBIT : std_logic_vector(11 downto 0) := X"320";
    --
    -- Debug/Trace Registers (Shared with Debug Mode) (MRW)
    constant CSR_TSELECT       : std_logic_vector(11 downto 0) := X"7A0"; -- Debug/Trace register select
    constant CSR_TDATA1        : std_logic_vector(11 downto 0) := X"7A1"; -- First Debug/Trace triger data register
    constant CSR_TDATA2        : std_logic_vector(11 downto 0) := X"7A2"; -- Second Debug/Trace triger data register
    constant CSR_TDATA3        : std_logic_vector(11 downto 0) := X"7A3"; -- Third Debug/Trace triger data register
    constant CSR_MCONTEXT      : std_logic_vector(11 downto 0) := X"7A8"; -- Machine-mode context register
    --
    -- Debug Mode Registers (DRW)
    constant CSR_DCSR          : std_logic_vector(11 downto 0) := X"7B0"; -- Debug control and status register
    constant CSR_DPC           : std_logic_vector(11 downto 0) := X"7B1"; -- Debug PC (program counter)
    constant CSR_DSCRATCH0     : std_logic_vector(11 downto 0) := X"7B2"; -- Debug scratch register 0
    constant CSR_DSCRATCH1     : std_logic_vector(11 downto 0) := X"7B3"; -- Debug scratch register 1
 

    -- Fields ------------------------------------------------------------------
    -- -------------------------------------------------------------------------
    -- CSR_MSTATUS
    constant MIE  : natural    := 3; 
    constant MPIE : natural    := 7; 
    subtype  FS  is natural range 14 downto 13;
    constant SD   : natural    := 31; 
    --
    -- CSR_MIE & CSR_MIP
    constant MSI  : natural    := 3; 
    constant MTI  : natural    := 7; 
    constant MEI  : natural    := 11;
    --
    -- CSR_MTVEC
    subtype  MODE is natural range 1 downto 0;
    subtype  BASE is natural range 31 downto 2;
    --
    -- CSR_MCAUSE
    constant INTR :  natural := 31;
    subtype  CODE is natural range 30 downto 0;

    -- Mcause Trap Codes -------------------------------------------------------
    -- -------------------------------------------------------------------------
    constant TRAP_MEI_IRQ  : std_logic_vector(30 downto 0) := std_logic_vector(to_unsigned(11, 31)); -- External Interrupt 
    constant TRAP_MSI_IRQ  : std_logic_vector(30 downto 0) := std_logic_vector(to_unsigned(3 , 31)); -- Software Interrupt
    constant TRAP_MTI_IRQ  : std_logic_vector(30 downto 0) := std_logic_vector(to_unsigned(7 , 31)); -- Timer Interrupt 
    constant TRAP_IMA      : std_logic_vector(30 downto 0) := std_logic_vector(to_unsigned(0 , 31)); -- Instruction Misaligned Address Exception
    constant TRAP_IACC     : std_logic_vector(30 downto 0) := std_logic_vector(to_unsigned(1 , 31)); -- Instruction Access Error Exception
    constant TRAP_ILL_INTR : std_logic_vector(30 downto 0) := std_logic_vector(to_unsigned(2 , 31)); -- Illegal Instruction Exception
    constant TRAP_EBREAK   : std_logic_vector(30 downto 0) := std_logic_vector(to_unsigned(3 , 31)); -- Ebreak Exception
    constant TRAP_LMA      : std_logic_vector(30 downto 0) := std_logic_vector(to_unsigned(4 , 31)); -- Load Misaligned Address Exception
    constant TRAP_LACC     : std_logic_vector(30 downto 0) := std_logic_vector(to_unsigned(5 , 31)); -- Load Access Exception 
    constant TRAP_SMA      : std_logic_vector(30 downto 0) := std_logic_vector(to_unsigned(6 , 31)); -- Store Misaligned Address Exception
    constant TRAP_SACC     : std_logic_vector(30 downto 0) := std_logic_vector(to_unsigned(7 , 31)); -- Store Access Exception
    constant TRAP_MECALL   : std_logic_vector(30 downto 0) := std_logic_vector(to_unsigned(11, 31)); -- Ecall Exception



    -- =========================================================================
    -- CPU Signals =============================================================
    -- =========================================================================
    -- 
    -- Control Unit ------------------------------------------------------------
    -- -------------------------------------------------------------------------
    type ctrl_t is record      
        reg_wr   : std_logic;
        wrb_sel  : std_logic_vector(1 downto 0);
        mem_wr   : std_logic;  
        mem_rd   : std_logic; 
        alu_ctrl : std_logic;
        alua_sel : std_logic_vector(1 downto 0);
        alub_sel : std_logic; 
        jal      : std_logic; 
        jalr     : std_logic;
        branch   : std_logic;
        imm_type : std_logic_vector(2 downto 0);
        sys      : std_logic;
        fence    : std_logic; 
        illegal  : std_logic; 
    end record;

    -- Traps -------------------------------------------------------------------
    -- -------------------------------------------------------------------------
    type trap_t is record      
        ms_irq        : std_logic;
        mt_irq        : std_logic;
        me_irq        : std_logic;
        instr_adr_ma  : std_logic;
        instr_access  : std_logic;
        illeg_instr   : std_logic;
        ecall         : std_logic;
        ebreak        : std_logic;
        store_adr_ma  : std_logic;
        load_adr_ma   : std_logic;
        store_access  : std_logic;
        load_access   : std_logic;
    end record;

    -- CSRs --------------------------------------------------------------------
    -- -------------------------------------------------------------------------
    -- run-time writable by cpu or by software 
    type csr_t is record      
        mstatus_mie  : std_logic; 
        mstatus_mpie : std_logic; 
        mcause_intr  : std_logic; 
        mcause_code  : std_logic_vector(30 downto 0); 
        mie_msi      : std_logic; 
        mie_mti      : std_logic; 
        mie_mei      : std_logic; 
        mip_msi      : std_logic; 
        mip_mti      : std_logic; 
        mip_mei      : std_logic; 
        mepc         : std_logic_vector(31 downto 2);
        mtvec        : std_logic_vector(31 downto 2);  
        mcycle       : std_logic_vector(31 downto 0);  
        minstret     : std_logic_vector(31 downto 0);  
    end record;


    -- pc_c -----------------------------------------
    -- -------------------------------------------------------------------------
    type pc_t is record
        -- Pipelined into next stage 
        pc   : std_logic_vector(31 downto 0);  
        trap : trap_t;


        -- Not pipelined into next stage 
        dly_mip_msi        : std_logic; 
        dly_mip_mti        : std_logic; 
        dly_mip_mei        : std_logic; 
        trap_taken         : std_logic;
        pc_fw_mepc         : std_logic_vector(31 downto 2);  
        pc_fw_mtvec        : std_logic_vector(31 downto 2);  
    end record;

    -- Instruction Fetch Request Stage -----------------------------------------
    -- -------------------------------------------------------------------------
    type f1_t is record
        -- Pipelined into next stage 
        pc   : std_logic_vector(31 downto 0);  
        trap : trap_t;
        iren : std_logic; 
    end record;

    -- Instruction Fetch Response Stage ----------------------------------------
    -- -------------------------------------------------------------------------
    type f2_t is record
        -- Pipelined into next stage 
        pc    : std_logic_vector(31 downto 0);  
        valid : std_logic;
        instr : std_logic_vector(31 downto 0);
        trap  : trap_t;
        asdf : std_logic;
        i_ierror_reg: std_logic;
        i_iack_reg: std_logic;
        i_irdat_reg: std_logic_vector(31 downto 0);

        -- Not pipelined into next stage 
        iren : std_logic; 
    end record;

 
    -- Decode Stage ------------------------------------------------------------
    -- -------------------------------------------------------------------------
    type id_t is record 
        -- Pipelined into next stage 
        pc                 : std_logic_vector(31 downto 0);
        valid       : std_logic; 
        trap : trap_t; 
        ctrl               : ctrl_t;
        rs1_adr            : std_logic_vector(4 downto 0);
        rs2_adr            : std_logic_vector(4 downto 0);
        rdst_adr           : std_logic_vector(4 downto 0);
        rs1_dat            : std_logic_vector(31 downto 0);
        rs2_dat            : std_logic_vector(31 downto 0);
        imm32              : std_logic_vector(31 downto 0);
        funct3             : std_logic_vector(2 downto 0);
        funct7             : std_logic_vector(6 downto 0);
        csr_access         : std_logic; 
        mret               : std_logic; 
        wfi                : std_logic; 

        -- Not pipelined into next stage 
        instr              : std_logic_vector(31 downto 0);
        irdat              : std_logic_vector(31 downto 0);
        last_instr         : std_logic_vector(31 downto 0);
        last_dec_en        : std_logic; 
        regfile            : slv_array_t(0 to 31)(31 downto 0);
        opcode             : std_logic_vector(6 downto 0);
        id_fw_rs1_dat     : std_logic_vector(31 downto 0);
        id_fw_rs2_dat     : std_logic_vector(31 downto 0);
        br_eq              : std_logic; 
        br_ltu             : std_logic; 
        br_lt              : std_logic; 
        branch             : std_logic; 
        br_taken           : std_logic; 
        brt_adr            : std_logic_vector(31 downto 0); 

        fence              : std_logic; 
        fencei             : std_logic; 
    end record;
 
    -- Execute Stage -------------------------------------------------------------
    -- -------------------------------------------------------------------------
    type ex_t is record    
        -- Pipelined into next stage 
        valid       : std_logic;
        pc                 : std_logic_vector(31 downto 0); 
        ctrl               : ctrl_t;
        rs2_adr            : std_logic_vector(4 downto 0);  
        rdst_adr           : std_logic_vector(4 downto 0);  
        rs2_dat            : std_logic_vector(31 downto 0);
        funct3             : std_logic_vector(2 downto 0);
        exe_rslt           : std_logic_vector(31 downto 0);
        csr_access         : std_logic;
        csr_adr            : std_logic_vector(11 downto 0);
        csr_wdata          : std_logic_vector(31 downto 0);
        trap : trap_t;

        -- Not pipelined into next stage 
        any_trap           : std_logic;
        rs1_adr            : std_logic_vector(4 downto 0);  
        alu_rslt           : std_logic_vector(31 downto 0);
        aluop              : std_logic_vector(3 downto 0);
        ex_fw_rs1_dat     : std_logic_vector(31 downto 0);
        ex_fw_rs2_dat     : std_logic_vector(31 downto 0);
        imm32              : std_logic_vector(31 downto 0);
        rs1_dat            : std_logic_vector(31 downto 0);
        funct7             : std_logic_vector(6 downto 0);
        alua_dat           : std_logic_vector(31 downto 0);
        alub_dat           : std_logic_vector(31 downto 0);
        csr_rdata          : std_logic_vector(31 downto 0);
        csr                : csr_t; 
        mret               : std_logic;
        is_rtype           : std_logic;
        wfi                : std_logic; 
        ex_fw_csr_rdat     : std_logic_vector(31 downto 0);

    end record;
 
    -- Memory Request Stage ------------------------------------------------------------
    -- -------------------------------------------------------------------------
    type m1_t is record    
        -- Pipelined into next stage 
        valid       : std_logic;
        pc                 : std_logic_vector(31 downto 0);
        ctrl               : ctrl_t;
        rdst_adr           : std_logic_vector(4 downto 0);
        exe_rslt           : std_logic_vector(31 downto 0);
        csr_access         : std_logic;
        csr_adr            : std_logic_vector(11 downto 0);
        csr_wdata          : std_logic_vector(31 downto 0);
        trap               : trap_t;
        m1_fw_rs2_dat      : std_logic_vector(31 downto 0);
        
        -- Not pipelined into next stage 
        rs2_dat            : std_logic_vector(31 downto 0);
        funct3             : std_logic_vector(2 downto 0); 
        rs2_adr            : std_logic_vector(4 downto 0); 
    end record;

    -- Memory Response Stage ------------------------------------------------------------
    -- -------------------------------------------------------------------------
    type m2_t is record    
        -- Pipelined into next stage 
        valid       : std_logic;
        pc                 : std_logic_vector(31 downto 0);
        ctrl               : ctrl_t;
        rdst_adr           : std_logic_vector(4 downto 0);
        exe_rslt           : std_logic_vector(31 downto 0);
        csr_access         : std_logic;
        csr_adr            : std_logic_vector(11 downto 0);
        csr_wdata          : std_logic_vector(31 downto 0);
        drdat              : std_logic_vector(31 downto 0);
        trap               : trap_t;
        
        -- Not pipelined into next stage 
        rs2_dat            : std_logic_vector(31 downto 0);
        funct3             : std_logic_vector(2 downto 0); 
        rs2_adr            : std_logic_vector(4 downto 0); 
    end record;

    -- Writeback Stage ---------------------------------------------------------
    -- -------------------------------------------------------------------------
    type wb_t is record   
        valid : std_logic;
        pc4          : std_logic_vector(31 downto 0); 
        ctrl         : ctrl_t;
        rdst_adr     : std_logic_vector(4 downto 0);  
        exe_rslt     : std_logic_vector(31 downto 0); 
        rdst_dat     : std_logic_vector(31 downto 0);  
        memrd_dat    : std_logic_vector(31 downto 0); 
        funct3       : std_logic_vector(2 downto 0); 
        csr_access         : std_logic;
        csr_adr            : std_logic_vector(11 downto 0);
        csr_wdata          : std_logic_vector(31 downto 0);
        drdat              : std_logic_vector(31 downto 0);
    end record;
    
    -- Hazard Unit -------------------------------------------------------------
    -- -------------------------------------------------------------------------
    type hz_t is record         
        -- Hazards 
        id_ex_br_hazard   : std_logic;
        id_ex_jalr_hazard : std_logic;
        id_m1_br_hazard   : std_logic;
        id_m1_jalr_hazard : std_logic;
        id_m2_br_hazard   : std_logic;
        id_m2_jalr_hazard : std_logic;
        ex_m1_csr_hazard  : std_logic;
        ex_m1_alu_hazard  : std_logic;
        ex_m2_csr_hazard  : std_logic;
        ex_m2_alu_hazard  : std_logic;
        ex_m1_ls_hazard   : std_logic;
        imem_hazard       : std_logic;
        dmem_hazard       : std_logic;

        -- Piepline register control signals
        f1_enable : std_logic;
        f2_enable : std_logic;
        id_enable : std_logic;
        ex_enable : std_logic;
        m1_enable : std_logic;
        m2_enable : std_logic;
        wb_enable : std_logic;
        f1_flush  : std_logic;
        f2_flush  : std_logic;
        id_flush  : std_logic;
        ex_flush  : std_logic;
        m1_flush  : std_logic;
        m2_flush  : std_logic;
        wb_flush  : std_logic;
    end record; 

    -- Performance Counters ----------------------------------------------------
    -- -------------------------------------------------------------------------
    type ct_t is record 
        mcycle: std_logic_vector(31 downto 0); 
        minstret: std_logic_vector(31 downto 0); 
    end record; 


    -- Control Signal Enumerations ---------------------------------------------
    -- -------------------------------------------------------------------------
    -- 
    -- mem2reg mux
    constant WRB_SEL_EXE : std_logic_vector(1 downto 0) := "00";
    constant WRB_SEL_MEM : std_logic_vector(1 downto 0) := "01";
    constant WRB_SEL_PC4 : std_logic_vector(1 downto 0) := "10";
    --
    -- alu control ops 
    constant ALU_CTRL_ADD : std_logic := '0';
    constant ALU_CTRL_ALU : std_logic := '1';
    --
    -- alu opcodes
    constant ALUOP_ADD  : std_logic_vector(3 downto 0) := '0' & F3_SUBADD ;
    constant ALUOP_SUB  : std_logic_vector(3 downto 0) := '1' & F3_SUBADD ;
    constant ALUOP_SLL  : std_logic_vector(3 downto 0) := '0' & F3_SLL    ;
    constant ALUOP_SLT  : std_logic_vector(3 downto 0) := '0' & F3_SLT    ;
    constant ALUOP_SLTU : std_logic_vector(3 downto 0) := '0' & F3_SLTU   ;
    constant ALUOP_XOR  : std_logic_vector(3 downto 0) := '0' & F3_XOR    ;
    constant ALUOP_SRL  : std_logic_vector(3 downto 0) := '0' & F3_SR     ;
    constant ALUOP_SRA  : std_logic_vector(3 downto 0) := '1' & F3_SR     ;
    constant ALUOP_OR   : std_logic_vector(3 downto 0) := '0' & F3_OR     ;
    constant ALUOP_AND  : std_logic_vector(3 downto 0) := '0' & F3_AND    ;
    --
    -- alusrca mux
    constant ALU_A_RS1  : std_logic_vector(1 downto 0) := "00";
    constant ALU_A_PC   : std_logic_vector(1 downto 0) := "01";
    constant ALU_A_ZERO : std_logic_vector(1 downto 0) := "10";
    --
    -- alusrcb mux
    constant ALU_B_RS2   : std_logic := '0';
    constant ALU_B_IMM32 : std_logic := '1';
    --
    -- immediate type 
    constant ITYPE : std_logic_vector(2 downto 0) := "000";
    constant STYPE : std_logic_vector(2 downto 0) := "001";
    constant BTYPE : std_logic_vector(2 downto 0) := "010";
    constant UTYPE : std_logic_vector(2 downto 0) := "011";
    constant JTYPE : std_logic_vector(2 downto 0) := "100";
    constant RTYPE : std_logic_vector(2 downto 0) := "101";
    --
    -- Forwarding mux select signals 
    constant NO_FW  : std_logic_vector(1 downto 0) := "00";
    constant M1_FW  : std_logic_vector(1 downto 0) := "01";
    constant M2_FW  : std_logic_vector(1 downto 0) := "01";
    constant WB_FW  : std_logic_vector(1 downto 0) := "11";

    constant NOP_INSTR : std_logic_vector(31 downto 0) := 
            x"000" & b"00000" & b"00000" & F3_SUBADD & OPCODE_ALUI;

end package; 
