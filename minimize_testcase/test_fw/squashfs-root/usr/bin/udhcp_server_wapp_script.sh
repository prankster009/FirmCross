#!/bin/sh

log() {
        echo "[Wappd run udhcp server] $@" > /dev/console
}

set_br_name=$1
set_br_ip=$2

if [ -z "$1" ]; then
    log "Unknown interface !!!"
else
    log "Start dhcp server from wapp to $set_br_name $set_br_ip"
    UDHCPCPID=`cat /var/run/udhcpc-br-lan.pid`
    sleep 3
    #ifconfig $set_br_name 0.0.0.0
    #kill -SIGUSR1 $UDHCPCPID

	touch /tmp/meshdown
fi
