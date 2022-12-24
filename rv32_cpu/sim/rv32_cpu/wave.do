onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /rv32_cpu_tb/u_dut_cpu/i_clk
add wave -noupdate /rv32_cpu_tb/u_dut_cpu/i_rst
add wave -noupdate -group Top /rv32_cpu_tb/u_dut_cpu/o_iren
add wave -noupdate -group Top /rv32_cpu_tb/u_dut_cpu/o_iaddr
add wave -noupdate -group Top /rv32_cpu_tb/u_dut_cpu/o_fencei
add wave -noupdate -group Top /rv32_cpu_tb/u_dut_cpu/i_irdat
add wave -noupdate -group Top /rv32_cpu_tb/u_dut_cpu/i_iack
add wave -noupdate -group Top /rv32_cpu_tb/u_dut_cpu/o_dren
add wave -noupdate -group Top /rv32_cpu_tb/u_dut_cpu/o_dwen
add wave -noupdate -group Top /rv32_cpu_tb/u_dut_cpu/o_dben
add wave -noupdate -group Top /rv32_cpu_tb/u_dut_cpu/o_daddr
add wave -noupdate -group Top /rv32_cpu_tb/u_dut_cpu/o_dwdat
add wave -noupdate -group Top /rv32_cpu_tb/u_dut_cpu/o_fence
add wave -noupdate -group Top /rv32_cpu_tb/u_dut_cpu/i_drdat
add wave -noupdate -group Top /rv32_cpu_tb/u_dut_cpu/i_dack
add wave -noupdate -group Top /rv32_cpu_tb/u_dut_cpu/i_ms_irq
add wave -noupdate -group Top /rv32_cpu_tb/u_dut_cpu/i_me_irq
add wave -noupdate -group Top /rv32_cpu_tb/u_dut_cpu/i_mt_irq
add wave -noupdate -group Top /rv32_cpu_tb/u_dut_cpu/o_sleep
add wave -noupdate -group Top /rv32_cpu_tb/u_dut_cpu/o_debug
add wave -noupdate -group Top /rv32_cpu_tb/u_dut_cpu/i_db_halt
add wave -noupdate -group Top /rv32_cpu_tb/u_dut_cpu/i_mtime
add wave -noupdate -expand -group All -expand -group fet /rv32_cpu_tb/u_dut_cpu/u_fetch_unit/o_iren
add wave -noupdate -expand -group All -expand -group fet /rv32_cpu_tb/u_dut_cpu/u_fetch_unit/o_iaddr
add wave -noupdate -expand -group All -expand -group fet /rv32_cpu_tb/u_dut_cpu/u_fetch_unit/iren_en
add wave -noupdate -expand -group All -expand -group fet /rv32_cpu_tb/u_dut_cpu/u_fetch_unit/i_iack
add wave -noupdate -expand -group All -expand -group fet /rv32_cpu_tb/u_dut_cpu/u_fetch_unit/i_idata
add wave -noupdate -expand -group All -expand -group fet /rv32_cpu_tb/u_dut_cpu/u_fetch_unit/i_ierr
add wave -noupdate -expand -group All -expand -group fet /rv32_cpu_tb/u_dut_cpu/u_fetch_unit/i_jump
add wave -noupdate -expand -group All -expand -group fet /rv32_cpu_tb/u_dut_cpu/u_fetch_unit/i_jump_addr
add wave -noupdate -expand -group All -expand -group fet /rv32_cpu_tb/u_dut_cpu/u_fetch_unit/o_pc
add wave -noupdate -expand -group All -expand -group fet /rv32_cpu_tb/u_dut_cpu/u_fetch_unit/o_instr
add wave -noupdate -expand -group All -expand -group fet /rv32_cpu_tb/u_dut_cpu/u_fetch_unit/o_valid
add wave -noupdate -expand -group All -expand -group fet /rv32_cpu_tb/u_dut_cpu/u_fetch_unit/i_ready
add wave -noupdate -expand -group All -expand -group fet /rv32_cpu_tb/u_dut_cpu/u_fetch_unit/o_iaddr_ma
add wave -noupdate -expand -group All -expand -group fet /rv32_cpu_tb/u_dut_cpu/u_fetch_unit/o_iaccess_err
add wave -noupdate -expand -group All -expand -group fet /rv32_cpu_tb/u_dut_cpu/u_fetch_unit/iren_latch
add wave -noupdate -expand -group All -expand -group fet /rv32_cpu_tb/u_dut_cpu/u_fetch_unit/istall
add wave -noupdate -expand -group All -expand -group fet /rv32_cpu_tb/u_dut_cpu/u_fetch_unit/fifo_iaddr
add wave -noupdate -expand -group All -expand -group fet /rv32_cpu_tb/u_dut_cpu/u_fetch_unit/valid_not_killed
add wave -noupdate -expand -group All -expand -group fet /rv32_cpu_tb/u_dut_cpu/u_fetch_unit/fifo2_empty
add wave -noupdate -expand -group All -expand -group fet /rv32_cpu_tb/u_dut_cpu/u_fetch_unit/fifo2_idat
add wave -noupdate -expand -group All -expand -group fet /rv32_cpu_tb/u_dut_cpu/u_fetch_unit/fifo2_odat
add wave -noupdate -expand -group All -expand -group fet /rv32_cpu_tb/u_dut_cpu/u_fetch_unit/jump_latch
add wave -noupdate -expand -group All -expand -group fet /rv32_cpu_tb/u_dut_cpu/u_fetch_unit/jump_addr_latch
add wave -noupdate -expand -group All -expand -group fet /rv32_cpu_tb/u_dut_cpu/u_fetch_unit/state
add wave -noupdate -expand -group All -expand /rv32_cpu_tb/u_dut_cpu/id
add wave -noupdate -expand -group All -expand /rv32_cpu_tb/u_dut_cpu/ex
add wave -noupdate -expand -group All /rv32_cpu_tb/u_dut_cpu/m1
add wave -noupdate -expand -group All /rv32_cpu_tb/u_dut_cpu/m2
add wave -noupdate -expand -group All /rv32_cpu_tb/u_dut_cpu/wb
add wave -noupdate -expand -group All /rv32_cpu_tb/u_dut_cpu/hz
add wave -noupdate -expand -group All /rv32_cpu_tb/u_dut_cpu/ct
add wave -noupdate -group TB /rv32_cpu_tb/dut.iren
add wave -noupdate -group TB /rv32_cpu_tb/dut.iaddr
add wave -noupdate -group TB /rv32_cpu_tb/dut.irdat
add wave -noupdate -group TB /rv32_cpu_tb/iadr_dly
add wave -noupdate -group TB /rv32_cpu_tb/irack_dly
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {903979 ps} 0}
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
WaveRestoreZoom {375375 ps} {950168 ps}
