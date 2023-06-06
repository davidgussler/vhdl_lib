### Register Automation Project

## Rationalle

Managing a register map is a common problem for FPGA Projects. In this python 
project, I'll try to make a CLI program for managing register banks. This 
project isn't entirely necessary. All of the work intended for this program could
be done by hand, but it is tedious and error-prone. The bigger the project, the 
more usefule a program like this starts to be. 

This is also a good opportunity for me to improve my Python skills. 

## Requirements

* Command line driven progam shall give the user a means to create an modify 
  a memory map for a digital design project / module. 
* The program shall have the following as output products:
  1. Markdown file with the registers in a pretty and readable format
  2. CSV file (low priority)
  3. C Header file ("registers.h" for example) (low prioroty)
  4. VHDL package file and instantiation of wb_regs.vhd describing the register
     layout.
* The register attributes shall be created, deleted, modified, etc via the CLI
* A plaintext configurition type of file shall be used to store program data 
  between program calls. This implies that this is not going to be an "in-memory"
  program (like vivado) but rather a simpler program that runs one command at a 
  time (like git)

## Similar Projects

I'm essentially making my own dumbed-down version of this project [here](https://airhdl.com)

## Implementation Thoughts

* Python is the language choice for this project. It fits the bill well for this 
  simple, low-performance CLI app. I have also been wanting to take on a Python 
  project bigger than a simple script.

* I'm not sure what type of file to use for storing register data. JSON or XML
  might be good, but I know basically nothing about how this would work. I'm sure
  python has library that makes working with these pretty easy. 