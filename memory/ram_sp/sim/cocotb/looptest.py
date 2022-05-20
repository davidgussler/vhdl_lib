from cocotb.types import LogicArray
from cocotb.types import Range

READ_LATENCY = 1
DEPTH = 5
ADDRESS = 1
DATA_IN = LogicArray(12345678, Range(31, 'downto', 0))
NUM_WRITES = 5

# Example 1
# GOOD
arr_2d = [[LogicArray(0, Range(31, 'downto', 0)) for i in range(DEPTH)] \
    for j in range(READ_LATENCY+2)]

if (READ_LATENCY > 0):
    for i in range(NUM_WRITES):
      
        # Writes
        # Simulate latency 
        for a in range(READ_LATENCY+1):
            arr_2d[ADDRESS][a] = arr_2d[ADDRESS][a+1]
        # New data coming in
        arr_2d[ADDRESS][READ_LATENCY+1] = DATA_IN
      
        # Reads
        data_out = arr_2d[ADDRESS][0]
        print("Expected output on cycle ",i ," : ", data_out)

del(arr_2d)
print()

# Example 2
# BAD
arr_2d = [[LogicArray(0, Range(31, 'downto', 0)) for i in range(DEPTH)] \
    for j in range(READ_LATENCY+2)]

if (READ_LATENCY > 0):
    for i in range(NUM_WRITES):
      
        # Writes
        # Simulate latency 
        for a in range(READ_LATENCY+1):
            arr_2d[ADDRESS][a] = arr_2d[ADDRESS][a+1]
        # New data coming in
        arr_2d[ADDRESS][READ_LATENCY+1][31:0] = DATA_IN
      
        # Reads
        data_out = arr_2d[ADDRESS][0]
        print("Expected output on cycle ",i ," : ", data_out)

del(arr_2d)
print()

# Example 3
# GOOD
arr_2d = [[LogicArray(0, Range(31, 'downto', 0)) for i in range(DEPTH)] \
    for j in range(READ_LATENCY+2)]

if (READ_LATENCY > 0):
    for i in range(NUM_WRITES):
      
        # Writes
        # Simulate latency 
        for a in range(READ_LATENCY+1):
            arr_2d[ADDRESS][a][31:0] = arr_2d[ADDRESS][a+1]
        # New data coming in
        arr_2d[ADDRESS][READ_LATENCY+1][31:0] = DATA_IN
      
        # Reads
        data_out = arr_2d[ADDRESS][0]
        print("Expected output on cycle ",i ," : ", data_out)

del(arr_2d)
print()

# Example 4
# BAD
arr_2d = [[LogicArray(0, Range(31, 'downto', 0)) for i in range(DEPTH)] \
    for j in range(READ_LATENCY+2)]

if (READ_LATENCY > 0):
    for i in range(NUM_WRITES):
      
        # Writes
        # Simulate latency 
        for a in range(READ_LATENCY+1):
            arr_2d[ADDRESS][a][31:0] = arr_2d[ADDRESS][a+1]
        # New data coming in
        arr_2d[ADDRESS][READ_LATENCY+1][31:24] = DATA_IN[31:24]
        #arr_2d[ADDRESS][READ_LATENCY+1][23:16] = DATA_IN[23:16]
        arr_2d[ADDRESS][READ_LATENCY+1][15:8]  = DATA_IN[15:8] 
        arr_2d[ADDRESS][READ_LATENCY+1][7:0]   = DATA_IN[7:0]  
      
        # Reads
        data_out = arr_2d[ADDRESS][0]
        print("Expected output on cycle ",i ," : ", data_out)