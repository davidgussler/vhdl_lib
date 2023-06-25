onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /skid_buff_tb/clk
add wave -noupdate /skid_buff_tb/rst
add wave -noupdate /skid_buff_tb/rstn
add wave -noupdate /skid_buff_tb/stall
add wave -noupdate /skid_buff_tb/start
add wave -noupdate /skid_buff_tb/done
add wave -noupdate -divider In
add wave -noupdate /skid_buff_tb/o_ready
add wave -noupdate /skid_buff_tb/i_valid
add wave -noupdate /skid_buff_tb/i_data
add wave -noupdate -divider Out
add wave -noupdate /skid_buff_tb/i_ready
add wave -noupdate /skid_buff_tb/o_valid
add wave -noupdate /skid_buff_tb/o_data
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {64 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 150
configure wave -valuecolwidth 216
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
WaveRestoreZoom {0 ps} {959 ps}
