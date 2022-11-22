-- ###############################################################################################
-- # << RV32 Control Unit >> #
-- *********************************************************************************************** 
-- Copyright 2022
-- *********************************************************************************************** 
-- File     : rv32_control.vhd
-- Author   : David Gussler - davidnguss@gmail.com 
-- Language : VHDL '08
-- History  :  Date      | Version | Comments 
--            --------------------------------
--            01-03-2022 | 1.0     | Initial 
-- *********************************************************************************************** 
-- Description : 
--   Useful description describing the description to describe the module
-- Generics

-- ###############################################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.rv32_pkg.all; 

entity rv32_control is
    port (
        i_opcode : in std_logic_vector(6 downto 0);
        o_ctrl   : out ctrl_t
    );
end entity;

architecture rtl of rv32_control is

begin
    prc_cntrl : process (all)
    begin
        case i_opcode is
        when OPCODE_LUI => 
            o_ctrl.reg_wr   <= '1';
            o_ctrl.wrb_sel  <= WRB_SEL_ALU;
            o_ctrl.mem_wr   <= '0';
            o_ctrl.mem_rd   <= '0'; 
            o_ctrl.alu_ctrl <= ALU_CTRL_ADD; 
            o_ctrl.alu_a    <= ALU_A_ZERO;
            o_ctrl.alu_b    <= ALU_B_IMM32;
            o_ctrl.jal      <= '0';
            o_ctrl.jalr     <= '0';
            o_ctrl.branch   <= '0';
            o_ctrl.imm_type <= UTYPE;
  
        when OPCODE_AUIPC => 
            o_ctrl.reg_wr   <= '1';
            o_ctrl.wrb_sel  <= WRB_SEL_ALU;
            o_ctrl.mem_wr   <= '0';
            o_ctrl.mem_rd   <= '0';
            o_ctrl.alu_ctrl <= ALU_CTRL_ADD; 
            o_ctrl.alu_a    <= ALU_A_PC;
            o_ctrl.alu_b    <= ALU_B_IMM32;
            o_ctrl.jal      <= '0';
            o_ctrl.jalr     <= '0';
            o_ctrl.branch   <= '0';
            o_ctrl.imm_type <= UTYPE;  
  
        when OPCODE_ALUI  =>
            o_ctrl.reg_wr   <= '1';
            o_ctrl.wrb_sel  <= WRB_SEL_ALU;
            o_ctrl.mem_wr   <= '0';
            o_ctrl.mem_rd   <= '0';
            o_ctrl.alu_ctrl <= ALU_CTRL_ALU;
            o_ctrl.alu_a    <= ALU_A_RS1;
            o_ctrl.alu_b    <= ALU_B_IMM32;
            o_ctrl.jal      <= '0';
            o_ctrl.jalr     <= '0';
            o_ctrl.branch   <= '0';
            o_ctrl.imm_type <= ITYPE;
            o_ctrl.exe_unit <= INT_ALU_UNIT; 
  
        when OPCODE_ALUR  =>
            o_ctrl.reg_wr   <= '1';
            o_ctrl.wrb_sel  <= WRB_SEL_ALU;
            o_ctrl.mem_wr   <= '0';
            o_ctrl.mem_rd   <= '0';
            o_ctrl.alu_ctrl <= ALU_CTRL_ALU;
            o_ctrl.alu_a    <= ALU_A_RS1;
            o_ctrl.alu_b    <= ALU_B_RS2;
            o_ctrl.jal      <= '0';
            o_ctrl.jalr     <= '0';
            o_ctrl.branch   <= '0';
            o_ctrl.imm_type <= RTYPE;
            o_ctrl.exe_unit <= INT_ALU_UNIT; 
  
        when OPCODE_JAL  =>  
            o_ctrl.reg_wr   <= '1';
            o_ctrl.wrb_sel  <= WRB_SEL_PC4; 
            o_ctrl.mem_wr   <= '0';
            o_ctrl.mem_rd   <= '0';
            o_ctrl.alu_ctrl <= '-';  
            o_ctrl.alu_a    <= b"--";   
            o_ctrl.alu_b    <= '-'; 
            o_ctrl.jal      <= '1';
            o_ctrl.jalr     <= '0';
            o_ctrl.branch   <= '0';
            o_ctrl.imm_type <= JTYPE; 
            o_ctrl.exe_unit <= b"--";  
  
        when OPCODE_JALR =>  
            o_ctrl.reg_wr   <= '1';
            o_ctrl.wrb_sel  <= WRB_SEL_PC4; 
            o_ctrl.mem_wr   <= '0';
            o_ctrl.mem_rd   <= '0';
            o_ctrl.alu_ctrl <= '-';  
            o_ctrl.alu_a    <= b"--";  
            o_ctrl.alu_b    <= '-'; 
            o_ctrl.jal      <= '0';
            o_ctrl.jalr     <= '1';
            o_ctrl.branch   <= '0';
            o_ctrl.imm_type <= ITYPE;  
            o_ctrl.exe_unit <= b"--";  
  
        when OPCODE_BRANCH =>
            o_ctrl.reg_wr   <= '0';
            o_ctrl.wrb_sel  <= b"--";
            o_ctrl.mem_wr   <= '0';
            o_ctrl.mem_rd   <= '0';
            o_ctrl.alu_ctrl <= '-';  
            o_ctrl.alu_a    <= b"--";
            o_ctrl.alu_b    <= '-'; 
            o_ctrl.jal      <= '0';
            o_ctrl.jalr     <= '0';
            o_ctrl.branch   <= '1';
            o_ctrl.imm_type <= BTYPE; 
            o_ctrl.exe_unit <= b"--";  
  
        when OPCODE_LOAD =>
            o_ctrl.reg_wr   <= '1';
            o_ctrl.wrb_sel  <= WRB_SEL_MEM;
            o_ctrl.mem_wr   <= '0';
            o_ctrl.mem_rd   <= '1';
            o_ctrl.alu_ctrl <= ALU_CTRL_ADD;
            o_ctrl.alu_a    <= ALU_A_RS1;
            o_ctrl.alu_b    <= ALU_B_IMM32;
            o_ctrl.jal      <= '0';
            o_ctrl.jalr     <= '0';
            o_ctrl.branch   <= '0';
            o_ctrl.imm_type <= ITYPE;
            o_ctrl.exe_unit <= INT_ALU_UNIT; 
  
        when OPCODE_STORE =>
            o_ctrl.reg_wr   <= '0';
            o_ctrl.wrb_sel  <= b"--";
            o_ctrl.mem_wr   <= '1';
            o_ctrl.mem_rd   <= '0';
            o_ctrl.alu_ctrl <= ALU_CTRL_ADD;
            o_ctrl.alu_a    <= ALU_A_RS1;
            o_ctrl.alu_b    <= ALU_B_IMM32;
            o_ctrl.jal      <= '0';
            o_ctrl.jalr     <= '0';
            o_ctrl.branch   <= '0';
            o_ctrl.imm_type <= STYPE; 
            o_ctrl.exe_unit <= INT_ALU_UNIT; 
  
        when OPCODE_FENCE =>
            o_ctrl.reg_wr   <= '0';
            o_ctrl.wrb_sel  <= b"--";
            o_ctrl.mem_wr   <= '0';
            o_ctrl.mem_rd   <= '0';
            o_ctrl.alu_ctrl <= '-';  
            o_ctrl.alu_a    <= b"--";
            o_ctrl.alu_b    <= '-'; 
            o_ctrl.jal      <= '0';
            o_ctrl.jalr     <= '0';
            o_ctrl.branch   <= '0';
            o_ctrl.imm_type <= b"---"; 
            o_ctrl.exe_unit <= b"--"; 
            o_ctrl.fence    <= '1';
  
        when OPCODE_SYSTEM =>
            o_ctrl.reg_wr   <= '1';
            o_ctrl.wrb_sel  <= WRB_SEL_CSR;
            o_ctrl.mem_wr   <= '0';
            o_ctrl.mem_rd   <= '0';
            o_ctrl.alu_ctrl <= '-';  
            o_ctrl.alu_a    <= b"--";
            o_ctrl.alu_b    <= '-'; 
            o_ctrl.jal      <= '0';
            o_ctrl.jalr     <= '0';
            o_ctrl.branch   <= '0';
            o_ctrl.imm_type <= ITYPE; 
            o_ctrl.exe_unit <= b"--"; 
  
        when others =>
            o_ctrl.reg_wr   <= '0';
            o_ctrl.wrb_sel  <= b"--";
            o_ctrl.mem_wr   <= '0';
            o_ctrl.mem_rd   <= '0';
            o_ctrl.alu_ctrl <= '-';  
            o_ctrl.alu_a    <= b"--";
            o_ctrl.alu_b    <= '-'; 
            o_ctrl.jal      <= '0';
            o_ctrl.jalr     <= '0';
            o_ctrl.branch   <= '0';
            o_ctrl.imm_type <= b"---"; 
            o_ctrl.exe_unit <= b"--"; 
            o_ctrl.illegal  <= '1'; 
        end case; 
    end process;
end architecture rtl; 




