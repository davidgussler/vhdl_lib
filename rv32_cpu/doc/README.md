### rv32_cpu

RISC V implementation

## Requirements 

* No hardware support for misaligned addresses 
* no support for compressed instructions
* predict not taken 
* Branch taken/not-taken and target address resolved in ID phase
* JAL target address resolved in ID phase
* JALR target address resolved in ID phase 


## Non-compliance

* doesnt trap access of CSRs that dont exit
* doesnt trap writes of RO CSRs, instead it does nothing
* only supports up to 32-bit performance counters rather than 64