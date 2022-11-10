-- ###############################################################################################
-- # << RV32 CPU Package File>> #
-- *********************************************************************************************** 
-- Copyright 2022
-- *********************************************************************************************** 
-- File     : rv32_pkg.vhd
-- Author   : David Gussler - davidnguss@gmail.com 
-- Language : VHDL '08
-- History  :  Date      | Version | Comments 
--            --------------------------------
--            01-01-2021 | 1.0     | Initial 
-- *********************************************************************************************** 
-- Description : 
--   Useful description describing the description to describe the module

-- ###############################################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.gen_utils_pkg.all;


package rv32_pkg is 
   
    -- Instruction Decoding -------------------------------------------------------------------------
    -- ----------------------------------------------------------------------------------------------
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
    
 
    -- Opcodes --------------------------------------------------------------------------------------
    -- ----------------------------------------------------------------------------------------------
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
    
    -- Funct3 ---------------------------------------------------------------------------------------
    -- ----------------------------------------------------------------------------------------------
    -- OPCODE_JALR
    constant F3_JALR     : std_logic_vector(2 downto 0) := "000"; -- jump and link register
 
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
    -- OPCODE_ALUI and OPCODE_ALUR
    constant F3_SUBADD : std_logic_vector(2 downto 0) := "000"; -- sub/add via funct7
    constant F3_SLL    : std_logic_vector(2 downto 0) := "001"; -- shift logical left
    constant F3_SLT    : std_logic_vector(2 downto 0) := "010"; -- set on less than
    constant F3_SLTU   : std_logic_vector(2 downto 0) := "011"; -- set on less than unsigned
    constant F3_XOR    : std_logic_vector(2 downto 0) := "100"; -- xor
    constant F3_SR     : std_logic_vector(2 downto 0) := "101"; -- shift right via funct7 / imm_i
    constant F3_OR     : std_logic_vector(2 downto 0) := "110"; -- or
    constant F3_AND    : std_logic_vector(2 downto 0) := "111"; -- and
    --
    -- OPCODE_SYSTEM --
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
 
 
    -- TODO: Here downto ...
    -- Immediate i-type -------------------------------------------------
    -- -------------------------------------------------------------------------------------------
    -- system F3_ENV --
    constant IMM_I_ECALL  : std_logic_vector(11 downto 0) := x"000"; -- ECALL
    constant IMM_I_EBREAK : std_logic_vector(11 downto 0) := x"001"; -- EBREAK
    constant IMM_I_MRET   : std_logic_vector(11 downto 0) := x"302"; -- MRET  idk this one 
    constant IMM_I_WFI    : std_logic_vector(11 downto 0) := x"105"; -- WFI   idk this one 
    constant IMM_I_DRET   : std_logic_vector(11 downto 0) := x"7b2"; -- DRET  idk this one
    -- OPCODE_JALR - 
    constant IMM_I_JALR : std_logic_vector(11 downto 0) := x"000"; -- ECALL
 
    -- Funct7  ----------------------------------------------------------------------------
    -- -------------------------------------------------------------------------------------------
    constant F7_ZERO : std_logic_vector(6 downto 0) := "0000000"; -- shift right / left logical and add
    constant F7_32   : std_logic_vector(6 downto 0) := "0100000"; -- shift right arithmetic and sub
    constant F7_ONE  : std_logic_vector(6 downto 0) := "0000001"; -- multiply extention 
 
 
 
    -- Funct5 --------------------------------------------------------------------------
    -- -------------------------------------------------------------------------------------------
    -- atomic operations  OPCODE_ATOMIC --
    constant F5_A_LR : std_logic_vector(4 downto 0) := "00010"; -- LR
    constant F5_A_SC : std_logic_vector(4 downto 0) := "00011"; -- SC
    -- ... TODO: here
    
    -- ALU OPCODES
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
 
 
    
    -- RISC-V standard CSR addresses --------------------------------------------
    -- --------------------------------------------------------------------------
    -- Unprivileged Floating-Point CSRs (URW)
    constant CSR_FFLAGS   : std_logic_vector(11 downto 0) := X"001"; -- Floating-Point Accrued Exceptions
    constant CSR_FRM      : std_logic_vector(11 downto 0) := X"002"; -- Floating-Point Dynamic Rounding Mode
    constant CSR_FCSR     : std_logic_vector(11 downto 0) := X"003"; -- Floating-Point Control and Status Register (frm + fflags).
 
    -- Unprivileged Counters/Timers (URO)
    constant CSR_CYCLE    : std_logic_vector(11 downto 0) := X"C00"; -- Cycle counter for RDCYCLE instruction
    constant CSR_TIME     : std_logic_vector(11 downto 0) := X"C01"; -- Timer for RDTIME instruction
    constant CSR_INSTRET  : std_logic_vector(11 downto 0) := X"C02"; -- Instructions-retired counter for RDINSTRET instruction
    constant CSR_CYCLEH   : std_logic_vector(11 downto 0) := X"C80"; -- Upper 32 bits of cycle; RV32 only
    constant CSR_TIMEH    : std_logic_vector(11 downto 0) := X"C81"; -- Upper 32 bits of time; RV32 only
    constant CSR_INSTRETH : std_logic_vector(11 downto 0) := X"C82"; -- Upper 32 bits of instret; RV32 only
 
    -- Machine Information Registers (MRO)
    constant CSR_MVENDID      : std_logic_vector(11 downto 0) := X"F11"; -- Vendor ID
    constant CSR_MARCHID      : std_logic_vector(11 downto 0) := X"F12"; -- Architecture ID
    constant CSR_MIMPID       : std_logic_vector(11 downto 0) := X"F13"; -- Implementation ID
    constant CSR_MHARTID      : std_logic_vector(11 downto 0) := X"F14"; -- Hart (Hardware execution thread) ID
    constant CSR_MCONFIGPTR   : std_logic_vector(11 downto 0) := X"F15"; -- Pointer to configuration data structure
 
    -- Machine Trap Setup (MRW)
    constant CSR_MSTATUS      : std_logic_vector(11 downto 0) := X"300"; -- Machine status register
    constant CSR_MISA         : std_logic_vector(11 downto 0) := X"301"; -- ISA and extensions
    constant CSR_MEDELEG      : std_logic_vector(11 downto 0) := X"302"; -- Machine exception delegation register
    constant CSR_MIDELEG      : std_logic_vector(11 downto 0) := X"303"; -- Machine interrupt delegation register
    constant CSR_MIE          : std_logic_vector(11 downto 0) := X"304"; -- Machine interrupt enable register
    constant CSR_MTVEC        : std_logic_vector(11 downto 0) := X"305"; -- Machine trap handler base address 
    constant CSR_MCOUNTEREN   : std_logic_vector(11 downto 0) := X"306"; -- Machine counter enable
    constant CSR_MSTATUSH     : std_logic_vector(11 downto 0) := X"310"; -- Upper 32 bits of mstatus; RV32 only
 
    -- Machine Trap Handling (MRW)
    constant CSR_MSCRATCH     : std_logic_vector(11 downto 0) := X"340"; -- Scratch register for machine trap handlers
    constant CSR_MEPC         : std_logic_vector(11 downto 0) := X"341"; -- Machine exception program counter 
    constant CSR_MCAUSE       : std_logic_vector(11 downto 0) := X"342"; -- Machine trap cause
    constant CSR_MTVAL        : std_logic_vector(11 downto 0) := X"343"; -- Machine bad address or instruction
    constant CSR_MIP          : std_logic_vector(11 downto 0) := X"344"; -- Machine interrupt pending
    constant CSR_MTINST       : std_logic_vector(11 downto 0) := X"34A"; -- Machine bad trap instruction (transformed)
    constant CSR_MTVAL2       : std_logic_vector(11 downto 0) := X"34B"; -- Machine bad guest physical address 
 
    -- Machine Configuration (MRW)
    constant CSR_MENVCFG      : std_logic_vector(11 downto 0) := X"30A"; -- Machine environment configuration register
    constant CSR_MENVCFGH     : std_logic_vector(11 downto 0) := X"31A"; -- Upper 32 bits of menvcfg; RV32 only 
    constant CSR_MSECCFG      : std_logic_vector(11 downto 0) := X"747"; -- Machine security configuration register 
    constant CSR_MSECCFGH     : std_logic_vector(11 downto 0) := X"757"; -- Upper 32 bits of mseccfg; RV32 only 
 
    -- Machine Memory Protection
    -- Unused (for now)
    
    -- Machine Counters/Timers (MRW)
    constant CSR_MCYCLE    : std_logic_vector(11 downto 0) := X"B00"; -- Machine cycle counter
    constant CSR_MINSTRET  : std_logic_vector(11 downto 0) := X"B02"; -- Machine instructions-retired counter
    constant CSR_MCYCLEH   : std_logic_vector(11 downto 0) := X"B80"; -- Upper 32 bits of mcycle; RV32 only
    constant CSR_MINSTRETH : std_logic_vector(11 downto 0) := X"B82"; -- Upper 32 bits of minstret; RV32 only
 
    -- Machine Counter Setup (MRW)
    -- Unused (for now)
    
    -- Debug/Trace Registers (Shared with Debug Mode) (MRW)
    constant CSR_TSELECT       : std_logic_vector(11 downto 0) := X"7A0"; -- Debug/Trace register select
    constant CSR_TDATA1        : std_logic_vector(11 downto 0) := X"7A1"; -- First Debug/Trace triger data register
    constant CSR_TDATA2        : std_logic_vector(11 downto 0) := X"7A2"; -- Second Debug/Trace triger data register
    constant CSR_TDATA3        : std_logic_vector(11 downto 0) := X"7A3"; -- Third Debug/Trace triger data register
    constant CSR_MCONTEXT      : std_logic_vector(11 downto 0) := X"7A8"; -- Machine-mode context register
 
    -- Debug Mode Registers (DRW)
    constant CSR_DCSR          : std_logic_vector(11 downto 0) := X"7B0"; -- Debug control and status register
    constant CSR_DPC           : std_logic_vector(11 downto 0) := X"7B1"; -- Debug PC (program counter)
    constant CSR_DSCRATCH0     : std_logic_vector(11 downto 0) := X"7B2"; -- Debug scratch register 0
    constant CSR_DSCRATCH1     : std_logic_vector(11 downto 0) := X"7B3"; -- Debug scratch register 1
 
 
 
 
 
    
    -- control signals
    type ctrl_t is record      
        reg_wr   : std_logic;
        wrb_sel  : std_logic_vector(1 downto 0); -- memout, pc4, or aluout mux in wb stage
        mem_wr   : std_logic;   -- 1=read, 0=write
        mem_rd   : std_logic; 
        jalr     : std_logic;
        branch   : std_logic;
        exe_unit : std_logic_vector(1 downto 0); -- select the execution unit in the execute stage
        alu_ctrl : std_logic;
        alu_a    : std_logic_vector(1 downto 0); -- register, PC, zero
        alu_b    : std_logic; -- register, immediate
        jal      : std_logic; 
        imm_type : std_logic_vector(2 downto 0);
    end record;
 
    -- pipeline phases
    type fet_t is record      
        pc    : std_logic_vector(31 downto 0);  
        pc4   : std_logic_vector(31 downto 0); 
    end record;
 
 
    type dec_t is record 
        opcode : std_logic_vector(6 downto 0);
        rs1_adr: std_logic_vector(4 downto 0);
        rs2_adr: std_logic_vector(4 downto 0);
        rs1_dat: std_logic_vector(4 downto 0);
        rs2_dat: std_logic_vector(4 downto 0);
        rdst_adr : std_logic_vector(4 downto 0);
        funct3 : std_logic_vector(2 downto 0);
        funct7 : std_logic_vector(6 downto 0);
        ctrl    : ctrl_t;
        --pc4   : std_logic_vector(31 downto 0); 
        --pc    : std_logic_vector(31 downto 0);  
        instr : std_logic_vector(31 downto 0);
        regfile : slv_array_t(1 to 31)(31 downto 0);
        imm32 : std_logic_vector(31 downto 0);
    end record;
 
 
    type exe_t is record    
        ctrl   : ctrl_t;
  
        rd    : std_logic_vector(4 downto 0);  
        rs1      : std_logic_vector(4 downto 0);  
        rs2      : std_logic_vector(4 downto 0);  
        pc4      : std_logic_vector(31 downto 0);
        imm32    : std_logic_vector(31 downto 0);
        rs1_dat  : std_logic_vector(31 downto 0);
        rs2_dat  : std_logic_vector(31 downto 0);
        pc       : std_logic_vector(31 downto 0); 
        funct3   : std_logic_vector(2 downto 0);
        funct7   : std_logic_vector(6 downto 0);
 
    end record;
 
 
    type mem_t is record      
        ctrl   : ctrl_t;
 
        rdest : std_logic_vector(4 downto 0);  
        rs1      : std_logic_vector(4 downto 0);  
        rs2      : std_logic_vector(4 downto 0); 
        pc4      : std_logic_vector(31 downto 0);
        exe_rslt : std_logic_vector(31 downto 0); 
        rs2_dat  : std_logic_vector(31 downto 0);
    end record;
 
 
    type wrb_t is record   
        ctrl   : ctrl_t;
 
        rdst_adr  : std_logic_vector(4 downto 0);  
        rdst_dat  : std_logic_vector(31 downto 0);  
        pc4       : std_logic_vector(31 downto 0); 
        memrd_dat : std_logic_vector(31 downto 0); 
        exe_rslt  : std_logic_vector(31 downto 0); 
    end record;
    
    
    type haz_t is record 
        -- Forwarding MUX selects 
        id_fw_a_sel : std_logic_vector(1 downto 0);
        id_fw_b_sel : std_logic_vector(1 downto 0);
        ex_fw_a_sel : std_logic_vector(1 downto 0);
        ex_fw_b_sel : std_logic_vector(1 downto 0);
        wb_to_mem_fw: std_logic;
        -- Hazards 
        pc_stall    : std_logic;
        id_stall  : std_logic;
        ex_stall  : std_logic;
        mem_stall : std_logic;
        wb_stall : std_logic;
        id_flush  : std_logic;
        ex_flush  : std_logic;
        mem_flush : std_logic;
        wb_flush : std_logic;
    end record; 
    
    -- mem2reg mux
    constant WRB_SEL_EXE_RESULT : std_logic_vector(1 downto 0) := "00";
    constant WRB_SEL_MEM        : std_logic_vector(1 downto 0) := "01";
    constant WRB_SEL_PC4        : std_logic_vector(1 downto 0) := "10";
    -- alu control ops 
    constant ALU_CTRL_ADD : std_logic_vector(1 downto 0) := '0';
    constant ALU_CTRL_ALU : std_logic_vector(1 downto 0) := '1';
    -- alusrca mux
    constant ALU_A_RS1  : std_logic_vector(1 downto 0) := "00";
    constant ALU_A_PC   : std_logic_vector(1 downto 0) := "01";
    constant ALU_A_ZERO : std_logic_vector(1 downto 0) := "10";
    -- alusrcb mux
    constant ALU_B_RS2   : std_logic := '0';
    constant ALU_B_IMM32 : std_logic := '1';
    -- pc src mux
    constant PCSRC_PC4 : std_logic := '0';
    -- imm type 
    constant ITYPE : std_logic_vector(2 downto 0) := "000";
    constant STYPE : std_logic_vector(2 downto 0) := "001";
    constant BTYPE : std_logic_vector(2 downto 0) := "010";
    constant UTYPE : std_logic_vector(2 downto 0) := "011";
    constant JTYPE : std_logic_vector(2 downto 0) := "100";
    constant RTYPE : std_logic_vector(2 downto 0) := "101";
    -- execute unit select
    constant INT_ALU_UNIT : std_logic_vector(1 downto 0) := "00";
    constant SYSCSR_UNIT  : std_logic_vector(1 downto 0) := "01";
    constant FP_UNIT  : std_logic_vector(1 downto 0) := "10";
 
 
 
    -- ID Forwarding mux select signals 
    constant ID_TO_ID_FW     : std_logic_vector(1 downto 0) := "00";
    constant WB_TO_ID_FW     : std_logic_vector(1 downto 0) := "01";
    constant MEM_TO_ID_FW    : std_logic_vector(1 downto 0) := "10";
    constant MEM_WB_TO_ID_FW : std_logic_vector(1 downto 0) := "11";
 
    -- EXE Forwarding mux select signals 
    constant EX_TO_EX_FW      : std_logic_vector(1 downto 0) := "00";
    constant WB_TO_EX_FW      : std_logic_vector(1 downto 0) := "01";
    constant MEM_TO_EX_FW     : std_logic_vector(1 downto 0) := "10";
    constant MEM_WB_TO_EX_FW  : std_logic_vector(1 downto 0) := "11";
 
    -- MEM forwarding mux select signals 
    constant MEM_TO_MEM_FW : std_logic := '0';
    constant WB_TO_MEM_FW  : std_logic := '1';
 
 
 
    type t_instr_decode is (
        -- RV32I --
        I_BEQ      ,      
        I_BNE      ,
        I_BLT      ,
        I_BGE      ,
        I_BLTU     ,
        I_BGEU     ,
        I_JALR     ,
        I_JAL      ,
        I_LUI      ,
        I_AUIPC    ,
        I_ADDI     ,
        I_SLLI     ,
        I_SLTI     ,
        I_SLTIU    ,
        I_XORI     ,
        I_SRLI     ,
        I_SRAI     ,
        I_ORI      ,
        I_ANDI     ,
        I_ADD      ,
        I_SUB      ,
        I_SLL      ,
        I_SLT      ,
        I_SLTU     ,
        I_XOR      ,
        I_SRL      ,
        I_SRA      ,
        I_OR       ,
        I_AND      ,
        I_LB       ,
        I_LH       ,
        I_LW       ,
        I_LBU      ,
        I_LHU      ,
        I_SB       ,
        I_SH       ,
        I_SW       ,
        I_FENCE    ,
        Z_FENCE_I  ,
        I_ECALL    ,
        I_EBREAK   ,
        -- RV32M --
        M_MUL      ,
        M_MULH     ,
        M_MULHSU   ,
        M_MULHU    ,
        M_DIV      ,
        M_DIVU     ,
        M_REM      ,
        M_REMU     ,
        -- RVA --
        A_LR_W     ,
        A_SC_W     ,
        A_AMOSWAP_W,
        A_AMOADD_W ,
        A_AMOXOR_W ,
        A_AMOAND_W ,
        A_AMOOR_W  ,
        A_AMOMIN_W ,
        A_AMOMAX_W ,
        A_AMOMINU_W,
        A_AMOMAXU_W,
        -- Zcsri --
        Z_CSRRW    ,
        Z_CSRRS    ,
        Z_CSRRC    ,
        Z_CSRRWI   ,
        Z_CSRRSI   ,
        Z_CSRRCI   ,
        -- RV32F --
        FLW        ,
        FSW        ,
        FMADD_S    ,
        FMSUB_S    ,
        FNMSUB_S   ,
        FNMADD_S   ,
        FADD_S     ,
        FSUB_S     ,
        FMUL_S     ,
        FDIV_S     ,
        FSQRT_S    ,
        FSGNJ_S    ,
        FSGNJN_S   ,
        FSGNJX_S   ,
        FMIN_S     ,
        FMAX_S     ,
        FCVT_WS    ,
        FCVT_WUS   ,
        FMV_XW     ,
        FEQ_S      ,
        FLT_S      ,
        FLE_S      ,
        FCLASS_XW  ,
        FCVT_SW    ,
        FCVT_SWU   ,
        FMV_WX     ,
        -- RV32D --
        FLD        ,
        FSD        ,
        FMADD_D    ,
        FMSUB_D    ,
        FNMSUB_D   ,
        FNMADD_D   ,
        FADD_D     ,
        FSUB_D     ,
        FMUL_D     ,
        FDIV_D     ,
        FSQRT_D    ,
        FSGNJ_D    ,
        FSGNJN_D   ,
        FSGNJX_D   ,
        FMIN_D     ,
        FMAX_D     ,
        FCVT_SD    ,
        FCVT_DS    ,
        FEQ_D      ,
        FLT_D      ,
        FLE_D      ,
        FCLASD_XW  ,
        FCVT_WD    ,
        FCVT_WUD   ,
        FCVT_DW    ,
        FCVT_DWU   ,
  
        ILLEGAL_INSTR
    ); 
 
    type t_debug is record
       op : t_instr_decode; 
    end record t_debug; 








--   -- probs get rid of these 
--   -- types
--   --------------------------------------------------
--   -- r-type instructions (two operand registers)
--   type t_r_instr is record 
--      opcode : std_logic_vector(6 downto 0); -- instr(6 downto 0)
--      rd     : std_logic_vector(4 downto 0); -- instr(11 downto 7)
--      funct3 : std_logic_vector(2 downto 0); -- instr(14 downto 12)
--      rs1    : std_logic_vector(4 downto 0); -- instr(19 downto 15)
--      rs2    : std_logic_vector(4 downto 0); -- instr(20 downto 24)
--      funct7 : std_logic_vector(6 downto 0); -- instr(31 downto 25)
--   end record t_r_instr; 

--   -- i-type instructions (one operand register and one immediate operand)
--   type t_i_instr is record 
--      opcode : std_logic_vector(6  downto 0); -- instr(6 downto 0)
--      rd     : std_logic_vector(4  downto 0); -- instr(11 downto 7)
--      funct3 : std_logic_vector(2  downto 0); -- instr(14 downto 12)
--      rs1    : std_logic_vector(4  downto 0); -- instr(19 downto 15)
--      imm12  : std_logic_vector(11 downto 0); -- instr(31 downto 20)
--   end record t_i_instr; 

--   -- sb-type instructions (conditional branches)
--   type t_sb_instr is record 

--   end record t_sb_instr; 

--   -- u-type instructions (load and add upper immediate) 
--   type t_u_instr is record 
--      opcode : std_logic_vector(6  downto 0); -- instr(6 downto 0)
--      rd     : std_logic_vector(4  downto 0); -- instr(11 downto 7)
--      imm20  : std_logic_vector(19 downto 0); -- instr(31 downto 12)
--   end record t_u_instr; 

--   -- uj-type instructions (unconditional jumps)
--   type t_uj_instr is record 
--      opcode : std_logic_vector(6  downto 0); -- instr(6 downto 0)
--      rd     : std_logic_vector(4  downto 0); -- instr(11 downto 7)
--   end record t_uj_instr; 

end package rv32_pkg; 