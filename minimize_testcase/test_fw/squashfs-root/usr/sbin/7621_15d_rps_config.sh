#!/bin/sh

	echo "irq/rps config"
	echo 2 > /proc/irq/3/smp_affinity  
	echo 4 > /proc/irq/4/smp_affinity
	echo 8 > /proc/irq/24/smp_affinity #PCIe1
	echo 3 > /sys/class/net/ra0/queues/rx-0/rps_cpus
	echo 3 > /sys/class/net/rax0/queues/rx-0/rps_cpus
	echo 5 > /sys/class/net/eth0/queues/rx-0/rps_cpus
	echo 5 > /sys/class/net/eth1/queues/rx-0/rps_cpus
#	echo 8 >  /proc/irq/4/smp_affinity
