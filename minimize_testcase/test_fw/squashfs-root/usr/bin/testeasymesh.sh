#!/bin/sh

CRONTAB_ROOT="/etc/crontabs/root"

test_log() {
	free_memory=$(free | grep Mem | awk '{print $4}')
	uptime=$(cat /proc/uptime | awk '{print $1}')
	lost_internet=$(ping -q -c 2 -w 2 8.8.8.8 > /dev/null 2>&1; echo $?)

	echo "TEST_LOG $uptime $lost_internet $free_memory" > /dev/console
}

set_up_agent() {
	objReq easyMeshBasic setparam enable 1
	objReq easyMeshBasic setparam deviceRole 2

	objReq autofw setparam enable 0

	objReq wan setparam proto 5
	objReq bridge setparam mode 1
	objReq bridge setparam ip "192.168.1.1"
	objReq bridge setparam netmask "255.255.255.0"

	objReq system setparam doneWizard 1

	gnvram commit

	rcConf obj easyMeshBasic

	sleep 60

	print_config
}

set_up_controller() {
	objReq easyMeshBasic setparam enable 1
	objReq easyMeshBasic setparam deviceRole 1

	objReq autofw setparam enable 0

	objReq system setparam doneWizard 1

	if [ -n "$2" ]; then
		objReq easyMeshBss setparam ssid $2
		objReq easyMeshBss setparam ssid5G "$2"_5
	fi

	gnvram commit

	rcConf obj easyMeshBasic

	sleep 60

	print_config
}

print_config() {
	echo -e "\n=~=~=~=~=~=~=~=~=~=~=~=~= mt7663 =~=~=~=~=~=~=~=~=~=~=~=~=\n"
	cat /etc/wireless/mt7663/mt7663.2.dat

	echo -e "\n=~=~=~=~=~=~=~=~=~=~=~=~= mt7603 =~=~=~=~=~=~=~=~=~=~=~=~=\n"
	cat /etc/wireless/mt7603/mt7603.dat

	echo -e "\n=~=~=~=~=~=~=~=~=~=~=~=~= mapd_cfg =~=~=~=~=~=~=~=~=~=~=~=~=\n"
	cat /etc/map/mapd_cfg

	echo -e "\n=~=~=~=~=~=~=~=~=~=~=~=~= mapd_user.cfg =~=~=~=~=~=~=~=~=~=~=~=~=\n"
	cat /etc/map/mapd_user.cfg

	echo -e "\n=~=~=~=~=~=~=~=~=~=~=~=~= 1905d.cfg =~=~=~=~=~=~=~=~=~=~=~=~=\n"
	cat /etc/map/1905d.cfg

	echo -e "\n=~=~=~=~=~=~=~=~=~=~=~=~= wts_bss_info =~=~=~=~=~=~=~=~=~=~=~=~=\n"
	cat /etc/map/wts_bss_info_config

	echo -e "\n=~=~=~=~=~=~=~=~=~=~=~=~= iwconfig =~=~=~=~=~=~=~=~=~=~=~=~=\n"
	iwconfig

	echo -e "\n=~=~=~=~=~=~=~=~=~=~=~=~= ifconfig =~=~=~=~=~=~=~=~=~=~=~=~=\n"
	ifconfig

	echo -e "\n=~=~=~=~=~=~=~=~=~=~=~=~= ps =~=~=~=~=~=~=~=~=~=~=~=~=\n"
	ps -w
}

mtk_test() {
	#iptables -t filter -F forwarding_wan_log
	#iptables -t filter -F forwarding_lan_log

	iwpriv ra0 set debug=3
	iwpriv rai0 set debug=3
	iwpriv apcli0 set debug=3
	iwpriv apclii0 set debug=3
	mapd_cli /tmp/mapd_ctrl set log_level 3
	dmesg -n 8
	mapd_cli /tmp/mapd_ctrl mib sta_seen_list
	#mapd_cli /tmp/mapd_ctrl mib sta_seen_list | grep CLIENT_MAC
	#while true; do mapd_cli /tmp/mapd_ctrl mib; sleep 2; mapd_cli /tmp/mapd_ctrl mib sta CLIENT_MAC; sleep 3; done
}

send_file_to() {
	if [ -z "$1" ]; then
		address="192.168.1.11"
	else
		address="$1"
	fi

	cd /etc/map
	tftp -pl wts_bss_info_config "$address"
	tftp -pl mapd_cfg "$address"
	tftp -pl mapd_user.cfg "$address"
	tftp -pl 1905d.cfg "$address"
	cd /etc/wireless/mt7603/; tftp -pl mt7603.dat "$address"
	cd /etc/wireless/mt7663/; tftp -pl mt7663.2.dat "$address"
	cd ~
}

show_wireless_dat() {
	files="/etc/wireless/mt7603/mt7603.dat /etc/wireless/mt7663/mt7663.2.dat"
	for file in ${files}
	do
		echo "$file is"
		cat "$file" | grep "$1"
	done
}

memory() {
	cat /proc/uptime > /dev/console

	top n 1 > /dev/console

	free > /dev/console

	ps > /dev/console

	df > /dev/console

	cat /proc/meminfo > /dev/console

	mapd_cli /tmp/mapd_ctrl dump_topology_v1
	cat /tmp/dump.txt > /dev/console

	test_log
}

show_switch() {
	switch reg r 2504
	switch reg r 94
	switch reg r 98
	switch reg r 90
	switch reg r 94
	switch reg r 98
	switch reg r 90
	switch reg r 94
	switch reg r 98
	switch reg r 90
	switch reg r 94
	switch reg r 98
	switch reg r 90
	switch reg r 94
	switch reg r 98
	switch reg r 90
	switch reg r 94
	switch reg r 98
	switch reg r 90
	switch reg r 2404
	switch reg r 94
	switch reg r 98
	switch reg r 90
	switch reg r 94
	switch reg r 98
	switch reg r 90
	switch reg r 94
	switch reg r 98
	switch reg r 90
	switch reg r 94
	switch reg r 98
	switch reg r 90
	switch reg r 94
	switch reg r 98
	switch reg r 90
}

start_test() {
	sed -i '/testeasymesh.sh/d' $CRONTAB_ROOT
	echo "*/10 * * * * /usr/bin/testeasymesh.sh memory" >> $CRONTAB_ROOT
}

meminfo() {
	while [ 1 ]
	do
		cat /proc/meminfo
		sleep $1
	done
}

action=$1

case $action in
	start)
		start_test
	;;
	agent)
		set_up_agent
	;;
	controller)
		set_up_controller
	;;
	renew)
		mapd_cli /tmp/mapd_ctrl renew
		sleep $2
		/etc/init.d/network restart
	;;
	memory)
		memory
	;;
	free)
		while [ 1 ]
		do
			free
			sleep $2
		done
	;;
	meminfo)
		meminfo "$2"
	;;
	config)
		print_config

		echo -e "\n=~=~=~=~=~=~=~=~=~=~=~=~= stasecinfo =~=~=~=~=~=~=~=~=~=~=~=~=\n"
		iwpriv ra0 show stasecinfo; iwpriv rai0 show stasecinfo; dmesg | tail -20
	;;
	topo)
		mapd_cli /tmp/mapd_ctrl dump_topology_v1
		cat /tmp/dump.txt
	;;
	iface_test)
		if [ -z "$2" ] || [ -z "$3" ]; then
			echo "iface_test <destination mac> <test times>"
			exit 1
		fi

		for i in $(seq 0 $3)
		do
			mapd_cli /tmp/mapd_ctrl tx_higher_layer_data $2 99 10 $i
			echo "send times: $i"
			sleep 30
		done
	;;
	mtk_test)
		mtk_test
	;;
	send_file_to)
		send_file_to "$2"
	;;
	show_dat)
		show_wireless_dat "$2"
	;;
	show_switch)
		show_switch
	;;
	*)
		echo "[ controller | agent | start | renew | memory | free | config | topo | iface_test | mtk_test | send_file_to | show_dat ]"
	;;
esac

