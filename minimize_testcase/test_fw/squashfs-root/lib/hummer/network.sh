#!/bin/sh

. /lib/hummer/network/lan.sh
. /lib/hummer/network/wan.sh
. /lib/hummer/network/routing.sh

check_manufacture_mode() {
	MFG_MODE=$(gcontrol uenv get ManufactureMode | awk -F"=" '{print $2}')
	[ $MFG_MODE = "1" ] && {
		echo "======================================================" > /dev/console
		echo "================Starting Manufcture Mode==============" > /dev/console
		echo "======================================================" > /dev/console
		uci set network.wan.disabled='1'
		uci set network.wan6.disabled='1'
		uci set network.lan.ifname="eth0 eth1"
		uci set network.lan.proto='static'
		uci set network.lan.ipaddr="192.168.1.1"
		uci set network.lan.netmask="255.255.255.0"
		uci set network.lan.gateway="192.168.1.123"
		uci commit network
	}
	[ $MFG_MODE = "2" ] && {
                echo "======================================================" > /dev/console
		echo "================Starting Golden Mode==================" > /dev/console
		echo "======================================================" > /dev/console
		log_info "Starting Golden Mode"
		uci set network.wan.disabled='1'
		uci set network.wan6.disabled='1'
		uci set network.lan.ifname="eth0 eth1"
		uci set network.lan.proto='static'
		uci set network.lan.ipaddr="192.168.1.123"
		uci set network.lan.netmask="255.255.255.0"
		uci set network.lan.gateway="192.168.1.1"
		uci commit network
	}
	[ $MFG_MODE = "3" ] && {
		echo "===============================================================" > /dev/console
		echo "==============Starting EasyMesh Certification Mode=============" > /dev/console
		echo "===============================================================" > /dev/console

		objReq easyMeshBasic setparam enable 1
		objReq autofw setparam enable 0
		objReq system setparam doneWizard 1
		gnvram commit

		br0_mac=$(gcontrol di get hw_mac_addr | awk -F "=" '{print $2}')
		br0_mac_last_byte="0x${br0_mac##*:}"
		br0_mac_first_five_str=${br0_mac%:*}
		al_mac_last_byte=$(printf "%02X" $((br0_mac_last_byte ^ 0xAA)))
		al_mac="$br0_mac_first_five_str:$al_mac_last_byte"
		uci set network.lan.macaddr="$br0_mac_first_five_str:$al_mac_last_byte"

		uci set network.lan.ifname=eth0
		uci set network.wan.ifname=eth1
		uci set network.wan6.ifname=eth1

		uci set dhcp.lan.ignore='1'
		uci set firewall.@zone[1].input='ACCEPT'
		uci set firewall.@zone[1].forward='ACCEPT'
		uci set network.wan6.proto='static'
		uci set network.wan.proto='static'
		uci set network.lan.proto='static'
		uci set network.lan.ipaddr='192.165.100.200'
		uci set network.lan.netmask='255.255.255.0'
		uci set network.wan.ipaddr='192.168.250.200'
		uci set network.wan.netmask='255.255.255.0'
		uci commit
	}
}

network_obj2uci() {
    lan_obj2uci
    wan_obj2uci
    routing_obj2uci
}

