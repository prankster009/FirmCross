#!/bin/sh

# register hook with hwnat driver.
insmod /lib/modules/ralink/hw_nat.ko
cd /sys/class/net/
for vif in ra*; do
	iwpriv $vif set hw_nat_register=1
done

