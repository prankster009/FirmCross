#!/bin/sh

# register hook with hwnat driver.
cd /sys/class/net/
for vif in ra*; do
	iwpriv $vif set hw_nat_register=0
done
rmmod hw_nat.ko

