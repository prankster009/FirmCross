#!/bin/sh
# Copyright (C) 2014 Gemtek
# file: gemtek.sh


# check_uci_option <section> <option>
check_uci_option() {
	local section="$1"
	local option="$2"
	local default="$3"

	uci get $PACKAGE.$section.$option >/dev/null 2>&1
	[ "$?" != 0 ] && uci set $PACKAGE.$section.$option="$default"
}

# check_uci_option_list <section> <option> <defaults>
check_uci_option_list() {
	local section="$1"
	local option="$2"
	local defaults="$3"
	local value=`uci get $PACKAGE.$section.$option`
	
	if [ -z "$value" ]; then
		for entry in $defaults; do
			uci add_list $PACKAGE.$section.$option="$entry"
		done
	else
		[ "$value" != "$defaults" ] && {
			uci delete $PACKAGE.$section.$option
			for entry in $defaults; do
				uci add_list $PACKAGE.$section.$option="$entry"
			done
		}
	fi
}

strtok() { # <string> { <variable> [<separator>] ... }
	local tmp
	local val="$1"
	local count=0

	shift

	while [ $# -gt 1 ]; do
		tmp="${val%%$2*}"

		[ "$tmp" = "$val" ] && break

		val="${val#$tmp$2}"

		export ${NO_EXPORT:+-n} "$1=$tmp"; count=$((count+1))
		shift 2
	done

	if [ $# -gt 0 -a -n "$val" ]; then
		export ${NO_EXPORT:+-n} "$1=$val"; count=$((count+1))
	fi

	return $count
}

toLower() {
	echo $1 | sed 'y/ABCDEFGHIJKLMNOPQRSTUVWXYZ/abcdefghijklmnopqrstuvwxyz/'
}

toUpper() {
	echo $1 | sed 'y/abcdefghijklmnopqrstuvwxyz/ABCDEFGHIJKLMNOPQRSTUVWXYZ/'
}

# ex. netmask_cnt="$(get_netmask_cnt 255.255.255.0)"
#     netmask_cnt=24
get_netmask_cnt() {
	local netmask="$1"
	local netmask_cnt="0"
	local p1 p2 p3 p4
	strtok $1 p1 . p2 . p3 . p4

	for i in 1 2 4 8 16 32 64 128
	do
		for j in $p1 $p2 $p3 $p4 
		do
			[ "$(($j & $i))" != 0 ] && netmask_cnt=`expr $netmask_cnt + 1`
		done
	done
	echo "$netmask_cnt"
}

# ex. network_addr="$(get_network_addr 192.168.1.1 255.255.255.0)"
#     network_addr=192.168.1.0
get_network_addr() {
	local ipaddr="$1"
	local netmask="$2"
	local p1 p2 p3 p4
	local mask1 mask2 mask3 mask4

	strtok $ipaddr p1 . p2 . p3 . p4
	strtok $netmask mask1 . mask2 . mask3 . mask4
	echo "$(($p1 & $mask1)).$(($p2 & $mask2)).$(($p3 & $mask3)).$(($p4 & $mask4))"
}


# ex. netmask_addr="$(get_netmask_addr 24)"
#     netmask_addr=255.255.255.0
get_netmask_addr() {
	local netmask_cnt="$1"
	local p=$(($netmask_cnt / 8))
	local q=$(($netmask_cnt - (8 * $p)))
	local i="0"
	local tmp netmask_addr

	while [ "$i" -lt "$p" ]
	do
		[ -n "$netmask_addr" ] && netmask_addr="$netmask_addr".255
		[ -z "$netmask_addr" ] && netmask_addr=255
		i=$(($i + 1))
	done

	i="0"
	tmp="0"
	while [ "$i" -lt "$q" ]
	do
		highbit=$((7 - $i))
		tmp=$(($tmp + (2 ** $highbit)))
		i=$(($i + 1))
	done
	netmask_addr="$netmask_addr"."$tmp"

	i=$(($p + 1))
	while [ "$i" -lt "4" ]
	do
		netmask_addr="$netmask_addr".0
		i=$(($i + 1))
	done
	

	echo $netmask_addr
}

check_overlay() {
	local isOverlayRst="0"
	
	local wan_ip="$1"
	local wan_netmask="$2"
	local lan_ip="$3"
	local lan_netmask="$4"
	local wan_netmask_cnt="$(get_netmask_cnt $wan_netmask)"
	local lan_netmask_cnt="$(get_netmask_cnt $lan_netmask)"

	local min_netmask_cnt

	local wan_min_network_addr
	local lan_min_network_addr

	min_netmask_cnt=$lan_netmask_cnt
	if [ $wan_netmask_cnt -lt $lan_netmask_cnt ]; then
		min_netmask_cnt=$wan_netmask_cnt
	fi

	min_netmask=$(get_netmask_addr $min_netmask_cnt)
	wan_min_network_addr=$(get_network_addr $wan_ip $min_netmask)
	lan_min_network_addr=$(get_network_addr $lan_ip $min_netmask)
	#echo "$wan_min_network_addr vs. $lan_min_network_addr" 1>&2 
	
	if [ "$wan_min_network_addr" = "$lan_min_network_addr" ]; then
		isOverlayRst=1
	fi 
	
	echo $isOverlayRst
}
