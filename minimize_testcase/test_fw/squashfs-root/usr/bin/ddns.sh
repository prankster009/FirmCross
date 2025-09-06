#!/bin/sh

CONFIG="/etc/inadyn.conf"
AUTH=""

. /usr/share/libubox/jshn.sh
. /lib/functions/network.sh
. /lib/functions.sh

ddns_log() {
	echo "[ddns] $@" > /dev/console
}

disable_ddns()
{
    objReq ddns setparam enable 0
    uci set ddns.gtkddns.enabled=$ENABLE
    uci commit ddns
}


SetupDdns()
{
    local wcd=""
    local mx=""
    local bmx=""
    json_load "$(objReq ddns json)"
    json_select "DdnsP"
    json_get_vars enable username password hostname provider system mailex backupmailex wildcard ip status
    json_select ".."

    if [ ! -f $CONFIG ]; then
        touch  $CONFIG
    else
        echo "" > $CONFIG
    fi

    if [ "$wildcard" = "1" ]; then
        wcd="ON"
    else
        wcd="NOCHG"
    fi
    if [ -z "$mailex" ]; then
        mx="NOCHG"
    else
        mx="$mailex"
    fi
    if [ "$backupmailex" = "1" ]; then
        bmx="YES"
    else
        bmx="NOCHG"
    fi

    local ip="$(ifconfig eth1 | grep 'inet addr' | cut -d: -f2 | awk '{print $1}')"

    echo "period = 300" >> $CONFIG
    echo "user-agent = inadyn/2.5" >> $CONFIG
    echo  >> $CONFIG
    echo "provider $PROVIDER:1" >> $CONFIG
    echo "{" >> $CONFIG
    echo "      username = $username" >> $CONFIG
    echo "      password = $password" >> $CONFIG
    echo "      hostname = $hostname" >> $CONFIG
    echo "}" >> $CONFIG

    if [ "$provider" = "no-ip.com" ]; then
            # https://www.noip.com/docs/crosswalk.pdf
            # System, Mail Exchange, Backup MX, Wildcard will be ignored by no-ip.com
            #
            AUTH="http://${username}:${password}@dynupdate.no-ip.com/nic/update?hostname=${hostname}&myip=${ip}"
            #AUTH="https://dynupdate.no-ip.com/nic/update"
            curl -X GET $AUTH > /dev/null 2>&1
    else
            AUTH="http://${username}:${password}@members.dyndns.org/nic/update?hostname=${hostname}&myip=${ip}&wildcard=${wcd}&mx=${mx}&backmx=${bmx}"
            curl -X GET $AUTH > /dev/null 2>&1
    fi
}

start_ddns() {
    SetupDdns
    json_load "$(ifstatus wan)"
    json_get_var DEVICE device

    /usr/sbin/inadyn -f $CONFIG -l info -i $DEVICE
    ddns_log "start ddns service"
}

stop_ddns() {
    ddns_log "stop ddns service"
    killall -9 inadyn
}


usage(){
        echo "$0 [ start ]"
        exit 1
}


action=$1
case "$action" in
    start)
        start_ddns ;;
    stop)
        stop_ddns ;;
    disable)
        exit 0 ;;
    *)
        usage ;;
esac

