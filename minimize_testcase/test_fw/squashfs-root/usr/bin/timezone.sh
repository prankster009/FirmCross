#!/bin/sh
# Copyright (C) 2014 Gemtek

. /usr/share/libubox/jshn.sh
. /lib/functions/network.sh
. /lib/functions.sh

CRONTAB_ROOT="/etc/crontabs/root"
NTP_SERVER=$(uci -q get system.ntp.server)

log() {
	echo "[timezone] $@" > /dev/console
}

remove_cron_rules() {
    sed -i '/#ntp/d' $CRONTAB_ROOT
}

add_cron_rules() {
    random=$(tr -dc 1-9 </dev/urandom | head -c 3)
    minute=$(((random+1) % 60))
    echo "$minute */12 * * * /usr/sbin/ntpd -q -p $NTP_SERVER #ntp" >> $CRONTAB_ROOT
}


disable_tz() {
    uci set system.ntp.enabled='0'
    uci commit system
    remove_cron_rules
}

start_tz() {
    /usr/bin/tz_setting
    log "Timezone setting is done."
    /usr/sbin/ntpd -q -p $NTP_SERVER
    remove_cron_rules
    add_cron_rules
}

stop_tz() {
    log "stop timezone service"
    remove_cron_rules
}

usage(){
        echo "$0 [ start|disable ]"
        exit 1
}

action=$1
case "$action" in
    start)
        start_tz ;;
    disable)
        disable_tz ;;
    none)
        exit 0;;
    *)
        usage ;;
esac

