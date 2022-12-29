-- #############################################################################
-- #  << RISC-V CPU Testbench Package >>
-- # ===========================================================================
-- # File     : rv32_testbench_pkg.vhd
-- # Author   : David Gussler - david.gussler@proton.me
-- # Language : VHDL '08
-- # ===========================================================================
-- # BSD 2-Clause License
-- # 
-- # Copyright (c) 2022, David Gussler. All rights reserved.
-- # 
-- # Redistribution and use in source and binary forms, with or without
-- # modification, are permitted provided that the following conditions are met:
-- # 
-- # 1. Redistributions of source code must retain the above copyright notice,
-- #     this list of conditions and the following disclaimer.
-- # 
-- # 2. Redistributions in binary form must reproduce the above copyright 
-- #    notice, this list of conditions and the following disclaimer in the 
-- #    documentation and/or other materials provided with the distribution.
-- # 
-- # THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
-- # AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
-- # IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE 
-- # ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE 
-- # LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
-- # CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF 
-- # SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS 
-- # INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN 
-- # CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) 
-- # ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
-- #  POSSIBILITY OF SUCH DAMAGE.
-- # ===========================================================================
-- # RV32 TB functions. These functions are used in the testbench to build 
-- # risc-v machine-code instructions, which are then loaded into simulated
-- # memory for the processor to fetch. These can be thought of as instruction 
-- # encoders. 
-- #
-- # Important note: 
-- # Offsets are in multiples of 2 bytes for all branchs and jumps
-- # for example jal(1, 8) would jump 8x2 bytes
-- #
-- # Makes use of function overloading to allow the user to feed inputs
-- # as either std_logic_vectors or integers.
-- #
-- #############################################################################


-- Libraries -------------------------------------------------------------------
-- -----------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.rv32_pkg.all;
library osvvm;
use osvvm.RandomPkg.all;


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

    -- Enumeration of all the instructions. This is used to select the list of 
    -- possible instructions in random instruction generator
    type instrs_t is (ENUM_LUI, ENUM_AUIPC, ENUM_JAL, ENUM_JALR, ENUM_BEQ, 
        ENUM_BNE, ENUM_BLT, ENUM_BGE, ENUM_BGEU, ENUM_LB, ENUM_LH, ENUM_LW, 
        ENUM_LBU, ENUM_LHU, ENUM_SB, ENUM_SH, ENUM_SW, ENUM_ADDI, ENUM_SLTI,
        ENUM_SLTUI, ENUM_XORI, ENUM_ORI, ENUM_ANDI, ENUM_SLLI, ENUM_SRLI, 
        ENUM_SRAI, ENUM_ADD, ENUM_SUB, ENUM_SLL, ENUM_SLT, ENUM_SLTU, ENUM_XOR, 
        ENUM_SRL, ENUM_SRA, ENUM_OR, ENUM_AND, ENUM_FENCE, ENUM_FENCEI, 
        ENUM_ECALL, ENUM_EBREAK, ENUM_CSRRW, ENUM_CSRRS, ENUM_CSRRC,
        ENUM_CSRRWI, ENUM_CSRRSI, ENUM_CSRRCI, ENUM_WFI, ENUM_MRET);

    type instrs_array_t is array (natural range <>) of instrs_t;

    -- Type Conversion Functions -----------------------------------------------
    -- -------------------------------------------------------------------------
    function u5  (int : natural) return std_logic_vector;
    function u12 (int : natural) return std_logic_vector;
    function s12 (int : integer) return std_logic_vector;
    function s20 (int : integer) return std_logic_vector;

    -- Random Functions --------------------------------------------------------
    -- -------------------------------------------------------------------------
    -- Generates a random instruction with random data in the fields
    procedure rv_random (
        variable rnd             : inout RandomPType;
        constant length          : in    positive; 
        constant instr_list      : in    instrs_array_t;
        constant reg_range_min   : in    integer range 0 to 2**5-1;
        constant reg_range_max   : in    integer range 0 to 2**5-1;
        constant imm12_range_min : in    integer range -2**11 to 2**11-1;
        constant imm12_range_max : in    integer range -2**11 to 2**12-1;
        constant imm20_range_min : in    integer range -2**19 to 2**19-1;
        constant imm20_range_max : in    integer range -2**19 to 2**19-1;
        variable v_instr         : out   instr32_t);
        

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

    function rv_wfi return instr32_t; 

    function rv_mret return instr32_t; 


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


    -- Random Instruction ======================================================
    -- =========================================================================
    procedure rv_random (
        variable rnd             : inout RandomPType;
        constant length          : in    positive; 
        constant instr_list      : in    instrs_array_t;
        constant reg_range_min   : in    integer range 0 to 2**5-1;
        constant reg_range_max   : in    integer range 0 to 2**5-1;
        constant imm12_range_min : in    integer range -2**11 to 2**11-1;
        constant imm12_range_max : in    integer range -2**11 to 2**12-1;
        constant imm20_range_min : in    integer range -2**19 to 2**19-1;
        constant imm20_range_max : in    integer range -2**19 to 2**19-1;
        variable v_instr         : out   instr32_t)
    is
        variable v_instr_sel : instrs_t;
        variable v_reg_adr0  : reg_adr_t;
        variable v_reg_adr1  : reg_adr_t;
        variable v_reg_adr2  : reg_adr_t;
        variable v_imm12     : imm12_t;
        variable v_imm20     : imm20_t;

    begin

        v_instr_sel := instr_list(rnd.RandInt(0, length-1));
        v_reg_adr0  := std_logic_vector(rnd.RandUnsigned(reg_range_min, reg_range_max, 5));
        v_reg_adr1  := std_logic_vector(rnd.RandUnsigned(reg_range_min, reg_range_max, 5));
        v_reg_adr2  := std_logic_vector(rnd.RandUnsigned(reg_range_min, reg_range_max, 5));
        v_imm12     := std_logic_vector(rnd.RandSigned(imm12_range_min, imm12_range_max, 12));
        v_imm20     := std_logic_vector(rnd.RandSigned(imm20_range_min, imm20_range_max, 20));

        case v_instr_sel is
            when ENUM_LUI    => v_instr := rv_lui(v_reg_adr0, v_imm20);
            when ENUM_AUIPC  => v_instr := rv_auipc(v_reg_adr0, v_imm20);
            when ENUM_JAL    => v_instr := rv_jal(v_reg_adr0, v_imm20); 
            when ENUM_JALR   => v_instr := rv_jalr(v_reg_adr0, v_reg_adr1, v_imm12);
            when ENUM_BEQ    => v_instr := rv_beq(v_reg_adr0, v_reg_adr1, v_imm12);
            when ENUM_BNE    => v_instr := rv_bne(v_reg_adr0, v_reg_adr1, v_imm12);
            when ENUM_BLT    => v_instr := rv_blt(v_reg_adr0, v_reg_adr1, v_imm12);
            when ENUM_BGE    => v_instr := rv_bge(v_reg_adr0, v_reg_adr1, v_imm12);
            when ENUM_BGEU   => v_instr := rv_bgeu(v_reg_adr0, v_reg_adr1, v_imm12);
            when ENUM_LB     => v_instr := rv_lb(v_reg_adr0, v_reg_adr1, v_imm12);
            when ENUM_LH     => v_instr := rv_lh(v_reg_adr0, v_reg_adr1, v_imm12);
            when ENUM_LW     => v_instr := rv_lw(v_reg_adr0, v_reg_adr1, v_imm12);
            when ENUM_LBU    => v_instr := rv_lbu(v_reg_adr0, v_reg_adr1, v_imm12);
            when ENUM_LHU    => v_instr := rv_lhu(v_reg_adr0, v_reg_adr1, v_imm12);
            when ENUM_SB     => v_instr := rv_sb(v_reg_adr0, v_reg_adr1, v_imm12);
            when ENUM_SH     => v_instr := rv_sh(v_reg_adr0, v_reg_adr1, v_imm12);
            when ENUM_SW     => v_instr := rv_sw(v_reg_adr0, v_reg_adr1, v_imm12);
            when ENUM_ADDI   => v_instr := rv_addi(v_reg_adr0, v_reg_adr1, v_imm12);
            when ENUM_SLTI   => v_instr := rv_slti(v_reg_adr0, v_reg_adr1, v_imm12);
            when ENUM_SLTUI  => v_instr := rv_sltui(v_reg_adr0, v_reg_adr1, v_imm12);
            when ENUM_XORI   => v_instr := rv_xori(v_reg_adr0, v_reg_adr1, v_imm12);
            when ENUM_ORI    => v_instr := rv_ori(v_reg_adr0, v_reg_adr1, v_imm12);
            when ENUM_ANDI   => v_instr := rv_andi(v_reg_adr0, v_reg_adr1, v_imm12);
            when ENUM_SLLI   => v_instr := rv_slli(v_reg_adr0, v_reg_adr1, v_reg_adr2);
            when ENUM_SRLI   => v_instr := rv_srli(v_reg_adr0, v_reg_adr1, v_reg_adr2);
            when ENUM_SRAI   => v_instr := rv_srai(v_reg_adr0, v_reg_adr1, v_reg_adr2);
            when ENUM_ADD    => v_instr := rv_add(v_reg_adr0, v_reg_adr1, v_reg_adr2);
            when ENUM_SUB    => v_instr := rv_sub(v_reg_adr0, v_reg_adr1, v_reg_adr2);
            when ENUM_SLL    => v_instr := rv_sll(v_reg_adr0, v_reg_adr1, v_reg_adr2);
            when ENUM_SLT    => v_instr := rv_slt(v_reg_adr0, v_reg_adr1, v_reg_adr2);
            when ENUM_SLTU   => v_instr := rv_sltu(v_reg_adr0, v_reg_adr1, v_reg_adr2);
            when ENUM_XOR    => v_instr := rv_xor(v_reg_adr0, v_reg_adr1, v_reg_adr2);
            when ENUM_SRL    => v_instr := rv_srl(v_reg_adr0, v_reg_adr1, v_reg_adr2);
            when ENUM_SRA    => v_instr := rv_sra(v_reg_adr0, v_reg_adr1, v_reg_adr2);
            when ENUM_OR     => v_instr := rv_or(v_reg_adr0, v_reg_adr1, v_reg_adr2);
            when ENUM_AND    => v_instr := rv_and(v_reg_adr0, v_reg_adr1, v_reg_adr2);
            when ENUM_FENCE  => v_instr := rv_fence;
            when ENUM_FENCEI => v_instr := rv_fencei;
            when ENUM_ECALL  => v_instr := rv_ecall;
            when ENUM_EBREAK => v_instr := rv_ebreak;
            when ENUM_CSRRW  => v_instr := rv_csrrw(v_reg_adr0, v_reg_adr1, v_imm12);
            when ENUM_CSRRS  => v_instr := rv_csrrs(v_reg_adr0, v_reg_adr1, v_imm12);
            when ENUM_CSRRC  => v_instr := rv_csrrc(v_reg_adr0, v_reg_adr1, v_imm12);
            when ENUM_CSRRWI => v_instr := rv_csrrwi(v_reg_adr0, v_reg_adr1, v_imm12);
            when ENUM_CSRRSI => v_instr := rv_csrrsi(v_reg_adr0, v_reg_adr1, v_imm12);
            when ENUM_CSRRCI => v_instr := rv_csrrci(v_reg_adr0, v_reg_adr1, v_imm12);
            when ENUM_WFI    => v_instr := rv_wfi;
            when ENUM_MRET   => v_instr := rv_mret;
            when others      => v_instr := (others=>'0');
        end case;

    end procedure;



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
        instr(RANGE_FUNCT3) := F3_ENV;
        instr(RANGE_RD)     := (others=>'0');
        instr(RANGE_RS1)    := (others=>'0');
        instr(RANGE_IMM_I)  := F12_ECALL;
        return instr; 
    end function; 


    function rv_ebreak
        return instr32_t 
    is
        variable instr : instr32_t;
    begin
        instr(RANGE_OPCODE) := OPCODE_SYSTEM;
        instr(RANGE_FUNCT3) := F3_ENV;
        instr(RANGE_RD)     := (others=>'0');
        instr(RANGE_RS1)    := (others=>'0');
        instr(RANGE_IMM_I)  := F12_EBREAK;
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


    function rv_wfi
        return instr32_t 
    is
        variable instr : instr32_t;
    begin
        instr(RANGE_OPCODE) := OPCODE_SYSTEM;
        instr(RANGE_FUNCT3) := F3_ENV;
        instr(RANGE_RD)     := (others=>'0');
        instr(RANGE_RS1)    := (others=>'0');
        instr(RANGE_IMM_I)  := F12_WFI;
        return instr; 
    end function; 

    function rv_mret
        return instr32_t 
    is
        variable instr : instr32_t;
    begin
        instr(RANGE_OPCODE) := OPCODE_SYSTEM;
        instr(RANGE_FUNCT3) := F3_ENV;
        instr(RANGE_RD)     := (others=>'0');
        instr(RANGE_RS1)    := (others=>'0');
        instr(RANGE_IMM_I)  := F12_MRET;
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

