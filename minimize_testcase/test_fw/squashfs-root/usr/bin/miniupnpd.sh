#!/bin/sh

log() {
	echo "[Miniupnpd] $@" > /dev/console
}

. /usr/share/libubox/jshn.sh
. /lib/functions/network.sh
. /lib/functions.sh
. /lib/hummer/state.sh

MFG_MODE=$(gcontrol uenv get ManufactureMode | awk -F"=" '{print $2}')
[ -z $MFG_MODE ] && { MFG_MODE="0"; }
[ $MFG_MODE = "1" -o $MFG_MODE = "2" ] && {
	exit 0
}

json_load "$(objReq easyMeshBasic json)"
json_select EasyMeshBasicP
json_get_vars enable deviceRole
[ $enable = "1" -a $deviceRole = "2" ] && {
	log "Skip in easymesh child mode!!"
	exit 0
}

WANIF=`uci -q get network.wan.ifname`
LANIP=`uci -q get network.lan.ipaddr`
LANMASK=`uci -q get network.lan.netmask`
MINIUPNPDUUID=`gcontrol di get uuid_key | awk -F"=" '{print $2}'`
[ -z $MINIUPNPDUUID ] && {
        MINIUPNPDUUID=`cat /proc/sys/kernel/random/uuid`
}

SHOWNAME=`cat /tmp/devinfo/default_ssid`
if [ -z $SHOWNAME ]; then
	SHOWNAME="Linksys Router"
else
	json_load "$(objReq lan json)"
	json_select LanP
	json_get_vars routername
	[ "$routername" != "$SHOWNAME" ] && { SHOWNAME=$routername; }
fi

MODELNAME=`cat /tmp/devinfo/modelNumber`
SN=`cat /tmp/devinfo/serial_number`

USERCONF="1"
USERDISCONNECT="0"

setup_miniupnp_conf() {
	if [ -z "$1" -o "$1" = "bridge" ]; then
                runif="ra0 rai0"
		rm -f /var/etc/miniupnpd-*
	else
                runif=$1
		rm -f /var/etc/miniupnpd-$1.conf
	fi

        for ifname in $runif;
        do
                CONFPATH="/var/etc/miniupnpd-$ifname.conf"
                PORTNUM=`expr 6352 + ${#ifname}`

		if [ "$1" != "bridge" ]; then
			echo "ext_ifname=$WANIF" > $CONFPATH
			echo "listening_ip=$LANIP/$LANMASK" >> $CONFPATH
			echo "port=$PORTNUM"  >> $CONFPATH
			echo "bitrate_up=800000000" >> $CONFPATH
			echo "bitrate_down=800000000" >> $CONFPATH
		fi
                echo "secure_mode=no" >> $CONFPATH
                echo "system_uptime=yes" >> $CONFPATH
                echo "notify_interval=30" >> $CONFPATH
                echo "uuid=$MINIUPNPDUUID" >> $CONFPATH
                echo "serial=$SN" >> $CONFPATH
                echo "model_number=1" >> $CONFPATH
                echo "enable_upnp=no" >> $CONFPATH
		echo "friendly_name=$SHOWNAME" >> $CONFPATH
		echo "model_name=Linksys Series Router $MODELNAME" >> $CONFPATH
		echo "user_conf=$USERCONF" >> $CONFPATH
		echo "user_disconnect=$USERDISCONNECT" >> $CONFPATH
        done
}

setup_miniupnp_iptable() {
        #adding the rule to MINIUPNPD
        iptables -wt nat -N MINIUPNPD
        iptables -wt nat -A PREROUTING -i $WANIF -j MINIUPNPD
        iptables -wt filter -N MINIUPNPD
        iptables -wt filter -A FORWARD -i $WANIF ! -o $WANIF -j MINIUPNPD
}

remove_miniupnp_iptable() {
	#Change delete wan interface from config file
	if [ -f "/var/etc/miniupnpd-ra0.conf" ]; then
		DELWANIF=`cat /var/etc/miniupnpd-ra0.conf | grep ext_ifname | cut -d '=' -f 2`
	elif [ -f "/var/etc/miniupnpd-rai0.conf" ]; then
		DELWANIF=`cat /var/etc/miniupnpd-rai0.conf | grep ext_ifname | cut -d '=' -f 2`
	else
		DELWANIF=$WANIF
	fi
        iptables -wt nat -F MINIUPNPD 1>/dev/null 2>&1
        iptables -wt nat -D PREROUTING -i $DELWANIF -j MINIUPNPD 1>/dev/null 2>&1
        iptables -wt nat -X MINIUPNPD 1>/dev/null 2>&1

        iptables -wt filter -F MINIUPNPD 1>/dev/null 2>&1
        iptables -wt filter -D FORWARD -i $DELWANIF ! -o $DELWANIF -j MINIUPNPD 1>/dev/null 2>&1
        iptables -wt filter -X MINIUPNPD 1>/dev/null 2>&1
}

start_upnp() {
	#remove_miniupnp_iptable
        json_load "$(objReq upnp json)"
        json_select UpnpP
        json_get_var enable enable
	json_get_var USERCONF allowUserConf
	json_get_var USERDISCONNECT disableInternet

	json_load "$(objReq wan json)"
	json_select WanP
	json_get_var wanmode proto
	if [ "$wanmode" = "$WAN_PROTO_L2TP" ]; then
		WANIF="l2tp-vpn"
	elif [ "$wanmode" = "$WAN_PROTO_PPTP" ]; then
		WANIF="pptp-vpn"
	elif [ "$wanmode" = "$WAN_PROTO_PPPOE" ]; then
		WANIF="pppoe-wan"
	fi

	OPGID=""
	[ $enable == "1" ] && { OPGID="-G"; }

	if [ $wanmode = "$WAN_PROTO_BRIDGE" -o $wanmode = "$WAN_PROTO_WLAN_BRIDGE" ]; then
		echo "Start miniupnpd bridge" > /dev/console
		setup_miniupnp_conf bridge
		network_get_ipaddr lanIp lan
		miniupnpd -m 1 -I ra0 -f "/var/etc/miniupnpd-ra0.conf" -P "/var/run/miniupnpd.ra0" $OPGID -i br-lan -a $lanIp -n 7922
		miniupnpd -m 1 -I rai0 -f "/var/etc/miniupnpd-rai0.conf" -P "/var/run/miniupnpd.rai0" $OPGID -i br-lan -a $lanIp -n 7930
	else
		#[ -n "$OPGID" ] && { setup_miniupnp_iptable; }
		if [ -z $1 ]; then
			echo "Start miniupnpd all" > /dev/console
			setup_miniupnp_conf
			miniupnpd -m 1 -I ra0 -f "/var/etc/miniupnpd-ra0.conf" -P "/var/run/miniupnpd.ra0" $OPGID -i $WANIF -a "$LANIP/$LANMASK" -n 7922
			miniupnpd -m 1 -I rai0 -f "/var/etc/miniupnpd-rai0.conf" -P "/var/run/miniupnpd.rai0" $OPGID -i $WANIF -a "$LANIP/$LANMASK" -n 7930
		else
			[ $1 == "ra0" ] && { PORT="7922"; }
			[ $1 == "rai0" ] && { PORT="7930"; }
			echo "Start miniupnpd $1" > /dev/console
			setup_miniupnp_conf $1
			miniupnpd -m 1 -I $1 -f "/var/etc/miniupnpd-$1.conf" -P "/var/run/miniupnpd.$1" $OPGID -i $WANIF -a "$LANIP/$LANMASK" -n $PORT
		fi
	fi
}

stop_upnp() {
	if [ -z $1 ]; then
        	runpid=`pidof miniupnpd`
        	echo "Kill miniupnpd $runpid" > /dev/console

        	for pid in $runpid;
        	do
        	        kill -15 $pid
        	done
        	rm -f /var/run/miniupnpd.*
        else
                echo "Kill miniupnpd $1" > /dev/console
                runpid=`cat /var/run/miniupnpd.$1`
                kill -15 $runpid
                rm -f /var/run/miniupnpd.$1
	fi
}

send_wanchnage() {
	runpid=`pidof miniupnpd`
	echo "Send miniupnpd wan change to $runpid" > /dev/console
	for pid in $runpid;
	do
		kill -16 $pid
	done
}

usage() {
	log "Unknown miniupnpd status!!"
}

action=$1
actif=$2
case "$action" in
    start)
            if [ -z $2 ]; then
                start_upnp
            elif [ "$2" == "ra0" -o "$2" == "rai0" ]; then
                start_upnp $2
            fi
	    ;;
    stop)
            if [ -z $2 ]; then
                stop_upnp
            elif [ "$2" == "ra0" -o "$2" == "rai0" ]; then
                stop_upnp $2
            fi
	    ;;
    restart)
            stop_upnp
	    start_upnp
	    ;;
    wanchange)
            send_wanchnage
            ;;
    *)
            usage ;;
esac

