#!/bin/sh

	echo "interface config"
	brctl addbr br-lan
	modprobe /lib/modules/3.10.14/mt7615e.ko
	ifconfig ra0 up
	ifconfig rax0 up
	ifconfig eth0 up
	ifconfig eth1 up
	switch-llllw_7621.sh
	brctl addif br-lan eth0
	brctl addif br-lan rax0
	brctl addif br-lan ra0	
	ifconfig br-lan up
	ifconfig br-lan 192.168.1.1
	ifconfig eth1 192.168.2.100
	ifconfig eth0 0.0.0.0
	
	nat_router_config_7621_15d.sh
	rps_config_7621_15d.sh
	udhcpd -f /etc/udhcpd.config &
