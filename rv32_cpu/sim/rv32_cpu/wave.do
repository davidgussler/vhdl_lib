onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /rv32_cpu_tb/u_dut_cpu/i_clk
add wave -noupdate /rv32_cpu_tb/u_dut_cpu/i_rst
add wave -noupdate -expand -group {Instr I/F} /rv32_cpu_tb/u_dut_cpu/o_iren
add wave -noupdate -expand -group {Instr I/F} /rv32_cpu_tb/u_dut_cpu/o_iaddr
add wave -noupdate -expand -group {Instr I/F} /rv32_cpu_tb/u_dut_cpu/o_fencei
add wave -noupdate -expand -group {Instr I/F} /rv32_cpu_tb/u_dut_cpu/i_irdat
add wave -noupdate -expand -group {Instr I/F} /rv32_cpu_tb/u_dut_cpu/i_istall
add wave -noupdate -expand -group {Instr I/F} /rv32_cpu_tb/u_dut_cpu/i_ierror
add wave -noupdate -group {Data I/F} /rv32_cpu_tb/u_dut_cpu/o_dren
add wave -noupdate -group {Data I/F} /rv32_cpu_tb/u_dut_cpu/o_dwen
add wave -noupdate -group {Data I/F} /rv32_cpu_tb/u_dut_cpu/o_dben
add wave -noupdate -group {Data I/F} /rv32_cpu_tb/u_dut_cpu/o_daddr
add wave -noupdate -group {Data I/F} /rv32_cpu_tb/u_dut_cpu/o_dwdat
add wave -noupdate -group {Data I/F} /rv32_cpu_tb/u_dut_cpu/o_fence
add wave -noupdate -group {Data I/F} /rv32_cpu_tb/u_dut_cpu/i_drdat
add wave -noupdate -group {Data I/F} /rv32_cpu_tb/u_dut_cpu/i_dstall
add wave -noupdate -group {Data I/F} /rv32_cpu_tb/u_dut_cpu/i_derror
add wave -noupdate -expand -group Other /rv32_cpu_tb/u_dut_cpu/i_ms_irq
add wave -noupdate -expand -group Other /rv32_cpu_tb/u_dut_cpu/i_me_irq
add wave -noupdate -expand -group Other /rv32_cpu_tb/u_dut_cpu/i_mt_irq
add wave -noupdate -expand -group Other /rv32_cpu_tb/u_dut_cpu/o_sleep
add wave -noupdate -expand -group Other /rv32_cpu_tb/u_dut_cpu/o_debug
add wave -noupdate -expand -group Other /rv32_cpu_tb/u_dut_cpu/i_db_halt
add wave -noupdate -expand -group Other /rv32_cpu_tb/u_dut_cpu/i_mtime
add wave -noupdate -expand /rv32_cpu_tb/u_dut_cpu/fet
add wave -noupdate -expand /rv32_cpu_tb/u_dut_cpu/dec
add wave -noupdate /rv32_cpu_tb/u_dut_cpu/exe
add wave -noupdate /rv32_cpu_tb/u_dut_cpu/mem
add wave -noupdate /rv32_cpu_tb/u_dut_cpu/wrb
add wave -noupdate -expand /rv32_cpu_tb/u_dut_cpu/haz
add wave -noupdate /rv32_cpu_tb/u_dut_cpu/cnt
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {187909 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 285
configure wave -valuecolwidth 217
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
WaveRestoreZoom {137838 ps} {400996 ps}
