#!/bin/sh

log() {
        echo "[Wappd run udhcpc] $@" > /dev/console
}

if [ -z "$1" ]; then
    log "Unknown interface !!!"
else
    log "Start dhcp client"
	UDHCPCPID=`cat /var/run/udhcpc-br-lan.pid`
	sleep 3
	ifconfig $1 0.0.0.0
	#kill -SIGUSR1 $UDHCPCPID
	kill -9 $UDHCPCPID

	rm -f /tmp/meshdown
fi
