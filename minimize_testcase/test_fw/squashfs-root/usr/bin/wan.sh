#!/bin/sh
# Copyright (C) 2014 Gemtek

. /lib/hummer/network/wan.sh
. /etc/init.d/network

bridgeFlag="0"
Proto="1"
usage(){
    echo "$0 [ start ]"
    exit 1
}

## bridge check
wan_setup_param() {
        json_load "$(objReq wan json)"
        json_select WanP
        json_get_var Hostname hostname
        json_get_var Ifname ifname
        json_get_var Proto proto
        json_get_var Domainname domainName

        #check if change about bridge
        if_list=`uci get network.lan.ifname`
        case $if_list in
                *$Ifname*)
                        bridgeFlag="1";;
        esac
}

start_wan() {
        ifup -w wan

        /etc/init.d/system reload
        /etc/init.d/dnsmasq reload

        if [ $Proto = "3" ] || [ $Proto = "4" ]; then
            ifup vpn
        fi
        check_wan_monitor
}

stop_wan() {
        ifdown vpn
        ifdown lan6
        ifdown -w wan

        /etc/init.d/xl2tpd stop
        killall -9 pppd 2&>1 > /dev/null
        killall -9 udhcpc 2&>1 > /dev/null

        vpn="$(uci get network.vpn)"
        if [ ! -z "$vpn" ]; then
                uci del network.vpn
                uci commit network
        fi

        lan6="$(uci get network.lan6)"
        if [ ! -z "$lan6" ]; then
                uci del network.lan6
                uci commit network
        fi
}

action=$1
case "$action" in
    start)
        wan_setup_param
        wan_obj2uci
        log "bridgeFlag=$bridgeFlag"
    	if [ $bridgeFlag = "1" ]; then
                /etc/init.d/network restart
                ifup lan6
        else
                start_wan
	    fi
	;;
    stop)
       	stop_wan
	;;
    *)
        usage ;;
esac

