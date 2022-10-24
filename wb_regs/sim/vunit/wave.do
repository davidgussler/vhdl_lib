onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /wb_regs_example_tb/clk
add wave -noupdate /wb_regs_example_tb/rst
add wave -noupdate /wb_regs_example_tb/wbs_cyc
add wave -noupdate /wb_regs_example_tb/wbs_stb
add wave -noupdate /wb_regs_example_tb/wbs_adr
add wave -noupdate /wb_regs_example_tb/wbs_wen
add wave -noupdate /wb_regs_example_tb/wbs_sel
add wave -noupdate /wb_regs_example_tb/wbs_dati
add wave -noupdate /wb_regs_example_tb/wbs_stl
add wave -noupdate /wb_regs_example_tb/wbs_ack
add wave -noupdate /wb_regs_example_tb/wbs_err
add wave -noupdate /wb_regs_example_tb/wbs_dato
add wave -noupdate /wb_regs_example_tb/in_bit0
add wave -noupdate /wb_regs_example_tb/in_vec0
add wave -noupdate /wb_regs_example_tb/in_vec1
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {269066 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 345
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 0
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
WaveRestoreZoom {91939 ps} {480216 ps}
