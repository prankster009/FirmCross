#!/bin/sh

. /usr/share/libubox/jshn.sh
. /lib/hummer/api.sh

routing_obj2uci() {
    log_info "network/routing" "setup static route"

    ###Delete all reserved items
    while uci -q delete network.@route[0]; do :; done

    json_load "$(objReq staticRoute json)"
    json_select "StaticRouteT"
    local Index="1"
    while json_get_type Type $Index && [ "$Type" = object ]; do
        json_select "$Index"
        json_get_vars desc dstIp dstNetmask gateway ifname
        log_info "network/routing" "sr#$Index desc:$desc, dstIp:$dstIp, dstNetmask:$dstNetmask, gateway:$gateway, ifname:$ifname"
        let Index=$Index+1
        json_select ".."

        uci add network route
        uci set network.@route[-1].interface=$ifname
        uci set network.@route[-1].target=$dstIp
        uci set network.@route[-1].netmask=$dstNetmask
        uci set network.@route[-1].gateway=$gateway
    done
}
