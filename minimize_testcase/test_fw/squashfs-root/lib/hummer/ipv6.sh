#!/bin/sh

. /usr/share/libubox/jshn.sh
. /lib/hummer/api.sh

ipv6_obj2uci() {
    json_load "$(objReq wan json)"
    json_select "WanP"
    json_get_vars proto
    json_select ".."

    json_load "$(objReq ipv6 json)"
    json_select "Ipv6P"
    json_get_vars dhcp6cEnable tun6rdMode ip6prefix ip6prefixlen peeraddr ip4prefixlen
    json_select ".."


    if [ "$proto" = "5" -o "$proto" = "6" ]; then
        log_info "ipv6" "exit due to the wan proto ($proto)"
        return
    fi

    uci delete network.wan6
    uci set network.wan6='interface'
    uci set network.wan6.ifname='eth1'

    if [ "$dhcp6cEnable" = "0" -a "$tun6rdMode" = "0" ]; then
        log_info "ipv6" "disabled"
        uci set network.wan6.proto='none'
        uci del network.lan.ip6addr
        uci del network.lan.ip6ifaceid
    elif [ "$dhcp6cEnable" = "1" ]; then
        log_info "ipv6" "dhcp6c enabled"
        uci set network.wan6.proto='dhcpv6'
        uct del network.lan.ip6addr
        uci set network.lan.ip6ifaceid='eui64'
    elif [ "$tun6rdMode" = "1" ]; then
        log_info "ipv6" "6rd auto enabled"
        uci set network.wan6.proto='6rd'
        uci set network.wan6.auto='0'
        uci set network.wan.iface6rd='wan6'
        uci set network.lan.ip6ifaceid='eui64'
    elif [ "$tun6rdMode" = "2" ]; then
        log_info "ipv6" "6rd manual enabled"
        uci set network.wan6.proto='6rd'
        uci set network.wan6.peeraddr="$peeraddr"
        uci set network.wan6.ip6prefix="$ip6prefix"
        uci set network.wan6.ip6prefixlen="$ip6prefixlen"
        uci set network.wan6.ip4prefixlen="$ip4prefixlen"
        uci set network.lan.ip6ifaceid='eui64'
    fi

    uci commit network
}

ipv6_start() {
    ipv6_obj2uci
    ifup -w wan6
}

ipv6_stop() {
    ifdown wan6
}

