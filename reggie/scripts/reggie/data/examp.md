# examp_regs

Description of this example register map

### Register Map Settings

|  |  |
| --- | --- |
| Data Width | 32 |
| Address Width | 8 |
| Reggie Version | 0.1.0 |
|  |  |

### Register Space

| Address Offset | Register Name | Access | Description |
| --- | --- | --- | --- |
| 0x0 | reg0 | RW | This is an example of a RW register

## reg0

This is an example of a RW register. This is the long description for this 
register. As you can clearly see, this verbose description is much more wordy 
than the regular description, and it is allowed to span many lines.

|  |  |
| --- | --- |
| Address Offset | 0x0 |
| Reset Value | 0x0 |
| Access | RW |
|  |  |

| 31:9 | 8:5 | 4:1 | 0 |
| --- | --- | --- | --- |
| - | fld1 | - | fld0 |

| Bits | Field Name | Reset Value | Description
| --- | --- | --- | --- |
| 8:5 | fld1 | 0 | Description of fld1 |
| 0 | fld0 | 0 | Description of fld0 |
