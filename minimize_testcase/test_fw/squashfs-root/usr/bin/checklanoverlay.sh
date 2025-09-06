#!/bin/sh

log() {
	echo "[Check wan/lan overlay] $@" > /dev/console
}

. /usr/share/libubox/jshn.sh
. /lib/functions/network.sh
. /lib/functions.sh
. /lib/functions/gemtek.sh

log "Start overlay check"

masknumtoaddr() {
	zeros=$((32-$1))
	NETMASKNUM=0
	while [ $zeros != 0 ]; do
	        NETMASKNUM=$(( (NETMASKNUM << 1) ^ 1 ))
	        zeros=$(expr $zeros - 1)
	done
	NETMASKNUM=$((NETMASKNUM ^ 0xFFFFFFFF))

	b1=$(( ($NETMASKNUM & 0xFF000000) >> 24))
	b2=$(( ($NETMASKNUM & 0xFF0000) >> 16))
	b3=$(( ($NETMASKNUM & 0xFF00) >> 8))
	b4=$(( $NETMASKNUM & 0xFF ))
	eval "$2=\$b1.\$b2.\$b3.\$b4"
}

json_load "$(objReq lan json)"
json_select "LanP"
json_get_var LANIP ipaddr
json_get_var LANMASK netmask
json_get_var SETROUTERNAME routername

network_get_ipaddr WANIP wan
network_get_subnet WANMASK wan
if [ -n "$WANMASK" -a -n "$WANIP" ]; then

    local ret=0
	MASKNUM=`echo $WANMASK | cut -d '/' -f 2`
	[ -z "$MASKNUM" ] && { MASKNUM='24'; }
	masknumtoaddr $MASKNUM WANMASK
	WanIsOverlay="$(check_overlay $WANIP $WANMASK $LANIP $LANMASK)"
	[ "$WanIsOverlay" = "1" ] && {
		log "wan subnet is the same as lan, update lan setting!!!"
        uci -q delete dhcp.@dnsmasq[0].address
		if [ $(check_overlay $WANIP $WANMASK 192.168.11.1 255.255.255.0) = 1 ]; then
			log "Change lan ip to 192.168.1.1/24"
			objReq lan setparam ipaddr "192.168.1.1"
			objReq dhcps setparam startIp "192.168.1.100"
            uci add_list dhcp.@dnsmasq[0].address="/myrouter.local/192.168.1.1"
            uci add_list dhcp.@dnsmasq[0].address="/$SETROUTERNAME/192.168.1.1"
		else
			log "Change lan ip to 192.168.11.1/24"
			objReq lan setparam ipaddr "192.168.11.1"
			objReq dhcps setparam startIp "192.168.11.100"
            uci add_list dhcp.@dnsmasq[0].address="/myrouter.local/192.168.11.1"
            uci add_list dhcp.@dnsmasq[0].address="/$SETROUTERNAME/192.168.11.1"
		fi
        uci commit dhcp
		objReq lan setparam netmask "255.255.255.0"
		gnvram commit
        ret=1
		
	}
  
    gst_ipaddr=`uci get network.guest.ipaddr`
    gst_netmask=`uci get network.guest.netmask`
    
	[ "$gst_ipaddr" != "" -a "$gst_netmask" != "" -a $(check_overlay $WANIP $WANMASK $gst_ipaddr $gst_netmask) = 1 ] && {
		log "wan subnet is the same as guest, update guest setting!!!"
        
        if [ $(check_overlay $WANIP $WANMASK 192.168.34.1 255.255.255.0) = 1 ]; then
            log "Change guest ip to 192.168.35.1/24"
            uci set network.guest.ipaddr='192.168.35.1'
        else
            log "Change guest ip to 192.168.34.1/24"
            uci set network.guest.ipaddr='192.168.34.1'
        fi
        uci commit network
        ret=2
	}  

    
    [ "$ret" = "1" ] && /etc/init.d/network restart
    [ "$ret" = "2" ] && /etc/init.d/network restart && /etc/init.d/nodogsplash restart
    /etc/init.d/mdnsd restart
    
else
	log "Can't get wan netmask, skip check!!!"
fi
