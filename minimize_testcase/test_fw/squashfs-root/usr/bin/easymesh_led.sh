#!/bin/sh

. /lib/hummer/api.sh

BH=""
RSSI=""


check_enable() {
    local open=$(objReq easyMeshBasic show | head -n 1 | awk -F " " '{print $3}')

    if [ "$open" != "1" ]; then
        # not light led when disable
        exit 0
    fi
}

check_role() {
    local role=$(cat /etc/map/mapd_cfg | grep DeviceRole | awk -F "=" '{print $2}')

    if [ "$role" = "1" ]; then
        # not light led on controller
        exit 0
    fi
}

check_meshdown() {
	if [ -f /tmp/meshdown ]; then
		# mesh down
		/usr/bin/ledstatus.sh wps_fail
		exit 0
	fi
}

check_bh() {
    local ssid_2=$(iwconfig apcli0 | head -n 1 | awk -F "\"" '{print $2}')

    if [ -n "$ssid_2" ]; then
        BH="2.4G"
        #return
    fi

    local ssid_5=$(iwconfig apclii0 | head -n 1 | awk -F "\"" '{print $2}')

    if [ -n "$ssid_5" ]; then
        BH="5G"
        #return
    fi
	# mesh up check wired or backhaul
    if [ -z "$BH" ]; then
        # no backhaul
		/usr/bin/ledstatus.sh wps_finish
        exit 0
    fi
}

get_rssi() {
    if [ "$BH" = "2.4G" ]; then
        RSSI=$(iwpriv apcli0 stat | grep RSSI | awk -F " " '{print $4}')
    elif [ "$BH" = "5G" ]; then
        RSSI=$(iwpriv apclii0 stat | grep RSSI | awk -F " " '{print $3}')
    fi

    if [ -z "$RSSI" ]; then
        log_info "easymesh/led" "can't get RSSI!"
        exit 1
    fi
}

light_led() {
    if [ "$RSSI" -le "-60" ]; then
        /usr/bin/ledstatus.sh easymesh_too_far
    else
        /usr/bin/ledstatus.sh wps_finish
    fi
}

check_enable
check_role
check_meshdown
check_bh
get_rssi
light_led

