onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /test_ram_sp_tb/i_en
add wave -noupdate -expand /test_ram_sp_tb/i_we
add wave -noupdate -radix unsigned /test_ram_sp_tb/i_adr
add wave -noupdate -radix unsigned /test_ram_sp_tb/i_dat
add wave -noupdate -radix unsigned /test_ram_sp_tb/o_dat
add wave -noupdate /test_ram_sp_tb/i_clk
add wave -noupdate /test_ram_sp_tb/tb_blip
add wave -noupdate -radix unsigned -childformat {{/test_ram_sp_tb/dut/r_ram(7) -radix unsigned} {/test_ram_sp_tb/dut/r_ram(6) -radix unsigned} {/test_ram_sp_tb/dut/r_ram(5) -radix unsigned} {/test_ram_sp_tb/dut/r_ram(4) -radix unsigned} {/test_ram_sp_tb/dut/r_ram(3) -radix unsigned} {/test_ram_sp_tb/dut/r_ram(2) -radix unsigned} {/test_ram_sp_tb/dut/r_ram(1) -radix unsigned} {/test_ram_sp_tb/dut/r_ram(0) -radix unsigned}} -expand -subitemconfig {/test_ram_sp_tb/dut/r_ram(7) {-radix unsigned} /test_ram_sp_tb/dut/r_ram(6) {-radix unsigned} /test_ram_sp_tb/dut/r_ram(5) {-radix unsigned} /test_ram_sp_tb/dut/r_ram(4) {-radix unsigned} /test_ram_sp_tb/dut/r_ram(3) {-radix unsigned} /test_ram_sp_tb/dut/r_ram(2) {-radix unsigned} /test_ram_sp_tb/dut/r_ram(1) {-radix unsigned} /test_ram_sp_tb/dut/r_ram(0) {-radix unsigned}} /test_ram_sp_tb/dut/r_ram
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {15 ns} 0}
quietly wave cursor active 1
configure wave -namecolwidth 216
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
WaveRestoreZoom {0 ns} {194 ns}
