#!/bin/sh

. /lib/hummer/api.sh
. /lib/hummer/state.sh
. /usr/share/libubox/jshn.sh

VLAN_IFNAME=
WAN_HOSTNAME=

#
#Set hostname for wan and lan domain name
#
wan_send_hostname() {
    json_load "$(objReq wan json)"
    json_select "WanP"
    json_get_vars hostname
    json_select ".."

    json_load "$(objReq lan json)"
    json_select LanP
    json_get_vars routername
    json_select ".."

    if [ -z "$hostname" ]; then
        WAN_HOSTNAME="$routername"
    else
        WAN_HOSTNAME="$hostname"
    fi
}

#
#
# Wan used static ip and reset lan DNS 
reset_lan_dhcp_obj2uci() {
        json_load "$(objReq dhcps json)"
        json_select "DhcpsP"
        json_get_vars dns1 dns2 dns3 wins1

        local dnslist="6"
        uci delete dhcp.lan.dhcp_option
        if [ -n "$dns1" ]; then
                dnslist=$dnslist",$dns1"
        fi
        if [ -n "$dns2" ]; then
                dnslist=$dnslist",$dns2"
        fi
        if [ -n "$dns3" ]; then
                dnslist=$dnslist",$dns3"
        fi

        [ $dnslist == "6" ] || {
                echo "Wan reset lan DNS $dnslist" > /dev/console
                uci add_list dhcp.lan.dhcp_option=$dnslist
        }

        if [ x$wins1 != x"" ]; then
                uci add_list dhcp.lan.dhcp_option="44,$wins1"
        fi

        uci commit dhcp
}

#
# WAN setup functions
#
## staticip
staticip_obj2uci() {
    log_info "network/wan" "setup staticip"

    local mac_addr
    json_load "$(objReq staticip json)"
    json_select "StaticipP"
    json_get_vars ip netmask gateway dns1 dns2 dns3 mtuMode mtu
    json_select ".."
    json_load "$(objReq wan json)"
    json_select "WanP"
    json_get_vars ifname
    json_select ".."

    mac_addr=$(uci get network.wan.macaddr)
    uci del network.wan
    uci set network.wan=interface
    uci set network.wan.proto='static'
    if [ -z "$VLAN_IFNAME" ]; then
        uci set network.wan.ifname="$ifname"
    else
        uci set network.wan.ifname="${ifname}${VLAN_IFNAME}"
    fi

    uci set network.wan.macaddr="$mac_addr"
    uci set network.wan.ipaddr="$ip"
    uci set network.wan.netmask="$netmask"
    uci set network.wan.gateway="$gateway"
    uci set network.wan.force_link='1'
    uci set network.wan.hostname="$WAN_HOSTNAME"
    uci set network.wan.clientid="$mac_addr"
    uci del network.wan.dns
	local dnslist="6"
    if [ -n "$dns1" ]; then
        uci add_list network.wan.dns="$dns1"
		dnslist=$dnslist",$dns1"
    fi
    if [ -n "$dns2" ]; then
        uci add_list network.wan.dns="$dns2"
		dnslist=$dnslist",$dns2"
    fi
    if [ -n "$dns3" ]; then
        uci add_list network.wan.dns="$dns3"
		dnslist=$dnslist",$dns3"
    fi

    [ $dnslist == "6" ] || {
		uci delete dhcp.lan.dhcp_option
        echo "Reset DNS base wan set static ip=$dnslist" > /dev/console
        uci add_list dhcp.lan.dhcp_option=$dnslist
    }

    # mtuMode "0: auto, 1: manual"
    if [ "$mtuMode" = "0" ]; then
        uci set network.wan.mtu='1500'
    else
        uci set network.wan.mtu="$mtu"
    fi
}

## dhcpc
dhcpc_obj2uci() {
    log_info "network/wan" "setup dhcpc"

    local mac_addr
    json_load "$(objReq dhcpc json)"
    json_select "DhcpcP"
    json_get_vars hostName mtuMode mtu
    json_select ".."
    json_load "$(objReq wan json)"
    json_select "WanP"
    json_get_vars ifname
    json_select ".."
    json_load "$(objReq lan json)"
    json_select "LanP"
    json_get_var routername routername

    mac_addr=$(uci get network.wan.macaddr)
    uci del network.wan
    uci set network.wan=interface
    uci set network.wan.proto='dhcp'
    if [ -z "$VLAN_IFNAME" ]; then
        uci set network.wan.ifname="$ifname"
    else
        uci set network.wan.ifname="${ifname}${VLAN_IFNAME}"
    fi
    uci set network.wan.macaddr="$mac_addr"
    uci set network.wan.peerdns='1'
    uci set network.wan.force_link='1'
    uci set network.wan.hostname="$WAN_HOSTNAME"
    uci set network.wan.clientid="$mac_addr"

    # mtuMode "0: auto, 1: manual"
    if [ "$mtuMode" = "0" ]; then
        uci set network.wan.mtu='1500'
    else
        uci set network.wan.mtu="$mtu"
    fi
}

## pppoe
pppoe_obj2uci() {
    log_info "network/wan" "setup pppoe"

    local mac_addr
    local option_var=""
    json_load "$(objReq pppoe json)"
    json_select "PppoeP"
    json_get_vars enable username password autoType ondemand maxIdleTime mtuMode mtu serviceName redialPeriod
    json_select ".."
    json_load "$(objReq wan json)"
    json_select "WanP"
    json_get_vars ifname
    json_select ".."
    json_load "$(objReq ipv6 json)"
    json_select "Ipv6P"
    json_get_vars dhcp6cEnable tun6rdMode
    json_select ".."
    json_load "$(objReq lan json)"
    json_select "LanP"
    json_get_var routername routername

    mac_addr=$(uci get network.wan.macaddr)
    uci del network.wan
    uci set network.wan=interface
    uci set network.wan.macaddr="$mac_addr"
    uci set network.wan.username="$username"
    uci set network.wan.password="$password"
    uci set network.wan.defaultroute="1"
    if [ "$dhcp6cEnable" = "0" -a "$tun6rdMode" = "0" ]; then
        uci set network.wan.ipv6="0"
    else
        uci set network.wan.ipv6="auto"
    fi
    option_var="nomppe dump usepeerdns"

    # ondemand = 0, keepalive, redialPeriod: 20~180 seconds
    # ondemand = 1, connect on demand, maxIdleTime: 1~9999 mins
    #
    # keepalive='v1 v2', v1:lcp-echo-interval v2:lcp-echo-failure, set v2=5
    #
    var="3"
    if [ $ondemand = "0" ]; then
        #uci set network.wan.keepalive="${redialPeriod} ${var}"
        uci set network.wan.keepalive="${var} ${redialPeriod}"
        uci set network.wan.keepalive_adaptive='0'
    else
        local t=$( expr 60 '*' "$maxIdleTime")
		# Add ipv6 ::1234,::0001 for local/remote LL address required for demand-dialling error in ipv6
		# remote id is temp(::0001) and than update from server
        option_var="${option_var} idle ${t} persist demand replacedefaultroute ipv6 ::1234,::0001"
        uci set network.wan.keepalive="${var} 30"
    fi

    uci set network.wan.proto='pppoe'
    if [ -z "$VLAN_IFNAME" ]; then
        uci set network.wan.ifname="$ifname"
    else
        uci set network.wan.ifname="${ifname}${VLAN_IFNAME}"
    fi
    uci set network.wan.peerdns='1'
    uci set network.wan.force_link='1'
    uci set network.wan.hostname="$WAN_HOSTNAME"
    uci set network.wan.clientid="$mac_addr"
    uci set network.wan.service="$serviceName"
    # mtuMode "0: auto, 1: manual"
    if [ "$mtuMode" = "0" ]; then
        uci set network.wan.mtu='1492'
    else
        uci set network.wan.mtu="$mtu"
    fi

    [ -f /tmp/.firstWizard ] && uci set network.wan.authfail='1' || uci set network.wan.authfail='0'

    uci set network.wan.pppd_options="$option_var"
}

## pptp
pptp_obj2uci() {
    log_info "network/wan" "setup pptp"

    local option_var=""
    local mac_addr
    json_load "$(objReq pptp json)"
    json_select "PptpP"
    json_get_vars enable username password autoObtain vpnServer ipaddr netmask gateway dns1 dns2 dns3 mtuMode mtu ondemand maxIdleTime redialPeriod
    json_select ".."
    json_load "$(objReq wan json)"
    json_select "WanP"
    json_get_vars ifname
    json_select ".."

    uci del network.vpn
    uci set network.vpn='interface'
    uci set network.vpn.proto='pptp'
    uci set network.vpn.server="$vpnServer"
    uci set network.vpn.username="$username"
    uci set network.vpn.password="$password"
    uci set network.vpn.defaultroute='1'
    uci set network.vpn.ipv6='0'
    option_var="nomppe dump usepeerdns"

    # autoObtain
    # 0: specify an ipv4 address, set static ip for wan
    # 1: Obtain ipv4 address automatically
    #
    if [ "$autoObtain" = "0" ]; then
        mac_addr=$(uci get network.wan.macaddr)
        uci del network.wan
        uci set network.wan=interface
        uci set network.wan.proto='static'
        if [ -z "$VLAN_IFNAME" ]; then
                uci set network.wan.ifname="$ifname"
        else
                uci set network.wan.ifname="${ifname}${VLAN_IFNAME}"
        fi

        uci set network.wan.macaddr="$mac_addr"
        uci set network.wan.ipaddr="$ipaddr"
        uci set network.wan.netmask="$netmask"
        uci set network.wan.gateway="$gateway"
        uci set network.wan.force_link='1'
        uci set network.wan.hostname="$WAN_HOSTNAME"
        uci set network.wan.clientid="$mac_addr"
        uci del network.wan.dns
        if [ -n "$dns1" ]; then
                uci add_list network.wan.dns="$dns1"
        fi
        if [ -n "$dns2" ]; then
                uci add_list network.wan.dns="$dns2"
        fi
        if [ -n "$dns3" ]; then
                uci add_list network.wan.dns="$dns3"
        fi

        option_var="nomppe dump"
    fi

    # ondemand = 0, keepalive, redialPeriod: 1~59 seconds
    # ondemand = 1, connect on demand, maxIdleTime: 5~999 mins
    #
    # keepalive='v1 v2', v1:lcp-echo-interval v2:lcp-echo-failure
    #
    var="3"
    if [ "$ondemand" = "0" ]; then
        #uci set network.vpn.keepalive="${redialPeriod} ${var}"
        uci set network.vpn.keepalive="${var} ${redialPeriod}"
        uci set network.vpn.keepalive_adaptive='0'
    else
        #uci set network.vpn.demand="$maxIdleTime"
        local t=$( expr 60 '*' "$maxIdleTime")
        option_var="${option_var} idle ${t} persist demand replacedefaultroute noipv6"
        uci set network.vpn.keepalive="${var} 30"
    fi

    # mtuMode "0: auto, 1: manual"
    if [ "$mtuMode" = "0" ]; then
        uci set network.wan.mtu='1460'
    else
        uci set network.wan.mtu="$mtu"
    fi
    uci set network.vpn.pppd_options="$option_var"
}

## l2tp
l2tp_obj2uci() {
    log_info "network/wan" "setup l2tp"

    local option_var=""
    json_load "$(objReq l2tp json)"
    json_select "L2tpP"
    json_get_vars enable username password vpnServer mode idleTime redialPeriod mtuMode mtu
    json_select ".."

    uci del network.vpn
    uci set network.vpn='interface'
    uci set network.vpn.proto='l2tp'
    uci set network.vpn.server="$vpnServer"
    uci set network.vpn.username="$username"
    uci set network.vpn.password="$password"
    uci set network.vpn.defaultroute='1'
    uci set network.vpn.auto='1'
    uci set network.vpn.checkup_interval='30'
    option_var="nomppe dump usepeerdns"

    # ondemand = 0, keepalive, redialPeriod: 1~59 seconds
    # ondemand = 1, connect on demand, maxIdleTime: 5~999 mins
    #
    # keepalive='v1 v2', v1:lcp-echo-interval v2:lcp-echo-failure
    #
    var="3"
    if [ "$mode" = "0" ]; then
        #uci set network.vpn.keepalive="${redialPeriod} ${var}"
        uci set network.vpn.keepalive="${var} ${redialPeriod}"
    else
        #uci set network.vpn.demand="$idleTime"
        local t=$( expr 60 '*' "$idleTime")
        option_var="${option_var} idle ${t} persist demand replacedefaultroute noipv6"
        uci set network.vpn.keepalive="${var} 30"
    fi

    # mtuMode "0: auto, 1: manual"
    if [ "$mtuMode" = "0" ]; then
        uci set network.wan.mtu='1460'
    else
        uci set network.wan.mtu="$mtu"
    fi
    uci set network.vpn.pppd_options="$option_var"

    conf="/etc/xl2tpd/xl2tpd.conf"
    conf_ppp="/etc/ppp/options.xl2tpd"
    sed -i "s/lns = .*/lns = ${vpnServer}/g" $conf
    sed -i "/user */d" $conf_ppp
    sed -i "/password */d" $conf_ppp
    echo "user ${username}" >> $conf_ppp
    echo "password ${password}" >> $conf_ppp
}

## ethernet bridge
eth_bridge_obj2uci() {
    log_info "network/wan" "setup bridge mode"

    json_load "$(objReq bridge json)"
    json_select BridgeP
    json_get_vars mode ip netmask gateway
    json_select ".."
    json_load "$(objReq lan json)"
    json_select LanP
    json_get_vars ifnameList routername
    json_select ".."
    json_load "$(objReq easyMeshBasic json)"
    json_select EasyMeshBasicP
    json_get_var easymesh enable
    json_select ".."

    if [ "$mode" = "1" ]; then
        log_info "network/wan" "bridge mode:$mode, routername:$routername ip=$ip, netmask=$netmask, gateway=$gateway"
    else
        log_info "network/wan" "bridge mode:$mode, routername:$routername"
    fi

    uci set network.wan.disabled='1'
    uci set network.wan6.disabled='1'
    uci set network.lan.stp='1'
    if [ "$easymesh" = "1" ]; then
        # don't bridge eth1 in easymesh or agent will go crazy after controller reboot
        uci set network.lan.ifname="$ifnameList"
    else
        uci set network.lan.ifname="$ifnameList $wanif"
    fi

    uci del network.lan.dns

    if [ "$mode" = "0" ]; then
        uci set network.lan.proto='dhcp'
    elif [ "$mode" = "1" ]; then
        uci set network.lan.proto='static'
        uci set network.lan.ipaddr="$ip"
        uci set network.lan.netmask="$netmask"
        uci set network.lan.gateway="$gateway"
        uci add_list network.lan.dns="$gateway"
    else
        log_info "network/wan" "unknown bridge mode!"
    fi
    #Clean dhcp lease file
    echo "" > /tmp/dhcp.leases
}

## wlan bridge
wlan_apcli_obj2dat() {
    log_info "network/wan" "setup wireless bridge"
    wireless.sh  update_wlanBridge

}

check_vlan_config() {
    json_load "$(objReq vlanEnable json)"
    json_select "VlanEnableP"
    json_get_vars vlanEnable
    json_select ".."

    if [ "$vlanEnable" = "0" ]; then
        return
    fi

    json_load "$(objReq vlan json)"
    json_select "VlanT"
    local Index="1"
    while json_get_type Type $Index && [ "$Type" = object ]; do
        json_select "$Index"
        json_get_vars descName enable portVID portTag portPriotity portService
        if [ "$enable" = "1" ]; then
            # only check wan port
            i=1
            vid=$(echo "$portVID" | cut -d ';' -f $i)
            tag=$(echo "$portTag" | cut -d ';' -f $i)
            pri=$(echo "$portPriotity" | cut -d ';' -f $i)
            service=$(echo $portService | cut -d ';' -f $i)
            if [ -n "$vid" -a -n "$tag" -a -n "$pri" ]; then
                VLAN_IFNAME=".$vid"
                return
            fi
        fi

	let Index=$Index+1
	json_select ".."
    done
}

check_ipv6_bridge() {
    if [ "$1" = "$WAN_PROTO_BRIDGE" -o "$1" = "$WAN_PROTO_WLAN_BRIDGE" ]; then
        uci del network.lan6
        uci set network.lan6='interface'
        uci set network.lan6.ifname='br-lan'
        uci set network.lan6.proto='dhcpv6'
        uci set dhcp.lan.dhcpv6='disabled'
        uci set dhcp.lan.ra='disabled'
    else
        uci del network.lan6
        uci set dhcp.lan.ra='server'
        uci set dhcp.lan.dhcpv6='server'
    fi

    uci_changes=$(uci changes network)
    if [ -n "$uci_changes" ]; then
        uci commit dhcp
        uci commit network
    fi
}

wan_obj2uci() {
    log_info "network/wan" "setup network uci config"

    json_load "$(objReq wan json)"
    json_select "WanP"
    json_get_vars ifname proto domainName
    json_select ".."

    if [ -n "$domainName" ]; then
        uci set dhcp.@dnsmasq[0].domain="$domainName"
        uci commit dhcp
    fi
    check_vlan_config
    wan_send_hostname
	reset_lan_dhcp_obj2uci
    check_ipv6_bridge "$proto"

    if [ "$proto" = "$WAN_PROTO_STATIC" ]; then
        staticip_obj2uci
    elif [ "$proto" = "$WAN_PROTO_DHCPC" ]; then
        dhcpc_obj2uci
    elif [ "$proto" = "$WAN_PROTO_PPPOE" ]; then
        pppoe_obj2uci
    elif [ "$proto" = "$WAN_PROTO_PPTP" ]; then
        dhcpc_obj2uci
        pptp_obj2uci
    elif [ "$proto" = "$WAN_PROTO_L2TP" ]; then
        dhcpc_obj2uci
        l2tp_obj2uci
    elif [ "$proto" = "$WAN_PROTO_BRIDGE" ]; then
        eth_bridge_obj2uci
    elif [ "$proto" = "$WAN_PROTO_WLAN_BRIDGE" ]; then
        wlan_apcli_obj2dat
        eth_bridge_obj2uci
    else
        log_info "network" "unknown wan mode"
    fi

    uci_changes=$(uci changes network)
    if [ -n "$uci_changes" ]; then
        uci commit network
    fi
}
