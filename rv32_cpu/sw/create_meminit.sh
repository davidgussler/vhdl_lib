#!/bin/bash
################################################################################
# Author: David Gussler
# Date: Dec-03-2022
#
# Script to convert a hex memory textfile to a vhdl meminit package file.
# Useage:
#   ./create_meminit.sh <./input_file.txt> <./output_file.vhd> <memory_size_words>
#
# If the size of the init file is greater than the memory size, then the extra 
# locations in the input file will be truncated. If the input file file is smaller
# than the memory size then the extra locations in the output file will be filled
# in with zeroes.
# 
################################################################################

# Basic check of input arguments
if [[ $# -lt 3 ]]; then
    echo "Error: Not enough input arguments"
    echo 
    echo "Useage: $0 <./input_file.txt> <./output_file.vhd> <memory_depth_words>"
    echo
    exit 1
fi

# Variables
input_file=$1
output_file=$2
depth=$3
date_time=$(date)

# VHDL Header and start of file variable
read -r -d '' start_of_file << EOM
-- #############################################################################
-- #  -<< Memory Init Package >>-
-- # ===========================================================================
-- # Copyright 2022, David Gusser
-- # ===========================================================================
-- # File     : $output_file
-- # Language : VHDL '08
-- # ===========================================================================
-- # This file was generated using the tool: $0
-- # Generated on: $date_time
-- #
-- #############################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.gen_utils_pkg.all;

package ${output_file%%.*}_pkg is 

constant C_REG_ADR : slv_array_t(0 to $depth-1)(31 downto 0) := (
EOM


# VHDL end of file variable
read -r -d '' end_of_file << EOM

);
end package; 

EOM




# Functions
writeFile()
{
    echo "$start_of_file" >> "$output_file"

    num_lines=$(wc -l < ${input_file})

    if [[ $depth -lt $num_lines ]]; then
        file_read_depth=$depth
        echo "WARNING: Specified memory depth is shorter than the number of lines in the input file"
        echo "The last $(($num_lines - $depth)) line(s) will not be added the the vhdl output file"
        echo 
    elif [[ $depth -eq $num_lines ]]; then
        file_read_depth=$depth
    else 
        file_read_depth=$num_lines
        echo "WARNING: Specified memory depth is longer than the number of lines in the input file"
        echo "Adding $(($depth - $num_lines)) extra row(s) of zeroes to the end of the vhdl output file"
        echo 
    fi


    for (( i=1; i<=$depth; i++ ))
    do
        if [[ $i -le $file_read_depth ]]; then

            val=${i}p
            line=$(sed -n $val $input_file)

            if [[ $i -lt $depth ]]; then
                echo "    x\"$line\"," >> "$output_file"
            else 
                echo "    x\"$line\"" >> "$output_file"
            fi
        else 
            
            if [[ $i -lt $depth ]]; then
                echo "    x\"00000000\"," >> "$output_file"
            else 
                echo "    x\"00000000\"" >> "$output_file"
            fi
        fi
    done

    echo "$end_of_file" >> "$output_file"

}


# Main
if [[ -f $output_file ]]; then
    echo "$output_file already exists..."
    echo "abort (a) or overwrite (o)?"
    read selection

    if [[ $selection == "o" || $selection == "overwrite" ]]; then
        rm $output_file
        touch $output_file
        writeFile
        echo "Overwrote file $output_file"
        exit 0
    else
        echo "Aborting..."
        exit 0
    fi

else
    touch $output_file
    writeFile
    echo "Wrote new file $output_file"
    exit 0
fi
