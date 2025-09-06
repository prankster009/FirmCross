#!/bin/sh

. /usr/share/libubox/jshn.sh
. /lib/functions/network.sh
. /lib/functions.sh

log() {
       echo "[Mac Clone] $@" > /dev/console
}

start_macClone() {

        json_load "$(objReq macclone json)"
        json_select MacCloneP
        json_get_var enable_var enable
        json_get_var mac_addr macAddress

        if [ "$enable_var" = 1 ]; then
            uci set network.wan.macaddr=$mac_addr
            log "do mac clone"
        else
            OrigMAC="$(uci get network.lan.macaddr| cut -c 1-15)"
            LastMAC="$(uci get network.lan.macaddr | cut -d: -f6)"
            LastMAC=$((0x${LastMAC}+1))
            UpdateMAC=`printf '%02X' $LastMAC |awk '{print tolower($0)}'`
            rmac=${OrigMAC}${UpdateMAC}

            uci set network.wan.macaddr=$rmac
            log "mac clone is disable, check mac recovery"
        fi
        uci commit network

        ifdown -w wan
        ifup -w wan
}


usage(){
    echo "$0 [ start ]"
    exit 1
}

action=$1
case "$action" in
    start)
            start_macClone ;;
    *)
            usage ;;
esac

