onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /wb_xbar_tb/u_dut/i_clk
add wave -noupdate /wb_xbar_tb/u_dut/i_rst
add wave -noupdate -expand -group {Master In} /wb_xbar_tb/u_dut/i_wbs_cyc
add wave -noupdate -expand -group {Master In} /wb_xbar_tb/u_dut/i_wbs_stb
add wave -noupdate -expand -group {Master In} /wb_xbar_tb/u_dut/i_wbs_adr
add wave -noupdate -expand -group {Master In} /wb_xbar_tb/u_dut/i_wbs_wen
add wave -noupdate -expand -group {Master In} /wb_xbar_tb/u_dut/i_wbs_sel
add wave -noupdate -expand -group {Master In} /wb_xbar_tb/u_dut/i_wbs_dat
add wave -noupdate -expand -group {Master In} /wb_xbar_tb/u_dut/o_wbs_stl
add wave -noupdate -expand -group {Master In} /wb_xbar_tb/u_dut/o_wbs_ack
add wave -noupdate -expand -group {Master In} /wb_xbar_tb/u_dut/o_wbs_err
add wave -noupdate -expand -group {Master In} /wb_xbar_tb/u_dut/o_wbs_dat
add wave -noupdate -expand -group {Slave Out} /wb_xbar_tb/u_dut/o_wbm_cyc
add wave -noupdate -expand -group {Slave Out} /wb_xbar_tb/u_dut/o_wbm_stb
add wave -noupdate -expand -group {Slave Out} /wb_xbar_tb/u_dut/o_wbm_adr
add wave -noupdate -expand -group {Slave Out} /wb_xbar_tb/u_dut/o_wbm_wen
add wave -noupdate -expand -group {Slave Out} /wb_xbar_tb/u_dut/o_wbm_sel
add wave -noupdate -expand -group {Slave Out} /wb_xbar_tb/u_dut/o_wbm_dat
add wave -noupdate -expand -group {Slave Out} /wb_xbar_tb/u_dut/i_wbm_stl
add wave -noupdate -expand -group {Slave Out} /wb_xbar_tb/u_dut/i_wbm_ack
add wave -noupdate -expand -group {Slave Out} /wb_xbar_tb/u_dut/i_wbm_err
add wave -noupdate -expand -group {Slave Out} /wb_xbar_tb/u_dut/i_wbm_dat
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {0 ps} 0}
quietly wave cursor active 0
configure wave -namecolwidth 290
configure wave -valuecolwidth 247
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
WaveRestoreZoom {0 ps} {879 ps}
