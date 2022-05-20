from cocotb.types import LogicArray
from cocotb.types import Array
from cocotb.types import Range
from cocotb.types import Logic
from numpy import array2string

READ_LATENCY = 2
DEPTH = 5
ADDRESS = 2
DATA_IN = LogicArray(12345678, Range(31, 'downto', 0))
NUM_WRITES = 5

# Example 1
# GOOD
# arr_2d = [[LogicArray(0, Range(31, 'downto', 0)) for i in range(DEPTH)] for j in range(READ_LATENCY+2)]
      
# arr_2d[0][4][31:0] = DATA_IN[31:0]

# # print(arr_2d)

arr = LogicArray(0, Range(31, 'downto', 0))

#arr2d = Array([arr for i in range(DEPTH)], Range(DEPTH-1, 'downto', 0))

arr2d = [LogicArray(0, Range(31, 'downto', 0)) for i in range(DEPTH)]

arr2 = LogicArray(1234, Range(31, 'downto', 0))


for i in range(DEPTH):
    print(i," : ",arr2d[i])

print()
arr2d[1] = LogicArray(12345, Range(31, 'downto', 0))

for i in range(DEPTH):
    print(i," : ",arr2d[i])

print()
arr2d[2][8:0] = LogicArray(12, Range(8, 'downto', 0))

for i in range(DEPTH):
    print(i," : ",arr2d[i])

print()

arr2d[3] = arr2 
for i in range(DEPTH):
    print(i," : ",arr2d[i])

print()

