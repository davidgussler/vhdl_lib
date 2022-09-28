## Introduction
This is a basic Synchronous FIFO module 

## Requirements
* Shall implement full, empty, almost full, and almost empty flags 
* Shall allow the user to choose the synthesis implementation of the storage
* Shall be as generic as possible where feasible
* Reading an empty fifo shall return 0
* Writing to a full fifo shall do nothing 
* Shall allow concurrent reads and writes
* Shall have variable read latency

## Design