#!bin/bash

vlib work
vcom -work work <loop to read vhdl source files>
vmap -c 
set MODELSIM=<pwd>/modelsim.ini
# if gui option 
vsim -do <wavefrom_config>; "run -all"
# else if no gui option 
vsim -c -do "run -all"