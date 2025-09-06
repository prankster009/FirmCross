#!/bin/sh

. /usr/share/libubox/jshn.sh
. /lib/functions/network.sh


IP4_NEIGH_FILE="/tmp/.ip4_neigh"
OLD_HOSTS_FILE="/tmp/.old_hosts"
NEW_HOSTS_FILE="/tmp/.new_hosts"

true > $IP4_NEIGH_FILE
true > $OLD_HOSTS_FILE
true > $NEW_HOSTS_FILE

ip -4 neigh show dev br-lan > $IP4_NEIGH_FILE

handle_old_hosts() {
    json_load "$(objReq pcPolicy json)"
    json_select "PcPolicyT"
    local Index="1"
    while json_get_type Type $Index && [ "$Type" = object ]; do
        json_select "$Index"
        json_get_vars targetName targetMac
        echo "$targetMac $targetName" >> $OLD_HOSTS_FILE
        let Index=$Index+1
        json_select ".."
    done
}

handle_dhcp_hosts() {
    cat /tmp/dhcp.leases | while read line
do
    HOST_DHCP_MAC=$(echo "$line" | awk '{print $2}')
    HOST_NAME=$(grep "$HOST_DHCP_MAC" $OLD_HOSTS_FILE | cut -d' ' -f2-)
    if [ -z "$HOST_NAME" ]; then
        HOST_NAME=$(echo "$line" | awk '{print $4}')
    fi

    STATE=$(grep "$HOST_DHCP_MAC" $IP4_NEIGH_FILE | awk '{print $4}')
    if [ "$STATE" = "DELAY" -o "$STATE" = "REACHABLE" ]; then
        echo "$HOST_DHCP_MAC $HOST_NAME" >> $NEW_HOSTS_FILE
    fi
done
}

handle_static_hosts() {
    LAN_SUBNET=
    network_get_subnet LAN_SUBNET lan
    LAN_MASKCNT=$(ipcalc.sh $LAN_SUBNET | grep PREFIX | cut -d"=" -f2)
    LAN_NETWORK=$(ipcalc.sh $LAN_SUBNET | grep NETWORK | cut -d"=" -f2)

    cat /proc/net/arp | grep "br-lan" | while read line
do
    HOST_ARP_IP=$(echo "$line" | awk '{print $1}')
    HOST_ARP_MAC=$(echo "$line" | awk '{print $4}')
    HOST_ARP_FLAG=$(echo "$line" | awk '{print $3}')

    HOST_NETWORK=$(ipcalc.sh $HOST_ARP_IP/$LAN_MASKCNT | grep NETWORK | cut -d"=" -f2)
    if [ "$HOST_NETWORK" != "$LAN_NETWORK" ]; then
        continue
    fi

    HOST_NAME=$(grep "$HOST_ARP_MAC" $OLD_HOSTS_FILE | cut -d' ' -f2-)
    if [ -z "$HOST_NAME" ]; then
        HOST_NAME="unknown"
    fi

    HOST_DHCP_INFO=$(grep "$HOST_ARP_MAC" /tmp/dhcp.leases)
    HOST_DHCP_IP=$(echo "$HOST_DHCP_INFO" | awk '{print $3}')
    if [ -z "$HOST_DHCP_INFO" ]; then
        echo "$HOST_ARP_MAC $HOST_NAME" >> $NEW_HOSTS_FILE
    else
        if [ "$HOST_ARP_IP" != "$HOST_DHCP_IP" -a "$HOST_ARP_FLAG" = "0x2" ]; then
            STATE=$(grep "$HOST_DHCP_IP" $IP4_NEIGH_FILE | awk '{print $4}')
            if [ "$STATE" = "DELAY" -o "$STATE" = "REACHABLE" ]; then
                continue
            fi

            STATE=$(grep "$HOST_ARP_IP" $IP4_NEIGH_FILE | awk '{print $4}')
            if [ "$STATE" = "DELAY" -o "$STATE" = "REACHABLE" -o "$STATE" = "STALE" ]; then
                echo "$HOST_ARP_MAC $HOST_NAME" >> $NEW_HOSTS_FILE
            fi
        fi
    fi
done
}

handle_new_hosts() {
    cat $OLD_HOSTS_FILE | while read line
do
    OLD_HOST_MAC=$(echo $line | awk '{print $1}')
    OLD_HOST_NAME=$(echo $line | cut -d' ' -f2-)
    grep -q "$OLD_HOST_MAC" $NEW_HOSTS_FILE
    RET="$?"
    if [ "$RET" = "1" ]; then
        echo "$OLD_HOST_MAC $OLD_HOST_NAME" >> $NEW_HOSTS_FILE
    fi
done
}

handle_old_hosts
handle_dhcp_hosts
handle_static_hosts
handle_new_hosts
cat $NEW_HOSTS_FILE

