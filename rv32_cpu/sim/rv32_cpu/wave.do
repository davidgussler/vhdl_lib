onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /rv32_cpu_tb/u_dut_cpu/i_clk
add wave -noupdate /rv32_cpu_tb/u_dut_cpu/i_rst
add wave -noupdate -group Top /rv32_cpu_tb/u_dut_cpu/o_iren
add wave -noupdate -group Top /rv32_cpu_tb/u_dut_cpu/o_iaddr
add wave -noupdate -group Top /rv32_cpu_tb/u_dut_cpu/o_fencei
add wave -noupdate -group Top /rv32_cpu_tb/u_dut_cpu/i_irdat
add wave -noupdate -group Top /rv32_cpu_tb/u_dut_cpu/i_iack
add wave -noupdate -group Top /rv32_cpu_tb/u_dut_cpu/i_ierror
add wave -noupdate -group Top /rv32_cpu_tb/u_dut_cpu/o_dren
add wave -noupdate -group Top /rv32_cpu_tb/u_dut_cpu/o_dwen
add wave -noupdate -group Top /rv32_cpu_tb/u_dut_cpu/o_dben
add wave -noupdate -group Top /rv32_cpu_tb/u_dut_cpu/o_daddr
add wave -noupdate -group Top /rv32_cpu_tb/u_dut_cpu/o_dwdat
add wave -noupdate -group Top /rv32_cpu_tb/u_dut_cpu/o_fence
add wave -noupdate -group Top /rv32_cpu_tb/u_dut_cpu/i_drdat
add wave -noupdate -group Top /rv32_cpu_tb/u_dut_cpu/i_dack
add wave -noupdate -group Top /rv32_cpu_tb/u_dut_cpu/i_derror
add wave -noupdate -group Top /rv32_cpu_tb/u_dut_cpu/i_ms_irq
add wave -noupdate -group Top /rv32_cpu_tb/u_dut_cpu/i_me_irq
add wave -noupdate -group Top /rv32_cpu_tb/u_dut_cpu/i_mt_irq
add wave -noupdate -group Top /rv32_cpu_tb/u_dut_cpu/o_sleep
add wave -noupdate -group Top /rv32_cpu_tb/u_dut_cpu/o_debug
add wave -noupdate -group Top /rv32_cpu_tb/u_dut_cpu/i_db_halt
add wave -noupdate -group Top /rv32_cpu_tb/u_dut_cpu/i_mtime
add wave -noupdate -expand -group All /rv32_cpu_tb/u_dut_cpu/pc
add wave -noupdate -expand -group All -expand /rv32_cpu_tb/u_dut_cpu/f1
add wave -noupdate -expand -group All -expand /rv32_cpu_tb/u_dut_cpu/f2
add wave -noupdate -expand -group All /rv32_cpu_tb/u_dut_cpu/id
add wave -noupdate -expand -group All /rv32_cpu_tb/u_dut_cpu/ex
add wave -noupdate -expand -group All /rv32_cpu_tb/u_dut_cpu/m1
add wave -noupdate -expand -group All /rv32_cpu_tb/u_dut_cpu/m2
add wave -noupdate -expand -group All /rv32_cpu_tb/u_dut_cpu/wb
add wave -noupdate -expand -group All /rv32_cpu_tb/u_dut_cpu/hz
add wave -noupdate -expand -group All /rv32_cpu_tb/u_dut_cpu/ct
add wave -noupdate -expand -group TB /rv32_cpu_tb/dut.iren
add wave -noupdate -expand -group TB /rv32_cpu_tb/dut.iaddr
add wave -noupdate -expand -group TB /rv32_cpu_tb/dut.irdat
add wave -noupdate -expand -group TB /rv32_cpu_tb/iadr_dly
add wave -noupdate -expand -group TB /rv32_cpu_tb/irack_dly
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {185443 ps} 0}
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
WaveRestoreZoom {0 ps} {5255250 ps}
