# examp_regs Register Map

#### Description of this example register map

This is the long description for this register map. As you can clearly see, this verbose description is much more wordy than the regular description, and it is allowed to span many lines. It is optional to add this, but highly recommended.  

### examp_regs Attributes

|  |  |
| --- | --- |
| Data Width | 32 |
| Address Width | 8 |
| Reggie Version | 0.1.0 |
| Generated on | 

### examp_regs Summary

| Register Name | Array | Address Offset | Access | Description |
| --- | --- | --- | --- | --- |
| reg0 | 1 | 0x0 | RW | This is an example of a RW register
| reg1 | 2 | 0x4 to 0x8 | RW | This is an example of a RW register array
| reg2 | 1 | 0xC | RO | This is an example of an RO register
| reg3 | 1 | 0x68 | RWV | This is an example of a RWV register

## reg0

#### This is an example of a RW register

This is the long description for this 
register. As you can clearly see, this verbose description is much more wordy 
than the regular description, and it is allowed to span many lines.

### reg0 Attributes

|  |  |
| --- | --- |
| Array | 1 | 
| Address Offset | 0x0 |
| Access | RW |

### reg0 Bitfield

| 31:12 | 11:8 | 7:1 | 0 |
| --- | --- | --- | --- |
| - | fld1 | - | fld0 |

### reg0 Fields

| Bits | Field Name | Reset Value | Description |
| --- | --- | --- | --- |
| 31:12 | - | - | - |
| 11:8 | fld1 | 0 | Description of fld1<br>on: 1<br>off: 0 |
| 7:1 | - | - | - |
| 0 | fld0 | 0 | Description of fld0 |


## reg1

### This is an example of a RW register array

|  |  |
| --- | --- |
| Array | 2 | 
| Address Offset | 0x4 to 0x8 |
| Access | RW |

| 31:16 | 15:8 | 7:1 | 0 |
| --- | --- | --- | --- |
| - | fld1 | - | fld0 |

| Bits | Field Name | Reset Value | Description
| --- | --- | --- | --- |
| 31:16 | - | - | - |
| 15:8 | fld1 | 0 | Description of fld1 |
| 7:1 | - | - | - |
| 0 | fld0 | 000 |  |


## reg2

### This is an example of an RO register

|  |  |
| --- | --- |
| Array | 1 | 
| Address Offset | 0xC |
| Access | RO |

| 31:0 |
| --- |
| fld0 |

| Bits | Field Name | Reset Value | Description
| --- | --- | --- | --- |
| 31:0 | fld0 | 0 | Description of fld0 |


## reg3

### This is an example of a RWV register

|  |  |
| --- | --- |
| Array | 1 | 
| Address Offset | 0x68 |
| Access | RWV |

| 31:24 | 23:0 |
| --- | --- |
| - | fld0 |

| Bits | Field Name | Reset Value | Description
| --- | --- | --- | --- |
| 31:24 | - | - | - |
| 23:0 | fld0 | 0x23_ABCD | Description of fld0 |
