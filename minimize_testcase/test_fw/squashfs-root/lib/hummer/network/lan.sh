#!/bin/sh


. /lib/hummer/api.sh
. /lib/hummer/state.sh
. /usr/share/libubox/jshn.sh
. /lib/functions.sh
. /lib/functions/gemtek.sh

master_lan_obj2uci() {
    log_info "network/lan" "setup uci"

    json_load "$(objReq lan json)"
    json_select "LanP"
    json_get_vars name ifnameList ipaddr netmask routername

    log_info "network/lan" "name:$name, ifname:$ifnameList, address:$ipaddr, netmask:$netmask"

    uci set network.lan.ifname=$ifnameList
    uci set network.lan.ipaddr=$ipaddr
    uci set network.lan.netmask=$netmask
    uci set network.lan.proto='static'
    uci set network.lan.gateway=''
    uci set network.lan.stp='1'
    uci set network.wan.disabled=''
    uci set network.wan6.disabled=''

    uci commit network

#checkurl=`cat /etc/hosts | grep "$ipaddr"`
#    [ -z $checkurl ] && {
#        log_info "network/lan" "setup url"
#        sed -i '/myrouter/d' /etc/hosts
#        echo "$ipaddr myrouter.local" >> /etc/hosts
#    }*/
    uci -q delete dhcp.@dnsmasq[0].address
    log_info "network/lan" "routername:$routername"
    echo "myrouter" > /tmp/mdnsdname.conf
    uci add_list dhcp.@dnsmasq[0].address="/myrouter.local/$ipaddr"
    uci add_list dhcp.@dnsmasq[0].address="/$routername/$ipaddr"
}

guest_lan_obj2uci() {
    log_info "network/guest" "setup uci"

#	main_lan_ip=`uci get network.lan.ipaddr`
#    main_lan_netmask=`uci get network.lan.netmask`
    main_lan_ip=$1
    main_lan_netmask=$2
    log_info "network/guest" "main_lan_ip:$main_lan_ip main_lan_netmask:$main_lan_netmask"



    json_load "$(objReq wlanGuest json)"
    json_select "WlanGuestT"
    local Index="1" gst_enable_2g=0 gst_enable_5g=0
    while json_get_type Type $Index && [ "$Type" = object ]; do
        local enable ssid type ifname

        json_select "$Index"
        json_get_vars enable ssid type ifname
        log_info "network/guest" "#$Index enable:$enable, ssid:$ssid"

        [ $type = "2" -a  $enable = "1" ] && gst_enable_2g=1
        [ $type = "5" -a  $enable = "1" ] && gst_enable_5g=1

        let Index=$Index+1
        json_select ".."
    done

    if [ "$gst_enable_2g" = "1"  -o "$gst_enable_5g" = "1"  ]; then
        uci set network.guest='interface'
        uci set network.guest.type='bridge'
        uci set network.guest.proto='static'
        local gst_macaddr

        [ "$gst_enable_2g" = "1"  -a "$gst_enable_5g" = "1" ] && {
            uci set network.guest.ifname='ra1 rai1'
            gst_macaddr=`ifconfig ra1 | grep HWaddr | awk '{print $5}'`
            [ "$gst_macaddr" != "" ] && uci set network.guest.macaddr=$gst_macaddr

        }
        [ "$gst_enable_2g" = "1"  -a "$gst_enable_5g" = "0" ] && {
            uci set network.guest.ifname='ra1'
            gst_macaddr=`ifconfig ra1 | grep HWaddr | awk '{print $5}'`
            [ "$gst_macaddr" != "" ] && uci set network.guest.macaddr=$gst_macaddr

        }
        [ "$gst_enable_2g" = "0"  -a "$gst_enable_5g" = "1" ] && {
            uci set network.guest.ifname='rai1'
            gst_macaddr=`ifconfig rai1 | grep HWaddr | awk '{print $5}'`
            [ "$gst_macaddr" != "" ] && uci set network.guest.macaddr=$gst_macaddr

        }

        langstIsOverlay="$(check_overlay $main_lan_ip $main_lan_netmask '192.168.33.1' '255.255.255.0')"

        if [ "$langstIsOverlay" = "1" ]; then
            uci set network.guest.ipaddr='192.168.34.1'
        else


            network_get_ipaddr WANIP wan
            network_get_subnet WANMASK wan
            if [ -n "$WANMASK" -a -n "$WANIP" ]; then

               if [ $(check_overlay $WANIP $WANMASK 192.168.33.1 255.255.255.0) = 1 ]; then

                    uci set network.guest.ipaddr='192.168.34.1'
                else
                    uci set network.guest.ipaddr='192.168.33.1'
                fi
            else
                uci set network.guest.ipaddr='192.168.33.1'
            fi

        fi

        uci set network.guest.netmask='255.255.255.0'
    else
        uci delete network.guest
    fi

    uci commit network
}

master_lan_dhcp_obj2uci() {
        json_load "$(objReq dhcps json)"
        json_select "DhcpsP"
        json_get_vars enable startIp endIp leaseTime dns1 dns2 dns3 wins1 maxClient

        echo "Setup DHCP server" > /dev/console
        echo "enable=          $enable" > /dev/console
        echo "startIp=         $startIp" > /dev/console
        echo "maxClient=       $maxClient" > /dev/console
        echo "leaseTime=       $leaseTime" > /dev/console
        echo "wins1=           $wins1" > /dev/console
        echo "dns1 dns2 dns3=  $dns1 $dns2 $dns3" > /dev/console
        ##Set up dhcp server
        if [ $enable = "0" ]; then
                uci set dhcp.lan.ignore="1"
		echo "" > /tmp/dhcp.leases
	else
		uci set dhcp.lan.ignore=""
		uci set dhcp.lan.force="1"
        fi

        uci set dhcp.lan.start=$startIp
        if [ $leaseTime = "0" ]; then
                uci set dhcp.lan.leasetime="24h"
        else
                uci set dhcp.lan.leasetime="$leaseTime"'m'
        fi
        uci set dhcp.lan.limit=$maxClient

        local dnslist="6"
        uci delete dhcp.lan.dhcp_option
        if [ x$dns1 != x"" ]; then
                dnslist=$dnslist",$dns1"
        fi
        if [ x$dns2 != x"" ]; then
                dnslist=$dnslist",$dns2"
        fi
        if [ x$dns3 != x"" ]; then
                dnslist=$dnslist",$dns3"
        fi

        [ $dnslist == "6" ] || {
                echo "DNSList=         $dnslist" > /dev/console
                uci add_list dhcp.lan.dhcp_option=$dnslist
        }

        if [ x$wins1 != x"" ]; then
                uci add_list dhcp.lan.dhcp_option="44,$wins1"
        fi

        uci commit dhcp
}

master_lan_static_dhcp_obj2uci() {
        ###Delete all reserved items
        while uci -q delete dhcp.@host[0]; do :; done

        ###Setup static reserved
        echo "Setup DCHP Reserved" > /dev/console
        json_load "$(objReq dhcpStatic json)"
        json_select "DhcpStaticT"
        local Index="1"
        while json_get_type Type $Index && [ "$Type" = object ]; do
                json_select "$Index"
                json_get_vars hostname mac assignedIp
                echo "[$Index  $hostname] mac ip =      $mac  $assignedIp" > /dev/console
                let Index=$Index+1
                json_select ".."
                uci add dhcp host
                uci set dhcp.@host[-1].name=$hostname
                uci set dhcp.@host[-1].mac=$mac
                uci set dhcp.@host[-1].ip=$assignedIp
        done
        uci commit dhcp
}

guest_lan_dhcp_obj2uci(){
    json_load "$(objReq wlanGuest json)"
    json_select "WlanGuestT"

    local Index="1" gst_enable_2g=0 gst_enable_5g=0
    while json_get_type Type $Index && [ "$Type" = object ]; do
        local enable ssid type
        json_select "$Index"
        json_get_vars enable type
        [ $type = "2" -a  $enable = "1" ] && gst_enable_2g=1
        [ $type = "5" -a  $enable = "1" ] && gst_enable_5g=1
        let Index=$Index+1
        json_select ".."
    done

    if [ "$gst_enable_2g" = "1" -o "$gst_enable_5g" = "1" ]; then
        uci set dhcp.guest=dhcp
        uci set dhcp.guest.interface=guest
        uci set dhcp.guest.start=50
        uci set dhcp.guest.limit=50
        uci set dhcp.guest.leasetime='1h'
        uci commit dhcp
    else
       uci delete dhcp.guest
       uci commit dhcp
    fi

}

lan_obj2uci() {
    json_load "$(objReq wan json)"
    json_select "WanP"
    json_get_var wanmode proto
    json_get_var wanif ifname
    json_select ".."

    json_load "$(objReq easyMeshBasic json)"
    json_select "EasyMeshBasicP"
    json_get_var easymesh_enable enable
    json_get_var easymesh_role deviceRole
    json_select ".."

    if [ "$wanmode" != "$WAN_PROTO_BRIDGE" -a "$wanmode" != "$WAN_PROTO_WLAN_BRIDGE" ]; then
        master_lan_obj2uci
        master_lan_dhcp_obj2uci

        main_lan_ip=`uci get network.lan.ipaddr`
        main_lan_netmask=`uci get network.lan.netmask`
        guest_lan_obj2uci $main_lan_ip $main_lan_netmask
        guest_lan_dhcp_obj2uci
    else
        echo "Ignore DHCP require in bridge mode" > /dev/console

        if [ "$easymesh_enable" = "1" -a "$easymesh_role" = "2" ]; then
            echo "easymesh agent, not change dhcp server setting" > /dev/console
        else
            uci set dhcp.lan.ignore="1"
            echo "" > /tmp/dhcp.leases
            uci commit dhcp
        fi

        rm -rf /tmp/mdnsdname.conf

        main_lan_ip=`ifconfig br-lan | grep 'inet addr' | cut -d: -f2 | awk '{print $1}'`
        main_lan_netmask=`ifconfig br-lan | grep 'Mask' | cut -d: -f4`

        if [ "$main_lan_ip" != "" -a "$main_lan_netmask" != "" ] ; then
            guest_lan_obj2uci $main_lan_ip $main_lan_netmask
        else
            main_lan_ip=`uci get network.lan.ipaddr`
            main_lan_netmask=`uci get network.lan.netmask`
            guest_lan_obj2uci $main_lan_ip $main_lan_netmask
        fi
        guest_lan_dhcp_obj2uci
    fi
}


