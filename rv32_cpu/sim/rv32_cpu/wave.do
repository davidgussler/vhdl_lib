onerror {resume}
quietly virtual signal -install /rv32_cpu_tb/u_dut_cpu { (context /rv32_cpu_tb/u_dut_cpu )(mem.pc & mem.ctrl.mem_wr & mem.ctrl.mem_rd &mem.rs2_adr &mem.mem_fw_rs2_dat &mem.exe_rslt )} MEM1
quietly WaveActivateNextPane {} 0
add wave -noupdate /rv32_cpu_tb/u_dut_cpu/i_clk
add wave -noupdate /rv32_cpu_tb/u_dut_cpu/i_rst
add wave -noupdate -group All -group {Instr I/F} /rv32_cpu_tb/u_dut_cpu/o_iren
add wave -noupdate -group All -group {Instr I/F} -radix hexadecimal /rv32_cpu_tb/u_dut_cpu/o_iaddr
add wave -noupdate -group All -group {Instr I/F} /rv32_cpu_tb/u_dut_cpu/o_fencei
add wave -noupdate -group All -group {Instr I/F} /rv32_cpu_tb/u_dut_cpu/i_irdat
add wave -noupdate -group All -group {Instr I/F} /rv32_cpu_tb/u_dut_cpu/i_istall
add wave -noupdate -group All -group {Instr I/F} /rv32_cpu_tb/u_dut_cpu/i_ierror
add wave -noupdate -group All -group {Data I/F} /rv32_cpu_tb/u_dut_cpu/o_dren
add wave -noupdate -group All -group {Data I/F} /rv32_cpu_tb/u_dut_cpu/o_dwen
add wave -noupdate -group All -group {Data I/F} /rv32_cpu_tb/u_dut_cpu/o_dben
add wave -noupdate -group All -group {Data I/F} /rv32_cpu_tb/u_dut_cpu/o_daddr
add wave -noupdate -group All -group {Data I/F} /rv32_cpu_tb/u_dut_cpu/o_dwdat
add wave -noupdate -group All -group {Data I/F} /rv32_cpu_tb/u_dut_cpu/o_fence
add wave -noupdate -group All -group {Data I/F} /rv32_cpu_tb/u_dut_cpu/i_drdat
add wave -noupdate -group All -group {Data I/F} /rv32_cpu_tb/u_dut_cpu/i_dstall
add wave -noupdate -group All -group {Data I/F} /rv32_cpu_tb/u_dut_cpu/i_derror
add wave -noupdate -group All -group Other /rv32_cpu_tb/u_dut_cpu/i_ms_irq
add wave -noupdate -group All -group Other /rv32_cpu_tb/u_dut_cpu/i_me_irq
add wave -noupdate -group All -group Other /rv32_cpu_tb/u_dut_cpu/i_mt_irq
add wave -noupdate -group All -group Other /rv32_cpu_tb/u_dut_cpu/o_sleep
add wave -noupdate -group All -group Other /rv32_cpu_tb/u_dut_cpu/o_debug
add wave -noupdate -group All -group Other /rv32_cpu_tb/u_dut_cpu/i_db_halt
add wave -noupdate -group All -group Other /rv32_cpu_tb/u_dut_cpu/i_mtime
add wave -noupdate -group All -group Other /rv32_cpu_tb/ADDR_WIDTH
add wave -noupdate -group All /rv32_cpu_tb/u_dut_cpu/fet
add wave -noupdate -group All -childformat {{/rv32_cpu_tb/u_dut_cpu/dec.regfile -radix decimal -childformat {{/rv32_cpu_tb/u_dut_cpu/dec.regfile(0) -radix decimal} {/rv32_cpu_tb/u_dut_cpu/dec.regfile(1) -radix decimal} {/rv32_cpu_tb/u_dut_cpu/dec.regfile(2) -radix decimal} {/rv32_cpu_tb/u_dut_cpu/dec.regfile(3) -radix decimal} {/rv32_cpu_tb/u_dut_cpu/dec.regfile(4) -radix decimal} {/rv32_cpu_tb/u_dut_cpu/dec.regfile(5) -radix decimal} {/rv32_cpu_tb/u_dut_cpu/dec.regfile(6) -radix decimal} {/rv32_cpu_tb/u_dut_cpu/dec.regfile(7) -radix decimal} {/rv32_cpu_tb/u_dut_cpu/dec.regfile(8) -radix decimal} {/rv32_cpu_tb/u_dut_cpu/dec.regfile(9) -radix decimal} {/rv32_cpu_tb/u_dut_cpu/dec.regfile(10) -radix decimal} {/rv32_cpu_tb/u_dut_cpu/dec.regfile(11) -radix decimal} {/rv32_cpu_tb/u_dut_cpu/dec.regfile(12) -radix decimal} {/rv32_cpu_tb/u_dut_cpu/dec.regfile(13) -radix decimal} {/rv32_cpu_tb/u_dut_cpu/dec.regfile(14) -radix decimal} {/rv32_cpu_tb/u_dut_cpu/dec.regfile(15) -radix decimal} {/rv32_cpu_tb/u_dut_cpu/dec.regfile(16) -radix decimal} {/rv32_cpu_tb/u_dut_cpu/dec.regfile(17) -radix decimal} {/rv32_cpu_tb/u_dut_cpu/dec.regfile(18) -radix decimal} {/rv32_cpu_tb/u_dut_cpu/dec.regfile(19) -radix decimal} {/rv32_cpu_tb/u_dut_cpu/dec.regfile(20) -radix decimal} {/rv32_cpu_tb/u_dut_cpu/dec.regfile(21) -radix decimal} {/rv32_cpu_tb/u_dut_cpu/dec.regfile(22) -radix decimal} {/rv32_cpu_tb/u_dut_cpu/dec.regfile(23) -radix decimal} {/rv32_cpu_tb/u_dut_cpu/dec.regfile(24) -radix decimal} {/rv32_cpu_tb/u_dut_cpu/dec.regfile(25) -radix decimal} {/rv32_cpu_tb/u_dut_cpu/dec.regfile(26) -radix decimal} {/rv32_cpu_tb/u_dut_cpu/dec.regfile(27) -radix decimal} {/rv32_cpu_tb/u_dut_cpu/dec.regfile(28) -radix decimal} {/rv32_cpu_tb/u_dut_cpu/dec.regfile(29) -radix decimal} {/rv32_cpu_tb/u_dut_cpu/dec.regfile(30) -radix decimal} {/rv32_cpu_tb/u_dut_cpu/dec.regfile(31) -radix decimal}}}} -subitemconfig {/rv32_cpu_tb/u_dut_cpu/dec.regfile {-height 35 -radix decimal -childformat {{/rv32_cpu_tb/u_dut_cpu/dec.regfile(0) -radix decimal} {/rv32_cpu_tb/u_dut_cpu/dec.regfile(1) -radix decimal} {/rv32_cpu_tb/u_dut_cpu/dec.regfile(2) -radix decimal} {/rv32_cpu_tb/u_dut_cpu/dec.regfile(3) -radix decimal} {/rv32_cpu_tb/u_dut_cpu/dec.regfile(4) -radix decimal} {/rv32_cpu_tb/u_dut_cpu/dec.regfile(5) -radix decimal} {/rv32_cpu_tb/u_dut_cpu/dec.regfile(6) -radix decimal} {/rv32_cpu_tb/u_dut_cpu/dec.regfile(7) -radix decimal} {/rv32_cpu_tb/u_dut_cpu/dec.regfile(8) -radix decimal} {/rv32_cpu_tb/u_dut_cpu/dec.regfile(9) -radix decimal} {/rv32_cpu_tb/u_dut_cpu/dec.regfile(10) -radix decimal} {/rv32_cpu_tb/u_dut_cpu/dec.regfile(11) -radix decimal} {/rv32_cpu_tb/u_dut_cpu/dec.regfile(12) -radix decimal} {/rv32_cpu_tb/u_dut_cpu/dec.regfile(13) -radix decimal} {/rv32_cpu_tb/u_dut_cpu/dec.regfile(14) -radix decimal} {/rv32_cpu_tb/u_dut_cpu/dec.regfile(15) -radix decimal} {/rv32_cpu_tb/u_dut_cpu/dec.regfile(16) -radix decimal} {/rv32_cpu_tb/u_dut_cpu/dec.regfile(17) -radix decimal} {/rv32_cpu_tb/u_dut_cpu/dec.regfile(18) -radix decimal} {/rv32_cpu_tb/u_dut_cpu/dec.regfile(19) -radix decimal} {/rv32_cpu_tb/u_dut_cpu/dec.regfile(20) -radix decimal} {/rv32_cpu_tb/u_dut_cpu/dec.regfile(21) -radix decimal} {/rv32_cpu_tb/u_dut_cpu/dec.regfile(22) -radix decimal} {/rv32_cpu_tb/u_dut_cpu/dec.regfile(23) -radix decimal} {/rv32_cpu_tb/u_dut_cpu/dec.regfile(24) -radix decimal} {/rv32_cpu_tb/u_dut_cpu/dec.regfile(25) -radix decimal} {/rv32_cpu_tb/u_dut_cpu/dec.regfile(26) -radix decimal} {/rv32_cpu_tb/u_dut_cpu/dec.regfile(27) -radix decimal} {/rv32_cpu_tb/u_dut_cpu/dec.regfile(28) -radix decimal} {/rv32_cpu_tb/u_dut_cpu/dec.regfile(29) -radix decimal} {/rv32_cpu_tb/u_dut_cpu/dec.regfile(30) -radix decimal} {/rv32_cpu_tb/u_dut_cpu/dec.regfile(31) -radix decimal}}} /rv32_cpu_tb/u_dut_cpu/dec.regfile(0) {-height 35 -radix decimal} /rv32_cpu_tb/u_dut_cpu/dec.regfile(1) {-height 35 -radix decimal} /rv32_cpu_tb/u_dut_cpu/dec.regfile(2) {-height 35 -radix decimal} /rv32_cpu_tb/u_dut_cpu/dec.regfile(3) {-height 35 -radix decimal} /rv32_cpu_tb/u_dut_cpu/dec.regfile(4) {-height 35 -radix decimal} /rv32_cpu_tb/u_dut_cpu/dec.regfile(5) {-height 35 -radix decimal} /rv32_cpu_tb/u_dut_cpu/dec.regfile(6) {-height 35 -radix decimal} /rv32_cpu_tb/u_dut_cpu/dec.regfile(7) {-height 35 -radix decimal} /rv32_cpu_tb/u_dut_cpu/dec.regfile(8) {-height 35 -radix decimal} /rv32_cpu_tb/u_dut_cpu/dec.regfile(9) {-height 35 -radix decimal} /rv32_cpu_tb/u_dut_cpu/dec.regfile(10) {-height 35 -radix decimal} /rv32_cpu_tb/u_dut_cpu/dec.regfile(11) {-height 35 -radix decimal} /rv32_cpu_tb/u_dut_cpu/dec.regfile(12) {-height 35 -radix decimal} /rv32_cpu_tb/u_dut_cpu/dec.regfile(13) {-height 35 -radix decimal} /rv32_cpu_tb/u_dut_cpu/dec.regfile(14) {-height 35 -radix decimal} /rv32_cpu_tb/u_dut_cpu/dec.regfile(15) {-height 35 -radix decimal} /rv32_cpu_tb/u_dut_cpu/dec.regfile(16) {-height 35 -radix decimal} /rv32_cpu_tb/u_dut_cpu/dec.regfile(17) {-height 35 -radix decimal} /rv32_cpu_tb/u_dut_cpu/dec.regfile(18) {-height 35 -radix decimal} /rv32_cpu_tb/u_dut_cpu/dec.regfile(19) {-height 35 -radix decimal} /rv32_cpu_tb/u_dut_cpu/dec.regfile(20) {-height 35 -radix decimal} /rv32_cpu_tb/u_dut_cpu/dec.regfile(21) {-height 35 -radix decimal} /rv32_cpu_tb/u_dut_cpu/dec.regfile(22) {-height 35 -radix decimal} /rv32_cpu_tb/u_dut_cpu/dec.regfile(23) {-height 35 -radix decimal} /rv32_cpu_tb/u_dut_cpu/dec.regfile(24) {-height 35 -radix decimal} /rv32_cpu_tb/u_dut_cpu/dec.regfile(25) {-height 35 -radix decimal} /rv32_cpu_tb/u_dut_cpu/dec.regfile(26) {-height 35 -radix decimal} /rv32_cpu_tb/u_dut_cpu/dec.regfile(27) {-height 35 -radix decimal} /rv32_cpu_tb/u_dut_cpu/dec.regfile(28) {-height 35 -radix decimal} /rv32_cpu_tb/u_dut_cpu/dec.regfile(29) {-height 35 -radix decimal} /rv32_cpu_tb/u_dut_cpu/dec.regfile(30) {-height 35 -radix decimal} /rv32_cpu_tb/u_dut_cpu/dec.regfile(31) {-height 35 -radix decimal}} /rv32_cpu_tb/u_dut_cpu/dec
add wave -noupdate -group All -childformat {{/rv32_cpu_tb/u_dut_cpu/exe.rs2_adr -radix unsigned} {/rv32_cpu_tb/u_dut_cpu/exe.rdst_adr -radix unsigned} {/rv32_cpu_tb/u_dut_cpu/exe.rs2_dat -radix decimal} {/rv32_cpu_tb/u_dut_cpu/exe.rs1_adr -radix unsigned} {/rv32_cpu_tb/u_dut_cpu/exe.imm32 -radix decimal} {/rv32_cpu_tb/u_dut_cpu/exe.rs1_dat -radix decimal} {/rv32_cpu_tb/u_dut_cpu/exe.alua_dat -radix decimal} {/rv32_cpu_tb/u_dut_cpu/exe.alub_dat -radix decimal}} -subitemconfig {/rv32_cpu_tb/u_dut_cpu/exe.ctrl {-height 35} /rv32_cpu_tb/u_dut_cpu/exe.rs2_adr {-height 35 -radix unsigned} /rv32_cpu_tb/u_dut_cpu/exe.rdst_adr {-height 35 -radix unsigned} /rv32_cpu_tb/u_dut_cpu/exe.rs2_dat {-height 35 -radix decimal} /rv32_cpu_tb/u_dut_cpu/exe.rs1_adr {-height 35 -radix unsigned} /rv32_cpu_tb/u_dut_cpu/exe.imm32 {-height 35 -radix decimal} /rv32_cpu_tb/u_dut_cpu/exe.rs1_dat {-height 35 -radix decimal} /rv32_cpu_tb/u_dut_cpu/exe.alua_dat {-height 35 -radix decimal} /rv32_cpu_tb/u_dut_cpu/exe.alub_dat {-height 35 -radix decimal}} /rv32_cpu_tb/u_dut_cpu/exe
add wave -noupdate -group All -childformat {{/rv32_cpu_tb/u_dut_cpu/mem.exe_rslt -radix decimal}} -subitemconfig {/rv32_cpu_tb/u_dut_cpu/mem.exe_rslt {-height 35 -radix decimal}} /rv32_cpu_tb/u_dut_cpu/mem
add wave -noupdate -group All /rv32_cpu_tb/u_dut_cpu/wrb
add wave -noupdate -group All /rv32_cpu_tb/u_dut_cpu/haz
add wave -noupdate -group All /rv32_cpu_tb/u_dut_cpu/cnt
add wave -noupdate -group All -childformat {{/rv32_cpu_tb/neorv.iaddr -radix decimal}} -subitemconfig {/rv32_cpu_tb/neorv.iaddr {-height 35 -radix decimal}} /rv32_cpu_tb/neorv
add wave -noupdate -group DEC /rv32_cpu_tb/u_dut_cpu/dec.pc
add wave -noupdate -group DEC /rv32_cpu_tb/u_dut_cpu/dec.ctrl
add wave -noupdate -group DEC -height 35 -radix decimal /rv32_cpu_tb/u_dut_cpu/dec.regfile
add wave -noupdate -group DEC /rv32_cpu_tb/u_dut_cpu/dec.rs1_adr
add wave -noupdate -group DEC /rv32_cpu_tb/u_dut_cpu/dec.rs2_adr
add wave -noupdate -group DEC /rv32_cpu_tb/u_dut_cpu/dec.dec_fw_rs1_dat
add wave -noupdate -group DEC /rv32_cpu_tb/u_dut_cpu/dec.dec_fw_rs2_dat
add wave -noupdate -group DEC /rv32_cpu_tb/u_dut_cpu/dec.br_taken
add wave -noupdate -group DEC /rv32_cpu_tb/u_dut_cpu/dec.brt_adr
add wave -noupdate -group EXE /rv32_cpu_tb/u_dut_cpu/exe.pc
add wave -noupdate -group EXE -height 35 /rv32_cpu_tb/u_dut_cpu/exe.ctrl
add wave -noupdate -group EXE /rv32_cpu_tb/u_dut_cpu/exe.aluop
add wave -noupdate -group EXE -height 35 -radix unsigned /rv32_cpu_tb/u_dut_cpu/exe.rs1_adr
add wave -noupdate -group EXE -height 35 -radix unsigned /rv32_cpu_tb/u_dut_cpu/exe.rs2_adr
add wave -noupdate -group EXE -height 35 -radix decimal /rv32_cpu_tb/u_dut_cpu/exe.alua_dat
add wave -noupdate -group EXE -height 35 -radix decimal /rv32_cpu_tb/u_dut_cpu/exe.alub_dat
add wave -noupdate -group EXE /rv32_cpu_tb/u_dut_cpu/exe.exe_rslt
add wave -noupdate -group MEM /rv32_cpu_tb/u_dut_cpu/mem.pc
add wave -noupdate -group MEM /rv32_cpu_tb/u_dut_cpu/mem.ctrl.mem_wr
add wave -noupdate -group MEM /rv32_cpu_tb/u_dut_cpu/mem.ctrl.mem_rd
add wave -noupdate -group MEM /rv32_cpu_tb/u_dut_cpu/mem.rs2_adr
add wave -noupdate -group MEM /rv32_cpu_tb/u_dut_cpu/mem.mem_fw_rs2_dat
add wave -noupdate -group MEM -height 35 -radix decimal /rv32_cpu_tb/u_dut_cpu/mem.exe_rslt
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {4810083 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 317
configure wave -valuecolwidth 562
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ns
update
WaveRestoreZoom {0 ps} {262275 ps}
