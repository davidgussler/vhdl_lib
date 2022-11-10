-- Simple run-thru of some of the instruction encoding fucntions


library ieee;
context ieee.ieee_std_context;

library vunit_lib;
context vunit_lib.vunit_context;

use work.rv32_testbench_pkg.all;

entity rv32_testbench_pkg_tb is
    generic (runner_cfg : string);
end entity;

architecture tb of rv32_testbench_pkg_tb is
begin
    -- Main TB Process ---------------------------------------------------------
    -- -------------------------------------------------------------------------
    main : process
    begin
        test_runner_setup(runner, runner_cfg);

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
            end if;
        end loop;

        test_runner_cleanup(runner);
    end process;


end architecture;
