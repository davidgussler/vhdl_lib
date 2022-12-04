### rv32_cpu

RISC V implementation

## Design Choices

* No hardware support for misaligned addresses 
* no support for compressed instructions
* predict not taken 
* Branch taken/not-taken and target address resolved in ID phase
* JAL target address resolved in ID phase
* JALR target address resolved in ID phase 
* WFI instr will be a simple nop and will not increment the instret counter


## Non-compliance

* doesnt trap access of CSRs that dont exit
* doesnt trap writes of RO CSRs, instead it does nothing
* only supports up to 32-bit performance counters rather than 64


## Notes

Something to consider: Move csr writes to writeback stage.
Forwarding should still work. 
I think hardware and software writes would both happen at that stage

Another thing to consider: May need to add a cycle of latency on memory error 
and or stall response so that timing can be improved
 