-- Simple run-thru of some of the instruction encoding fucntions to test 
-- compilation. 

library ieee;
context ieee.ieee_std_context;
library vunit_lib;
context vunit_lib.vunit_context;
use work.rv32_testbench_pkg.all;
library osvvm;
use osvvm.RandomPkg.all;

entity rv32_testbench_pkg_tb is
    generic (runner_cfg : string);
end entity;

architecture tb of rv32_testbench_pkg_tb is
begin
    -- Main TB Process ---------------------------------------------------------
    -- -------------------------------------------------------------------------
    main : process
        -- For OSVVM Random Package
        variable rnd : RandomPType;
        
        -- Length of our instruction list
        constant list_length : positive := 38;

        -- Constrains the instructions output by our random instruction generator 
        -- to the instructions listed here. We are avoiding CSRs and other privilidged
        -- instructions because this CPU differs from the golden model for these. 
        constant instr_list : instrs_array_t(0 to list_length-1) := (
            ENUM_LUI   ,
            ENUM_AUIPC ,
            ENUM_JAL   ,
            ENUM_JALR  ,
            ENUM_BEQ   ,
            ENUM_BNE   ,
            ENUM_BLT   ,
            ENUM_BGE   ,
            ENUM_BGEU  ,
            ENUM_LB    ,
            ENUM_LH    ,
            ENUM_LW    ,
            ENUM_LBU   ,
            ENUM_LHU   ,
            ENUM_SB    ,
            ENUM_SH    ,
            ENUM_SW    ,
            ENUM_ADDI  ,
            ENUM_SLTI  ,
            ENUM_SLTUI ,
            ENUM_XORI  ,
            ENUM_ORI   ,
            ENUM_ANDI  ,
            ENUM_SLLI  ,
            ENUM_SRLI  ,
            ENUM_SRAI  ,
            ENUM_ADD   ,
            ENUM_SUB   ,
            ENUM_SLL   ,
            ENUM_SLT   ,
            ENUM_SLTU  ,
            ENUM_XOR   ,
            ENUM_SRL   ,
            ENUM_SRA   ,
            ENUM_OR    ,
            ENUM_AND   ,
            ENUM_FENCE ,
            ENUM_FENCEI
        );

        variable v_rnd_instr : instr32_t; 

    begin
        test_runner_setup(runner, runner_cfg); -- Set up VUnit stuff
        rnd.InitSeed(rnd'instance_name); -- Initialize random seed

        while test_suite loop

            if run("test_0") then
                print(to_string(rv_lui  (u5(12), s20(12))));
                print(to_string(rv_auipc(u5(13), s20(500))));
                print(to_string(rv_jal  (u5(3), s20(16))));
                print(to_string(rv_jalr (u5(4), u5(30), s12(-20))));
                print(to_string(rv_bne  (u5(17), u5(22), s12(4))));
                print(to_string(rv_addi (u5(11), u5(28), s12(0))));
                print(to_string(rv_sub  (u5(18), u5(19), u5(20))));

                print(to_string(rv_lui  (12, 12)));
                print(to_string(rv_auipc(3, 500)));
                print(to_string(rv_jal  (3, 16)));
                print(to_string(rv_jalr (4, 30, -20)));
                print(to_string(rv_bne  (17, 22, 4)));
                print(to_string(rv_addi (11, 28, 0)));
                print(to_string(rv_sub  (18, 19, 20)));

                rv_random(rnd, list_length, instr_list, 0, 5, -100, 100, -100, 100, v_rnd_instr);  
                print(to_string(v_rnd_instr));
                rv_random(rnd, list_length, instr_list, 0, 5, -100, 100, -100, 100, v_rnd_instr);  
                print(to_string(v_rnd_instr));
                rv_random(rnd, list_length, instr_list, 0, 5, -100, 100, -100, 100, v_rnd_instr);  
                print(to_string(v_rnd_instr));
                rv_random(rnd, list_length, instr_list, 0, 5, -100, 100, -100, 100, v_rnd_instr);  
                print(to_string(v_rnd_instr));
                rv_random(rnd, list_length, instr_list, 0, 5, -100, 100, -100, 100, v_rnd_instr);  
                print(to_string(v_rnd_instr));
                rv_random(rnd, list_length, instr_list, 0, 5, -100, 100, -100, 100, v_rnd_instr);  
                print(to_string(v_rnd_instr));

            end if;
        end loop;

        test_runner_cleanup(runner);
    end process;

end architecture;
