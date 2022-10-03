### Wishbone Crossbar

## Requirements

* Any master to any slave communication
* Up to 16 masters and 16 slaves 
* No slave address overlapping
  * Can enforce this via assertions of config generics
* Master may not cross slaves during one cyc transaction
  * This prevents the issue of receiving data out of order (sifferent slaves 
    may have different latencies. A single slave guarentees transactions
    are acked in order).
* One cycle latency from master to slave
* Multiple masters may access multiple slaves at the same time
* Only ONE master may access a single slave at a time
* Priority-based arbitration if many masters attempt to access a single slave
* must support 100 percent thruput
  * ie: must support one transaction per cycle
* Limmit maximum number of outstanding transactions per cyc
  * Stall master if this limmit is reached
  
## Possible Upgrades

* Add a round robin arbitration scheme as an option
* Optional register slice to any master / slave interfaces
  * Would change 1-cycle latency to 2 or 3 cycle latency
* Add a connection matrix generic for the purpose of reducing utilization
  * If a master will never need to access a slave, then that connection can 
    be optomized out. 

## Operations

1. xbar checks all masters for transaction requests
2. xbar decodes all master request addresses to determine which slave it (they)
   is (are) requesting access to.
   * can use a 2D array to describe this... for example... assume 3 masters and 
     3 slaves. if M0 requests S0 and M1 requests S2 then:

request[3][3] = 
{
       |M0 |M1 |M2 |
    ----------------
    S0 | 1 | 0 | 0 |
    S1 | 0 | 0 | 0 |
    S2 | 0 | 1 | 0 |
}

I'll use the same structure to describe grant[3][3] which will define which 
masters currently have access to which slaves

Grant and request are both determined combinatorially based on the wishbone inputs

if request and grant are both high, then the transaction is taking place
if request is high but grant is low, then the master is stalled
if request and grant are both low, then the master is idle 
there is not a situation where grant is high and request is low.

   * request gets granted if:
       1. A master of higher priority is not requesting or has not been granted 
          access to the same slave  
   * if there is an ungranted request, then that master must be stalled 

3. once the master has gotten its request thru to the slave, it is now up to the 
   slave to respond with an ack. The xbar just waits for an ack
4. xbar combinationally routes the ack and associated data (if it was a read 
   request) to the master it is connected to. 
   * It knows which master it is connected to based off of the grant[][] value



## Exceptional Conditions

When is a bus error risen, and what happens during a bus error? 

1. Error when a master is granted access to a slave and a transaction is strobed 
   into the slave, but the slave doesn't respond within X number of clockcycles
2. Error when a master tries to access an invalid slave address

xbar can respond to the master with an error code in the data bus 
this error code must be 8-bits or less since that is the minumum wishbone data 
bus width