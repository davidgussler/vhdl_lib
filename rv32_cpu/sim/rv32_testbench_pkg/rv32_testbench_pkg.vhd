-- #############################################################################
-- #  -<< RISC-V Testbench Utilities >>-
-- # ===========================================================================
-- # File     : rv32_tb_pkg.vhd
-- # Author   : David Gussler - davidnguss@gmail.com 
-- # Language : VHDL '08
-- # History  :  Date      | Version | Comments 
-- #            --------------------------------
-- #            11-03-2022 | 1.0     | Initial 
-- # ===========================================================================
-- # RV32 TB functions
-- #
-- # Important note: 
-- # Offsets are in multiples of 2 bytes for all branchs and jumps
-- # for example jal(1, 8) would jump 8x2 bytes
-- #
-- # Makes use of function overloading to allow the user to feed inputs
-- # as either std_logic_vectors or integers
-- #
-- #############################################################################


-- Libraries -------------------------------------------------------------------
-- -----------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.rv32_pkg.all;


-- Package Header ==============================================================
-- =============================================================================
package rv32_testbench_pkg is
    
    -- Types  ------------------------------------------------------------------
    -- -------------------------------------------------------------------------
    subtype reg_adr_t is std_logic_vector(4 downto 0);
    subtype instr32_t is std_logic_vector(31 downto 0);
    subtype instr16_t is std_logic_vector(15 downto 0);
    subtype imm12_t is std_logic_vector(11 downto 0);
    subtype imm20_t is std_logic_vector(19 downto 0);


    -- Type Conversion Functions -----------------------------------------------
    -- -------------------------------------------------------------------------
    function u5  (int : natural) return std_logic_vector;
    function u12 (int : natural) return std_logic_vector;
    function s12 (int : integer) return std_logic_vector;
    function s20 (int : integer) return std_logic_vector;
        

    -- Instruction Encoding Functions ------------------------------------------
    -- -------------------------------------------------------------------------
    function rv_lui (rd : reg_adr_t; imm20 : imm20_t) return instr32_t; 
    function rv_lui (rd : integer; imm20 : integer) return instr32_t; 

    function rv_auipc (rd : reg_adr_t; imm20 : imm20_t) return instr32_t; 
    function rv_auipc (rd : integer; imm20 : integer) return instr32_t; 

    function rv_jal (rd : reg_adr_t; imm20 : imm20_t) return instr32_t; 
    function rv_jal (rd : integer; imm20 : integer) return instr32_t; 

    function rv_jalr (rd : reg_adr_t; rs1 : reg_adr_t; imm12 : imm12_t) return instr32_t; 
    function rv_jalr (rd : integer; rs1 : integer; imm12 : integer) return instr32_t; 
        
    function rv_beq (rs1 : reg_adr_t; rs2 : reg_adr_t; imm12 : imm12_t)  return instr32_t;
    function rv_beq (rs1 : integer; rs2 : integer; imm12 : integer)  return instr32_t;    

    function rv_bne (rs1 : reg_adr_t; rs2 : reg_adr_t; imm12 : imm12_t) return instr32_t; 
    function rv_bne (rs1 : integer; rs2 : integer; imm12 : integer) return instr32_t; 

    function rv_blt (rs1 : reg_adr_t; rs2 : reg_adr_t; imm12 : imm12_t)  return instr32_t; 
    function rv_blt (rs1 : integer; rs2 : integer; imm12 : integer)  return instr32_t;    

    function rv_bge (rs1 : reg_adr_t; rs2 : reg_adr_t; imm12 : imm12_t) return instr32_t;
    function rv_bge (rs1 : integer; rs2 : integer; imm12 : integer) return instr32_t;

    function rv_bltu (rs1 : reg_adr_t; rs2 : reg_adr_t; imm12 : imm12_t) return instr32_t; 
    function rv_bltu (rs1 : integer; rs2 : integer; imm12 : integer) return instr32_t; 

    function rv_bgeu (rs1 : reg_adr_t; rs2 : reg_adr_t; imm12 : imm12_t) return instr32_t; 
    function rv_bgeu (rs1 : integer; rs2 : integer; imm12 : integer) return instr32_t; 

    function rv_lb (rd : reg_adr_t; rs1 : reg_adr_t; imm12 : imm12_t) return instr32_t; 
    function rv_lb (rd : integer; rs1 : integer; imm12 : integer) return instr32_t; 

    function rv_lh (rd : reg_adr_t; rs1 : reg_adr_t; imm12 : imm12_t) return instr32_t; 
    function rv_lh (rd : integer; rs1 : integer; imm12 : integer) return instr32_t; 

    function rv_lw (rd : reg_adr_t; rs1 : reg_adr_t; imm12 : imm12_t) return instr32_t; 
    function rv_lw (rd : integer; rs1 : integer; imm12 : integer) return instr32_t; 

    function rv_lbu (rd : reg_adr_t; rs1 : reg_adr_t; imm12 : imm12_t) return instr32_t; 
    function rv_lbu (rd : integer; rs1 : integer; imm12 : integer) return instr32_t; 

    function rv_lhu (rd : reg_adr_t; rs1 : reg_adr_t; imm12 : imm12_t) return instr32_t; 
    function rv_lhu (rd : integer; rs1 : integer; imm12 : integer) return instr32_t; 
        
    function rv_sb (rs1 : reg_adr_t; rs2 : reg_adr_t; imm12 : imm12_t) return instr32_t; 
    function rv_sb (rs1 : integer; rs2 : integer; imm12 : integer) return instr32_t; 
        
    function rv_sh (rs1 : reg_adr_t; rs2 : reg_adr_t; imm12 : imm12_t) return instr32_t; 
    function rv_sh (rs1 : integer; rs2 : integer; imm12 : integer) return instr32_t; 

    function rv_sw (rs1 : reg_adr_t; rs2 : reg_adr_t; imm12 : imm12_t) return instr32_t; 
    function rv_sw (rs1 : integer; rs2 : integer; imm12 : integer) return instr32_t; 

    function rv_addi (rd : reg_adr_t; rs1 : reg_adr_t; imm12 : imm12_t) return instr32_t; 
    function rv_addi (rd : integer; rs1 : integer; imm12 : integer) return instr32_t; 

    function rv_slti (rd : reg_adr_t; rs1 : reg_adr_t; imm12 : imm12_t)  return instr32_t; 
    function rv_slti (rd : integer; rs1 : integer; imm12 : integer)  return instr32_t; 

    function rv_sltui (rd : reg_adr_t; rs1 : reg_adr_t; imm12 : imm12_t) return instr32_t; 
    function rv_sltui (rd : integer; rs1 : integer; imm12 : integer) return instr32_t; 

    function rv_xori (rd : reg_adr_t; rs1 : reg_adr_t; imm12 : imm12_t) return instr32_t; 
    function rv_xori (rd : integer; rs1 : integer; imm12 : integer) return instr32_t; 

    function rv_ori (rd : reg_adr_t; rs1 : reg_adr_t; imm12 : imm12_t) return instr32_t; 
    function rv_ori (rd : integer; rs1 : integer; imm12 : integer) return instr32_t; 

    function rv_andi (rd : reg_adr_t; rs1 : reg_adr_t; imm12 : imm12_t) return instr32_t; 
    function rv_andi (rd : integer; rs1 : integer; imm12 : integer) return instr32_t; 

    function rv_slli (rd : reg_adr_t; rs1 : reg_adr_t; shamt : reg_adr_t)  return instr32_t; 
    function rv_slli (rd : integer; rs1 : integer; shamt : integer)  return instr32_t; 

    function rv_srli (rd : reg_adr_t; rs1 : reg_adr_t; shamt : reg_adr_t) return instr32_t; 
    function rv_srli (rd : integer; rs1 : integer; shamt : integer) return instr32_t; 

    function rv_srai (rd : reg_adr_t; rs1 : reg_adr_t; shamt : reg_adr_t) return instr32_t; 
    function rv_srai (rd : integer; rs1 : integer; shamt : integer) return instr32_t; 

    function rv_add (rd : reg_adr_t; rs1 : reg_adr_t; rs2 : reg_adr_t) return instr32_t; 
    function rv_add (rd : integer; rs1 : integer; rs2 : integer) return instr32_t; 

    function rv_sub (rd : reg_adr_t; rs1 : reg_adr_t; rs2 : reg_adr_t) return instr32_t; 
    function rv_sub (rd : integer; rs1 : integer; rs2 : integer) return instr32_t; 

    function rv_sll (rd : reg_adr_t; rs1 : reg_adr_t; rs2 : reg_adr_t) return instr32_t; 
    function rv_sll (rd : integer; rs1 : integer; rs2 : integer) return instr32_t; 

    function rv_slt (rd : reg_adr_t; rs1 : reg_adr_t; rs2 : reg_adr_t) return instr32_t; 
    function rv_slt (rd : integer; rs1 : integer; rs2 : integer) return instr32_t; 
        
    function rv_sltu (rd : reg_adr_t; rs1 : reg_adr_t; rs2 : reg_adr_t)   return instr32_t; 
    function rv_sltu (rd : integer; rs1 : integer; rs2 : integer)   return instr32_t; 
      
    function rv_xor (rd : reg_adr_t; rs1 : reg_adr_t; rs2 : reg_adr_t)  return instr32_t; 
    function rv_xor (rd : integer; rs1 : integer; rs2 : integer)  return instr32_t; 
       
    function rv_srl (rd : reg_adr_t; rs1 : reg_adr_t; rs2 : reg_adr_t) return instr32_t; 
    function rv_srl (rd : integer; rs1 : integer; rs2 : integer) return instr32_t; 
        
    function rv_sra (rd : reg_adr_t; rs1 : reg_adr_t; rs2 : reg_adr_t)  return instr32_t; 
    function rv_sra (rd : integer; rs1 : integer; rs2 : integer)  return instr32_t; 
       
    function rv_or (rd : reg_adr_t; rs1 : reg_adr_t; rs2 : reg_adr_t) return instr32_t;
    function rv_or (rd : integer; rs1 : integer; rs2 : integer) return instr32_t;
        
    function rv_and (rd : reg_adr_t; rs1 : reg_adr_t; rs2 : reg_adr_t) return instr32_t; 
    function rv_and (rd : integer; rs1 : integer; rs2 : integer) return instr32_t; 
        
    function rv_fence return instr32_t; 
       
    function rv_ecall return instr32_t; 
       
    function rv_ebreak return instr32_t; 
       
    function rv_fencei return instr32_t; 
       
    function rv_csrrw (rd : reg_adr_t; rs1 : reg_adr_t; csr_addr : imm12_t)  return instr32_t; 
    function rv_csrrw (rd : integer; rs1 : integer; csr_addr : integer)  return instr32_t; 
       
    function rv_csrrs (rd : reg_adr_t; rs1 : reg_adr_t; csr_addr : imm12_t)   return instr32_t; 
    function rv_csrrs (rd : integer; rs1 : integer; csr_addr : integer)   return instr32_t; 
      
    function rv_csrrc (rd : reg_adr_t; rs1 : reg_adr_t; csr_addr : imm12_t) return instr32_t; 
    function rv_csrrc (rd : integer; rs1 : integer; csr_addr : integer) return instr32_t; 
        
    function rv_csrrwi (rd : reg_adr_t; imm5 : reg_adr_t; csr_addr : imm12_t) return instr32_t; 
    function rv_csrrwi (rd : integer; imm5 : integer; csr_addr : integer) return instr32_t; 
        
    function rv_csrrsi (rd : reg_adr_t; imm5 : reg_adr_t; csr_addr : imm12_t)    return instr32_t; 
    function rv_csrrsi (rd : integer; imm5 : integer; csr_addr : integer)    return instr32_t; 
     
    function rv_csrrci (rd : reg_adr_t; imm5 : reg_adr_t; csr_addr : imm12_t) return instr32_t;
    function rv_csrrci (rd : integer; imm5 : integer; csr_addr : integer) return instr32_t;


end package;



-- Package Body ================================================================
-- =============================================================================
package body rv32_testbench_pkg is
     
    -- Conversion --------------------------------------------------------------
    -- -------------------------------------------------------------------------
    -- Private
    function uint2slv (int : natural; slv_width : natural)
        return std_logic_vector
    is
        variable slv : std_logic_vector(slv_width-1 downto 0);
    begin
        return(std_logic_vector(to_unsigned(int, slv_width)));
    end function;


    -- Private
    function sint2slv (int : integer; slv_width : natural)
        return std_logic_vector
    is
        variable slv : std_logic_vector(slv_width-1 downto 0);
    begin
        return(std_logic_vector(to_signed(int, slv_width)));
    end function;


    -- For register addresses / csr immediates
    function u5 (int : natural)
        return std_logic_vector
    is
    begin
        return(uint2slv(int, 5));
    end function;

    -- For csr addresses
    function u12 (int : natural)
        return std_logic_vector
    is
    begin
        return(uint2slv(int, 12));
    end function;


    -- For 12-bit immediates
    function s12 (int : integer)
        return std_logic_vector
    is
    begin
        return(sint2slv(int, 12));
    end function;


    -- For 20-bit immediates
    function s20 (int : integer)
        return std_logic_vector
    is
    begin
        return(sint2slv(int, 20));
    end function;



    -- =========================================================================
    -- =========================================================================
    -- Logic Vector Versions
    -- =========================================================================
    -- =========================================================================
    

    -- Instruction Encoding ====================================================
    -- =========================================================================
    
    -- RV32I -------------------------------------------------------------------
    -- -------------------------------------------------------------------------
    function rv_lui (rd : reg_adr_t; imm20 : imm20_t) 
        return instr32_t 
    is
        variable instr : instr32_t;
    begin
        instr(RANGE_OPCODE) := OPCODE_LUI;
        instr(RANGE_RD)     := rd;
        instr(RANGE_IMM_U)  := imm20;
        return instr; 
    end function;


    function rv_auipc (rd : reg_adr_t; imm20 : imm20_t) 
        return instr32_t 
    is
        variable instr : instr32_t;
    begin
        instr(RANGE_OPCODE) := OPCODE_AUIPC;
        instr(RANGE_RD)     := rd;
        instr(RANGE_IMM_U)  := imm20;
        return instr; 
    end function;


    function rv_jal (rd : reg_adr_t; imm20 : imm20_t) 
        return instr32_t 
    is
        variable instr : instr32_t;
    begin
        instr(RANGE_OPCODE)      := OPCODE_JAL;
        instr(RANGE_RD)          := rd;
        instr(RANGE_IMM_J_20)    := imm20(19);
        instr(RANGE_IMM_J_19_12) := imm20(18 downto 11);
        instr(RANGE_IMM_J_11)    := imm20(10);
        instr(RANGE_IMM_J_10_1)  := imm20(9 downto 0);
        return instr; 
    end function;


    function rv_jalr (rd : reg_adr_t; rs1 : reg_adr_t; imm12 : imm12_t) 
        return instr32_t 
    is
        variable instr : instr32_t;
    begin
        instr(RANGE_OPCODE) := OPCODE_JALR;
        instr(RANGE_FUNCT3) := F3_JALR;
        instr(RANGE_RD)     := rd;
        instr(RANGE_RS1)    := rs1;
        instr(RANGE_IMM_I)  := imm12;
        return instr; 
    end function;


    function rv_beq (rs1 : reg_adr_t; rs2 : reg_adr_t; imm12 : imm12_t) 
        return instr32_t 
    is
        variable instr : instr32_t;
    begin
        instr(RANGE_OPCODE)     := OPCODE_BRANCH;
        instr(RANGE_FUNCT3)     := F3_BEQ;
        instr(RANGE_RS1)        := rs1;
        instr(RANGE_RS2)        := rs2;
        instr(RANGE_IMM_B_12)   := imm12(11);
        instr(RANGE_IMM_B_11)   := imm12(10);
        instr(RANGE_IMM_B_10_5) := imm12(9 downto 4);
        instr(RANGE_IMM_B_4_1)  := imm12(3 downto 0);
        return instr; 
    end function;   
    
    
    function rv_bne (rs1 : reg_adr_t; rs2 : reg_adr_t; imm12 : imm12_t) 
        return instr32_t 
    is
        variable instr : instr32_t;
    begin
        instr(RANGE_OPCODE)     := OPCODE_BRANCH;
        instr(RANGE_FUNCT3)     := F3_BNE;
        instr(RANGE_RS1)        := rs1;
        instr(RANGE_RS2)        := rs2;
        instr(RANGE_IMM_B_12)   := imm12(11);
        instr(RANGE_IMM_B_11)   := imm12(10);
        instr(RANGE_IMM_B_10_5) := imm12(9 downto 4);
        instr(RANGE_IMM_B_4_1)  := imm12(3 downto 0);
        return instr; 
    end function; 


    function rv_blt (rs1 : reg_adr_t; rs2 : reg_adr_t; imm12 : imm12_t) 
        return instr32_t 
    is
        variable instr : instr32_t;
    begin
        instr(RANGE_OPCODE)     := OPCODE_BRANCH;
        instr(RANGE_FUNCT3)     := F3_BLT;
        instr(RANGE_RS1)        := rs1;
        instr(RANGE_RS2)        := rs2;
        instr(RANGE_IMM_B_12)   := imm12(11);
        instr(RANGE_IMM_B_11)   := imm12(10);
        instr(RANGE_IMM_B_10_5) := imm12(9 downto 4);
        instr(RANGE_IMM_B_4_1)  := imm12(3 downto 0);
        return instr; 
    end function;   
    

    function rv_bge (rs1 : reg_adr_t; rs2 : reg_adr_t; imm12 : imm12_t) 
        return instr32_t 
    is
        variable instr : instr32_t;
    begin
        instr(RANGE_OPCODE)     := OPCODE_BRANCH;
        instr(RANGE_FUNCT3)     := F3_BGE;
        instr(RANGE_RS1)        := rs1;
        instr(RANGE_RS2)        := rs2;
        instr(RANGE_IMM_B_12)   := imm12(11);
        instr(RANGE_IMM_B_11)   := imm12(10);
        instr(RANGE_IMM_B_10_5) := imm12(9 downto 4);
        instr(RANGE_IMM_B_4_1)  := imm12(3 downto 0);
        return instr; 
    end function; 


    function rv_bltu (rs1 : reg_adr_t; rs2 : reg_adr_t; imm12 : imm12_t) 
        return instr32_t 
    is
        variable instr : instr32_t;
    begin
        instr(RANGE_OPCODE)     := OPCODE_BRANCH;
        instr(RANGE_FUNCT3)     := F3_BLTU;
        instr(RANGE_RS1)        := rs1;
        instr(RANGE_RS2)        := rs2;
        instr(RANGE_IMM_B_12)   := imm12(11);
        instr(RANGE_IMM_B_11)   := imm12(10);
        instr(RANGE_IMM_B_10_5) := imm12(9 downto 4);
        instr(RANGE_IMM_B_4_1)  := imm12(3 downto 0);
        return instr; 
    end function;   
    
    
    function rv_bgeu (rs1 : reg_adr_t; rs2 : reg_adr_t; imm12 : imm12_t) 
        return instr32_t 
    is
        variable instr : instr32_t;
    begin
        instr(RANGE_OPCODE)     := OPCODE_BRANCH;
        instr(RANGE_FUNCT3)     := F3_BGEU;
        instr(RANGE_RS1)        := rs1;
        instr(RANGE_RS2)        := rs2;
        instr(RANGE_IMM_B_12)   := imm12(11);
        instr(RANGE_IMM_B_11)   := imm12(10);
        instr(RANGE_IMM_B_10_5) := imm12(9 downto 4);
        instr(RANGE_IMM_B_4_1)  := imm12(3 downto 0);
        return instr; 
    end function; 


    function rv_lb (rd : reg_adr_t; rs1 : reg_adr_t; imm12 : imm12_t) 
        return instr32_t 
    is
        variable instr : instr32_t;
    begin
        instr(RANGE_OPCODE) := OPCODE_LOAD;
        instr(RANGE_FUNCT3) := F3_LB;
        instr(RANGE_RD)     := rd;
        instr(RANGE_RS1)    := rs1;
        instr(RANGE_IMM_I)  := imm12;
        return instr; 
    end function; 


    function rv_lh (rd : reg_adr_t; rs1 : reg_adr_t; imm12 : imm12_t) 
        return instr32_t 
    is
        variable instr : instr32_t;
    begin
        instr(RANGE_OPCODE) := OPCODE_LOAD;
        instr(RANGE_FUNCT3) := F3_LH;
        instr(RANGE_RD)     := rd;
        instr(RANGE_RS1)    := rs1;
        instr(RANGE_IMM_I)  := imm12;
        return instr; 
    end function; 


    function rv_lw (rd : reg_adr_t; rs1 : reg_adr_t; imm12 : imm12_t) 
        return instr32_t 
    is
        variable instr : instr32_t;
    begin
        instr(RANGE_OPCODE) := OPCODE_LOAD;
        instr(RANGE_FUNCT3) := F3_LW;
        instr(RANGE_RD)     := rd;
        instr(RANGE_RS1)    := rs1;
        instr(RANGE_IMM_I)  := imm12;
        return instr; 
    end function; 


    function rv_lbu (rd : reg_adr_t; rs1 : reg_adr_t; imm12 : imm12_t) 
        return instr32_t 
    is
        variable instr : instr32_t;
    begin
        instr(RANGE_OPCODE) := OPCODE_LOAD;
        instr(RANGE_FUNCT3) := F3_LBU;
        instr(RANGE_RD)     := rd;
        instr(RANGE_RS1)    := rs1;
        instr(RANGE_IMM_I)  := imm12;
        return instr; 
    end function; 


    function rv_lhu (rd : reg_adr_t; rs1 : reg_adr_t; imm12 : imm12_t) 
        return instr32_t 
    is
        variable instr : instr32_t;
    begin
        instr(RANGE_OPCODE) := OPCODE_LOAD;
        instr(RANGE_FUNCT3) := F3_LHU;
        instr(RANGE_RD)     := rd;
        instr(RANGE_RS1)    := rs1;
        instr(RANGE_IMM_I)  := imm12;
        return instr; 
    end function; 


    function rv_sb (rs1 : reg_adr_t; rs2 : reg_adr_t; imm12 : imm12_t) 
        return instr32_t 
    is
        variable instr : instr32_t;
    begin
        instr(RANGE_OPCODE)     := OPCODE_STORE;
        instr(RANGE_FUNCT3)     := F3_SB;
        instr(RANGE_RS1)        := rs1;
        instr(RANGE_RS2)        := rs2;
        instr(RANGE_IMM_S_11_5) := imm12(11 downto 5);
        instr(RANGE_IMM_S_4_0)  := imm12(4 downto 0);
        return instr; 
    end function; 


    function rv_sh (rs1 : reg_adr_t; rs2 : reg_adr_t; imm12 : imm12_t) 
        return instr32_t 
    is
        variable instr : instr32_t;
    begin
        instr(RANGE_OPCODE)     := OPCODE_STORE;
        instr(RANGE_FUNCT3)     := F3_SH;
        instr(RANGE_RS1)        := rs1;
        instr(RANGE_RS2)        := rs2;
        instr(RANGE_IMM_S_11_5) := imm12(11 downto 5);
        instr(RANGE_IMM_S_4_0)  := imm12(4 downto 0);
        return instr; 
    end function; 


    function rv_sw (rs1 : reg_adr_t; rs2 : reg_adr_t; imm12 : imm12_t) 
        return instr32_t 
    is
        variable instr : instr32_t;
    begin
        instr(RANGE_OPCODE)     := OPCODE_STORE;
        instr(RANGE_FUNCT3)     := F3_SW;
        instr(RANGE_RS1)        := rs1;
        instr(RANGE_RS2)        := rs2;
        instr(RANGE_IMM_S_11_5) := imm12(11 downto 5);
        instr(RANGE_IMM_S_4_0)  := imm12(4 downto 0);
        return instr; 
    end function; 


    function rv_addi (rd : reg_adr_t; rs1 : reg_adr_t; imm12 : imm12_t) 
        return instr32_t 
    is
        variable instr : instr32_t;
    begin
        instr(RANGE_OPCODE) := OPCODE_ALUI;
        instr(RANGE_FUNCT3) := F3_SUBADD;
        instr(RANGE_RD)     := rd;
        instr(RANGE_RS1)    := rs1;
        instr(RANGE_IMM_I)  := imm12;
        return instr; 
    end function; 


    function rv_slti (rd : reg_adr_t; rs1 : reg_adr_t; imm12 : imm12_t) 
        return instr32_t 
    is
        variable instr : instr32_t;
    begin
        instr(RANGE_OPCODE) := OPCODE_ALUI;
        instr(RANGE_FUNCT3) := F3_SLT;
        instr(RANGE_RD)     := rd;
        instr(RANGE_RS1)    := rs1;
        instr(RANGE_IMM_I)  := imm12;
        return instr; 
    end function; 


    function rv_sltui (rd : reg_adr_t; rs1 : reg_adr_t; imm12 : imm12_t) 
        return instr32_t 
    is
        variable instr : instr32_t;
    begin
        instr(RANGE_OPCODE) := OPCODE_ALUI;
        instr(RANGE_FUNCT3) := F3_SLTU;
        instr(RANGE_RD)     := rd;
        instr(RANGE_RS1)    := rs1;
        instr(RANGE_IMM_I)  := imm12;
        return instr; 
    end function; 


    function rv_xori (rd : reg_adr_t; rs1 : reg_adr_t; imm12 : imm12_t) 
        return instr32_t 
    is
        variable instr : instr32_t;
    begin
        instr(RANGE_OPCODE) := OPCODE_ALUI;
        instr(RANGE_FUNCT3) := F3_XOR;
        instr(RANGE_RD)     := rd;
        instr(RANGE_RS1)    := rs1;
        instr(RANGE_IMM_I)  := imm12;
        return instr; 
    end function; 


    function rv_ori (rd : reg_adr_t; rs1 : reg_adr_t; imm12 : imm12_t) 
        return instr32_t 
    is
        variable instr : instr32_t;
    begin
        instr(RANGE_OPCODE) := OPCODE_ALUI;
        instr(RANGE_FUNCT3) := F3_OR;
        instr(RANGE_RD)     := rd;
        instr(RANGE_RS1)    := rs1;
        instr(RANGE_IMM_I)  := imm12;
        return instr; 
    end function; 


    function rv_andi (rd : reg_adr_t; rs1 : reg_adr_t; imm12 : imm12_t) 
        return instr32_t 
    is
        variable instr : instr32_t;
    begin
        instr(RANGE_OPCODE) := OPCODE_ALUI;
        instr(RANGE_FUNCT3) := F3_AND;
        instr(RANGE_RD)     := rd;
        instr(RANGE_RS1)    := rs1;
        instr(RANGE_IMM_I)  := imm12;
        return instr; 
    end function; 


    function rv_slli (rd : reg_adr_t; rs1 : reg_adr_t; shamt : reg_adr_t) 
        return instr32_t 
    is
        variable instr : instr32_t;
    begin
        instr(RANGE_OPCODE)  := OPCODE_ALUI;
        instr(RANGE_FUNCT3)  := F3_SLL;
        instr(RANGE_FUNCT7)  := F7_ZERO;
        instr(RANGE_RD)      := rd;
        instr(RANGE_RS1)     := rs1;
        instr(RANGE_SHAMT_I) := shamt;
        return instr; 
    end function; 


    function rv_srli (rd : reg_adr_t; rs1 : reg_adr_t; shamt : reg_adr_t) 
        return instr32_t 
    is
        variable instr : instr32_t;
    begin
        instr(RANGE_OPCODE)  := OPCODE_ALUI;
        instr(RANGE_FUNCT3)  := F3_SR;
        instr(RANGE_FUNCT7)  := F7_ZERO;
        instr(RANGE_RD)      := rd;
        instr(RANGE_RS1)     := rs1;
        instr(RANGE_SHAMT_I) := shamt;
        return instr; 
    end function; 


    function rv_srai (rd : reg_adr_t; rs1 : reg_adr_t; shamt : reg_adr_t) 
        return instr32_t 
    is
        variable instr : instr32_t;
    begin
        instr(RANGE_OPCODE)  := OPCODE_ALUI;
        instr(RANGE_FUNCT3)  := F3_SR;
        instr(RANGE_FUNCT7)  := F7_32;
        instr(RANGE_RD)      := rd;
        instr(RANGE_RS1)     := rs1;
        instr(RANGE_SHAMT_I) := shamt;
        return instr; 
    end function; 


    function rv_add (rd : reg_adr_t; rs1 : reg_adr_t; rs2 : reg_adr_t) 
        return instr32_t 
    is
        variable instr : instr32_t;
    begin
        instr(RANGE_OPCODE) := OPCODE_ALUR;
        instr(RANGE_FUNCT3) := F3_SUBADD;
        instr(RANGE_FUNCT7) := F7_ZERO;
        instr(RANGE_RD)     := rd;
        instr(RANGE_RS1)    := rs1;
        instr(RANGE_RS2)    := rs2;
        return instr; 
    end function; 


    function rv_sub (rd : reg_adr_t; rs1 : reg_adr_t; rs2 : reg_adr_t) 
        return instr32_t 
    is
        variable instr : instr32_t;
    begin
        instr(RANGE_OPCODE) := OPCODE_ALUR;
        instr(RANGE_FUNCT3) := F3_SUBADD;
        instr(RANGE_FUNCT7) := F7_32;
        instr(RANGE_RD)     := rd;
        instr(RANGE_RS1)    := rs1;
        instr(RANGE_RS2)    := rs2;
        return instr; 
    end function; 

    
    function rv_sll (rd : reg_adr_t; rs1 : reg_adr_t; rs2 : reg_adr_t) 
        return instr32_t 
    is
        variable instr : instr32_t;
    begin
        instr(RANGE_OPCODE) := OPCODE_ALUR;
        instr(RANGE_FUNCT3) := F3_SLL;
        instr(RANGE_FUNCT7) := F7_ZERO;
        instr(RANGE_RD)     := rd;
        instr(RANGE_RS1)    := rs1;
        instr(RANGE_RS2)    := rs2;
        return instr; 
    end function; 


    function rv_slt (rd : reg_adr_t; rs1 : reg_adr_t; rs2 : reg_adr_t) 
        return instr32_t 
    is
        variable instr : instr32_t;
    begin
        instr(RANGE_OPCODE) := OPCODE_ALUR;
        instr(RANGE_FUNCT3) := F3_SLT;
        instr(RANGE_FUNCT7) := F7_ZERO;
        instr(RANGE_RD)     := rd;
        instr(RANGE_RS1)    := rs1;
        instr(RANGE_RS2)    := rs2;
        return instr; 
    end function; 


    function rv_sltu (rd : reg_adr_t; rs1 : reg_adr_t; rs2 : reg_adr_t) 
        return instr32_t 
    is
        variable instr : instr32_t;
    begin
        instr(RANGE_OPCODE) := OPCODE_ALUR;
        instr(RANGE_FUNCT3) := F3_SLTU;
        instr(RANGE_FUNCT7) := F7_ZERO;
        instr(RANGE_RD)     := rd;
        instr(RANGE_RS1)    := rs1;
        instr(RANGE_RS2)    := rs2;
        return instr; 
    end function; 


    function rv_xor (rd : reg_adr_t; rs1 : reg_adr_t; rs2 : reg_adr_t) 
        return instr32_t 
    is
        variable instr : instr32_t;
    begin
        instr(RANGE_OPCODE) := OPCODE_ALUR;
        instr(RANGE_FUNCT3) := F3_XOR;
        instr(RANGE_FUNCT7) := F7_ZERO;
        instr(RANGE_RD)     := rd;
        instr(RANGE_RS1)    := rs1;
        instr(RANGE_RS2)    := rs2;
        return instr; 
    end function; 


    function rv_srl (rd : reg_adr_t; rs1 : reg_adr_t; rs2 : reg_adr_t) 
        return instr32_t 
    is
        variable instr : instr32_t;
    begin
        instr(RANGE_OPCODE) := OPCODE_ALUR;
        instr(RANGE_FUNCT3) := F3_SR;
        instr(RANGE_FUNCT7) := F7_ZERO;
        instr(RANGE_RD)     := rd;
        instr(RANGE_RS1)    := rs1;
        instr(RANGE_RS2)    := rs2;
        return instr; 
    end function; 


    function rv_sra (rd : reg_adr_t; rs1 : reg_adr_t; rs2 : reg_adr_t) 
        return instr32_t 
    is
        variable instr : instr32_t;
    begin
        instr(RANGE_OPCODE) := OPCODE_ALUR;
        instr(RANGE_FUNCT3) := F3_SR;
        instr(RANGE_FUNCT7) := F7_32;
        instr(RANGE_RD)     := rd;
        instr(RANGE_RS1)    := rs1;
        instr(RANGE_RS2)    := rs2;
        return instr; 
    end function; 


    function rv_or (rd : reg_adr_t; rs1 : reg_adr_t; rs2 : reg_adr_t) 
        return instr32_t 
    is
        variable instr : instr32_t;
    begin
        instr(RANGE_OPCODE) := OPCODE_ALUR;
        instr(RANGE_FUNCT3) := F3_OR;
        instr(RANGE_FUNCT7) := F7_ZERO;
        instr(RANGE_RD)     := rd;
        instr(RANGE_RS1)    := rs1;
        instr(RANGE_RS2)    := rs2;
        return instr; 
    end function; 

    function rv_and (rd : reg_adr_t; rs1 : reg_adr_t; rs2 : reg_adr_t) 
        return instr32_t 
    is
        variable instr : instr32_t;
    begin
        instr(RANGE_OPCODE) := OPCODE_ALUR;
        instr(RANGE_FUNCT3) := F3_AND;
        instr(RANGE_FUNCT7) := F7_ZERO;
        instr(RANGE_RD)     := rd;
        instr(RANGE_RS1)    := rs1;
        instr(RANGE_RS2)    := rs2;
        return instr; 
    end function; 


    -- NOTE: This assumes the simplest fence implementation with not extra I/O, R/W, fm options
    function rv_fence
        return instr32_t 
    is
        variable instr : instr32_t;
    begin
        instr(RANGE_OPCODE) := OPCODE_FENCE;
        instr(31 downto 7)  := (others=>'0');
        return instr; 
    end function; 

    
    function rv_ecall
        return instr32_t 
    is
        variable instr : instr32_t;
    begin
        instr(RANGE_OPCODE) := OPCODE_SYSTEM;
        instr(31 downto 7)  := (others=>'0');
        return instr; 
    end function; 


    function rv_ebreak
        return instr32_t 
    is
        variable instr : instr32_t;
    begin
        instr(RANGE_OPCODE) := OPCODE_SYSTEM;
        instr(31 downto 7)  := x"0010_00" & '0';
        return instr; 
    end function; 



    -- Zifencei ------------------------------------------------------------------------------------
    -- ---------------------------------------------------------------------------------------------
    function rv_fencei
        return instr32_t 
    is
        variable instr : instr32_t;
    begin
        instr(RANGE_OPCODE) := OPCODE_FENCE;
        instr(RANGE_FUNCT3) := F3_FENCEI;
        instr(RANGE_RD)     := b"00000";
        instr(RANGE_RS1)    := b"00000";
        instr(RANGE_IMM_I)  := x"000";
        return instr; 
    end function; 



    -- Zicsr ------------------------------------------------------------------------------------
    -- ---------------------------------------------------------------------------------------------
    function rv_csrrw (rd : reg_adr_t; rs1 : reg_adr_t; csr_addr : imm12_t) 
        return instr32_t 
    is
        variable instr : instr32_t;
    begin
        instr(RANGE_OPCODE) := OPCODE_SYSTEM;
        instr(RANGE_FUNCT3) := F3_CSRRW;
        instr(RANGE_RD)     := rd;
        instr(RANGE_RS1)    := rs1;
        instr(RANGE_IMM_I)  := csr_addr;
        return instr; 
    end function; 


    function rv_csrrs (rd : reg_adr_t; rs1 : reg_adr_t; csr_addr : imm12_t) 
        return instr32_t 
    is
        variable instr : instr32_t;
    begin
        instr(RANGE_OPCODE) := OPCODE_SYSTEM;
        instr(RANGE_FUNCT3) := F3_CSRRS;
        instr(RANGE_RD)     := rd;
        instr(RANGE_RS1)    := rs1;
        instr(RANGE_IMM_I)  := csr_addr;
        return instr; 
    end function; 


    function rv_csrrc (rd : reg_adr_t; rs1 : reg_adr_t; csr_addr : imm12_t) 
        return instr32_t 
    is
        variable instr : instr32_t;
    begin
        instr(RANGE_OPCODE) := OPCODE_SYSTEM;
        instr(RANGE_FUNCT3) := F3_CSRRC;
        instr(RANGE_RD)     := rd;
        instr(RANGE_RS1)    := rs1;
        instr(RANGE_IMM_I)  := csr_addr;
        return instr; 
    end function; 


    function rv_csrrwi (rd : reg_adr_t; imm5 : reg_adr_t; csr_addr : imm12_t) 
        return instr32_t 
    is
        variable instr : instr32_t;
    begin
        instr(RANGE_OPCODE) := OPCODE_SYSTEM;
        instr(RANGE_FUNCT3) := F3_CSRRWI;
        instr(RANGE_RD)     := rd;
        instr(RANGE_RS1)    := imm5;
        instr(RANGE_IMM_I)  := csr_addr;
        return instr; 
    end function; 


    function rv_csrrsi (rd : reg_adr_t; imm5 : reg_adr_t; csr_addr : imm12_t) 
        return instr32_t 
    is
        variable instr : instr32_t;
    begin
        instr(RANGE_OPCODE) := OPCODE_SYSTEM;
        instr(RANGE_FUNCT3) := F3_CSRRSI;
        instr(RANGE_RD)     := rd;
        instr(RANGE_RS1)    := imm5;
        instr(RANGE_IMM_I)  := csr_addr;
        return instr; 
    end function; 


    function rv_csrrci (rd : reg_adr_t; imm5 : reg_adr_t; csr_addr : imm12_t) 
        return instr32_t 
    is
        variable instr : instr32_t;
    begin
        instr(RANGE_OPCODE) := OPCODE_SYSTEM;
        instr(RANGE_FUNCT3) := F3_CSRRCI;
        instr(RANGE_RD)     := rd;
        instr(RANGE_RS1)    := imm5;
        instr(RANGE_IMM_I)  := csr_addr;
        return instr; 
    end function; 




    -- Others TBD when and if appropriate





    -- =========================================================================
    -- =========================================================================
    -- Integer Versions
    -- =========================================================================
    -- =========================================================================

    function rv_lui (rd : integer; imm20 : integer) return instr32_t is
    begin
        return rv_lui (u5(rd), s20(imm20));
    end function;

    function rv_auipc (rd : integer; imm20 : integer) return instr32_t is
    begin
        return rv_auipc (u5(rd), s20(imm20));
    end function; 

    function rv_jal (rd : integer; imm20 : integer) return instr32_t is
    begin
        return rv_jal(u5(rd), s20(imm20));
    end function; 

    function rv_jalr (rd : integer; rs1 : integer; imm12 : integer) return instr32_t is
    begin
        return rv_jalr(u5(rd), u5(rs1), s12(imm12));
    end function; 
        
    function rv_beq (rs1 : integer; rs2 : integer; imm12 : integer)  return instr32_t is
    begin
        return rv_beq(u5(rs1), u5(rs2), s12(imm12));
    end function;  

    function rv_bne (rs1 : integer; rs2 : integer; imm12 : integer) return instr32_t is
    begin
        return rv_bne(u5(rs1), u5(rs2), s12(imm12));
    end function; 

    function rv_blt (rs1 : integer; rs2 : integer; imm12 : integer)  return instr32_t is
    begin
        return rv_blt(u5(rs1), u5(rs2), s12(imm12));
    end function; 

    function rv_bge (rs1 : integer; rs2 : integer; imm12 : integer) return instr32_t is
    begin
        return rv_bge(u5(rs1), u5(rs2), s12(imm12));
    end function; 

    function rv_bltu (rs1 : integer; rs2 : integer; imm12 : integer) return instr32_t is
    begin
        return rv_bltu(u5(rs1), u5(rs2), s12(imm12));
    end function; 

    function rv_bgeu (rs1 : integer; rs2 : integer; imm12 : integer) return instr32_t is
    begin
        return rv_bgeu(u5(rs1), u5(rs2), s12(imm12));
    end function; 

    function rv_lb (rd : integer; rs1 : integer; imm12 : integer) return instr32_t is
    begin
        return  rv_lb(u5(rd), u5(rs1), s12(imm12));
    end function; 

    function rv_lh (rd : integer; rs1 : integer; imm12 : integer) return instr32_t is
    begin
        return rv_lh(u5(rd), u5(rs1), s12(imm12));
    end function; 

    function rv_lw (rd : integer; rs1 : integer; imm12 : integer) return instr32_t is
    begin
        return rv_lw(u5(rd), u5(rs1), s12(imm12));
    end function; 

    function rv_lbu (rd : integer; rs1 : integer; imm12 : integer) return instr32_t is
    begin
        return rv_lbu(u5(rd), u5(rs1), s12(imm12));
    end function; 

    function rv_lhu (rd : integer; rs1 : integer; imm12 : integer) return instr32_t is
    begin
        return rv_lhu(u5(rd), u5(rs1), s12(imm12));
    end function; 
        
    function rv_sb (rs1 : integer; rs2 : integer; imm12 : integer) return instr32_t is
    begin
        return rv_sb(u5(rs1), u5(rs2), s12(imm12));
    end function; 
        
    function rv_sh (rs1 : integer; rs2 : integer; imm12 : integer) return instr32_t is
    begin
        return rv_sh(u5(rs1), u5(rs2), s12(imm12));
    end function; 

    function rv_sw (rs1 : integer; rs2 : integer; imm12 : integer) return instr32_t is
    begin
        return rv_sw(u5(rs1), u5(rs2), s12(imm12));
    end function; 

    function rv_addi (rd : integer; rs1 : integer; imm12 : integer) return instr32_t is
    begin
        return rv_addi(u5(rd), u5(rs1), s12(imm12));
    end function; 

    function rv_slti (rd : integer; rs1 : integer; imm12 : integer) return instr32_t is
    begin
        return rv_slti(u5(rd), u5(rs1), s12(imm12));
    end function; 

    function rv_sltui (rd : integer; rs1 : integer; imm12 : integer) return instr32_t is
    begin
        return rv_sltui(u5(rd), u5(rs1), s12(imm12));
    end function; 

    function rv_xori (rd : integer; rs1 : integer; imm12 : integer) return instr32_t is
    begin
        return rv_xori(u5(rd), u5(rs1), s12(imm12));
    end function; 

    function rv_ori (rd : integer; rs1 : integer; imm12 : integer) return instr32_t is
    begin
        return rv_ori(u5(rd), u5(rs1), s12(imm12));
    end function; 

    function rv_andi (rd : integer; rs1 : integer; imm12 : integer) return instr32_t is
    begin
        return rv_andi(u5(rd), u5(rs1), s12(imm12));
    end function; 

    function rv_slli (rd : integer; rs1 : integer; shamt : integer) return instr32_t is
    begin
        return rv_slli(u5(rd), u5(rs1), u5(shamt));
    end function; 

    function rv_srli (rd : integer; rs1 : integer; shamt : integer) return instr32_t is
    begin
        return rv_srli(u5(rd), u5(rs1), u5(shamt));
    end function; 

    function rv_srai (rd : integer; rs1 : integer; shamt : integer) return instr32_t is
    begin
        return rv_srai(u5(rd), u5(rs1), u5(shamt));
    end function; 

    function rv_add (rd : integer; rs1 : integer; rs2 : integer) return instr32_t is
    begin
        return rv_add(u5(rd), u5(rs1), u5(rs2));
    end function; 

    function rv_sub (rd : integer; rs1 : integer; rs2 : integer) return instr32_t is
    begin
        return rv_sub(u5(rd), u5(rs1), u5(rs2));
    end function; 

    function rv_sll (rd : integer; rs1 : integer; rs2 : integer) return instr32_t is
    begin
        return rv_sll(u5(rd), u5(rs1), u5(rs2));
    end function; 

    function rv_slt (rd : integer; rs1 : integer; rs2 : integer) return instr32_t is
    begin
        return rv_slt(u5(rd), u5(rs1), u5(rs2));
    end function; 
        
    function rv_sltu (rd : integer; rs1 : integer; rs2 : integer) return instr32_t is
    begin
        return rv_sltu(u5(rd), u5(rs1), u5(rs2));
    end function; 
      
    function rv_xor (rd : integer; rs1 : integer; rs2 : integer) return instr32_t is
    begin
        return rv_xor(u5(rd), u5(rs1), u5(rs2));
    end function; 
       
    function rv_srl (rd : integer; rs1 : integer; rs2 : integer) return instr32_t is
    begin
        return rv_srl(u5(rd), u5(rs1), u5(rs2));
    end function; 
        
    function rv_sra (rd : integer; rs1 : integer; rs2 : integer) return instr32_t is
    begin
        return rv_sra(u5(rd), u5(rs1), u5(rs2));
    end function; 
       
    function rv_or (rd : integer; rs1 : integer; rs2 : integer) return instr32_t is
    begin
        return rv_or(u5(rd), u5(rs1), u5(rs2));
    end function; 
        
    function rv_and (rd : integer; rs1 : integer; rs2 : integer) return instr32_t is
    begin
        return rv_and(u5(rd), u5(rs1), u5(rs2));
    end function; 
       
    function rv_csrrw (rd : integer; rs1 : integer; csr_addr : integer) return instr32_t is
    begin
        return rv_csrrw(u5(rd), u5(rs1), u12(csr_addr));
    end function; 
       
    function rv_csrrs (rd : integer; rs1 : integer; csr_addr : integer) return instr32_t is
    begin
        return rv_csrrs(u5(rd), u5(rs1), u12(csr_addr));
    end function; 
      
    function rv_csrrc (rd : integer; rs1 : integer; csr_addr : integer) return instr32_t is
    begin
        return rv_csrrc(u5(rd), u5(rs1), u12(csr_addr));
    end function; 
        
    function rv_csrrwi (rd : integer; imm5 : integer; csr_addr : integer) return instr32_t is
    begin
        return rv_csrrwi(u5(rd), u5(imm5), u12(csr_addr));
    end function; 
        
    function rv_csrrsi (rd : integer; imm5 : integer; csr_addr : integer) return instr32_t is
    begin
        return rv_csrrsi(u5(rd), u5(imm5), u12(csr_addr));
    end function; 
     
    function rv_csrrci (rd : integer; imm5 : integer; csr_addr : integer) return instr32_t is
    begin
        return rv_csrrci(u5(rd), u5(imm5), u12(csr_addr));
    end function; 


end package body;

