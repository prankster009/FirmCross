#!/bin/sh

WPSFAIL="/tmp/wps_fail"
RUNNING="/tmp/wps_action.sh-running"


. /usr/share/libubox/jshn.sh
. /lib/functions/network.sh
. /lib/functions.sh
. /lib/hummer/api.sh

wps_enable=1
json_load "$(objReq wlanWps json)"
json_select "WlanWpsT"
local Index="1"
while json_get_type Type $Index && [ "$Type" = object ]; do
    json_select "$Index"
    json_get_vars enable
    wps_enable=$enable
    #let Index=$Index+1
    #json_select ".."
 done


json_load "$(objReq wlanBasic json)"
json_select "WlanBasicT"
Index="1"
while json_get_type Type $Index && [ "$Type" = object ]; do
    json_select "$Index"
    json_get_vars enable type  hiddenAP
    [ $type = "2" ] && onoff_2g=$enable && hiddenAP_2g=$hiddenAP
    [ $type = "5" ] && onoff_5g=$enable && hiddenAP_5g=$hiddenAP
    let Index=$Index+1
    json_select ".."
done

PATH_24G=`cat /etc/wireless/l1profile.dat | grep INDEX0_profile_path | cut -d '=' -f 2`
PATH_5G=`cat /etc/wireless/l1profile.dat | grep INDEX1_profile_path | cut -d '=' -f 2`

trap clean_up SIGHUP SIGINT SIGTERM


clean_up()
{

    log_info "wps" "stop wps process"

    iwpriv rai0 set WscStop=1
    iwpriv ra0 set WscStop=1

    /usr/bin/ledstatus.sh wps_finish
    rm -f $RUNNING
    exit 1
}


record_security_setting()
{
    log_info "wps" "record_security_setting $1"
    sleep 4

    local config_path ssid authtype encrypType wpaPsk index
    if [ $1 = "ra0" ]; then
        config_path=$PATH_24G
        index=0
    elif [ $1 = "rai0" ]; then
        config_path=$PATH_5G
        index=1
    fi

    ssid=`wificonf -f $config_path get SSID1`
    authtype=`wificonf -f $config_path get AuthMode 0`
    encrypType=`wificonf -f $config_path get EncrypType 0`
    wpaPsk=`wificonf -f $config_path get WPAPSK1 0`
    wscStatus=`wificonf -f $config_path get WscConfStatus 0`
    log_info "wps" "ifname:$1"
    log_info "wps" "ssid:$ssid authtype:$authtype encrypType:$encrypType wpaPsk:$wpaPsk wscStatus:$wscStatus"


    objReq wlanBasic setparam $index ssid "$ssid"
    objReq wlanSecurity setparam $index authtype "$authtype"
    objReq wlanSecurity setparam $index encrypType "$encrypType"
    objReq wlanSecurity setparam $index wpaPsk "$wpaPsk"

    objReq wlanWps setparam 0 wscConfStatus "$wscStatus"

    gnvram commit
}


wps_monitor_status()
{
    log_info "wps" "wps_monitor_status"

    local wps_ledstatus=

	TIME=0
	STATUS_TIMEOUT=120

	ENDTIME=`date +%s`
	ENDTIME=`expr $ENDTIME + $STATUS_TIMEOUT`

    local mesh_enable mesh_role
    json_load "$(objReq easyMeshBasic json)"
    json_select EasyMeshBasicP
    json_get_var mesh_enable enable
    json_get_var mesh_role deviceRole
    json_select ".."

	while [ true ] ; do

        wps_status_5g=`wsc_monitor -i rai0`
        wps_status_24g=`wsc_monitor -i ra0`

		if [ $wps_status_5g = 34 ] ; then

			record_security_setting rai0
            log_info "wps" "5G Connected!"
            /usr/bin/ledstatus.sh wps_finish
			return 0
    	fi

		if [ $wps_status_24g = 34  ] ; then

			record_security_setting ra0
            log_info "wps" "2.4G Connected!"
            /usr/bin/ledstatus.sh wps_finish
			return 0
    	fi

        if [ $wps_status_5g = 2 ] || [ $wps_status_5g = 31 ] || [ $wps_status_5g = 32 ] || [ $wps_status_5g = 33 ] ; then
            iwpriv rai0 set WscStop=1
            /usr/bin/ledstatus.sh wps_fail
        fi

        if [ $wps_status_24g = 2 ] || [ $wps_status_24g = 31 ] || [ $wps_status_24g = 32 ] || [ $wps_status_24g = 33 ] ; then
            iwpriv ra0 set WscStop=1
            /usr/bin/ledstatus.sh wps_fail
        fi

		TIME=0
		sleep 1

        TIME=`date +%s`
        if [ $TIME -gt $ENDTIME ] ; then

            iwpriv rai0 set WscStop=1
            iwpriv ra0 set WscStop=1
            /usr/bin/ledstatus.sh wps_fail

            if [ "$mesh_enable" = "1" -a "$mesh_role" = "1" ] || [ "$mesh_enable" = "0" ]; then
                sleep 60 && /usr/bin/ledstatus.sh wps_finish &
            else
                echo 1 > $WPSFAIL
                sleep 60 && rm $WPSFAIL &
            fi

            break
        fi
	done

}

wps_action_pbc_trigger()
{
    check_wsc_status=`ps | grep wsc_monitor | grep D | grep -v grep`
    [ "$check_wsc_status" = "" ] && {
        log_info "wps" "wsc_monitor is not ready"
        return 1
    }
    [ "$wps_enable" = "0" ] && exit 1

    # Make sure only one default script running.
    while :
    do
        if [ ! -f "$RUNNING" ] ; then
            break
        fi
        echo "exist $RUNNING"
        return 1
    done
    echo 1 > $RUNNING

    log_info "wps" "wps_action_pbc"


    if [ "$onoff_2g" = "1" -a "$hiddenAP_2g" = "0" ] || [ "$onoff_5g" = "1" -a "$hiddenAP_5g" = "0" ]; then
        /usr/bin/ledstatus.sh wps_start
    fi

    #2G
    [ "$onoff_2g"="1" -a "$hiddenAP_2g" = "0" ] && {
        iwpriv ra0 set WscConfMode=7
        iwpriv ra0 set WscMode=2
        iwpriv ra0 set WscGetConf=1
    }

    #5G
    [ "$onoff_5g" = "1" -a "$hiddenAP_5g" = "0" ] && {
        iwpriv rai0 set WscConfMode=7
        iwpriv rai0 set WscMode=2
        iwpriv rai0 set WscGetConf=1
    }

    wps_monitor_status

    rm -f $RUNNING
}

wps_action_pincode_trigger()
{
    check_wsc_status=`ps | grep wsc_monitor | grep D | grep -v grep`
    [ "$check_wsc_status" = "" ] && {
        log_info "wps" "wsc_monitor is not ready"
        return 1
    }
    [ "$wps_enable" = "0" ] && exit 1

    # Make sure only one default script running.
    while :
    do
        if [ ! -f "$RUNNING" ] ; then
            break
        fi
        echo "exist $RUNNING"
        return 1
    done
    echo 1 > $RUNNING

    log_info "wps" "wps_action_pincode_tirgger $1"


    if [ "$onoff_2g" = "1" -a "$hiddenAP_2g" = "0" ] || [ "$onoff_5g" = "1" -a "$hiddenAP_5g" = "0" ]; then
        /usr/bin/ledstatus.sh wps_start
    fi

    local pincode=$1

    #2G
    [ "$onoff_2g" = "1" -a "$hiddenAP_2g" = "0" ] && {

        iwpriv ra0 set WscConfMode=7
        iwpriv ra0 set WscPinCode=$pincode
        iwpriv ra0 set WscMode=1
        iwpriv ra0 set WscGetConf=1
    }

    #5G
    [ "$onoff_5g" = "1" -a "$hiddenAP_5g" = "0" ] && {

        iwpriv rai0 set WscConfMode=7
        iwpriv rai0 set WscPinCode=$pincode
        iwpriv rai0 set WscMode=1
        iwpriv rai0 set WscGetConf=1
    }
    wps_monitor_status

    rm -f $RUNNING
}

wps_actions_start()
{
    if [ "$wps_enable" = "1" ] ; then
        #2g
        [ "$onoff_2g" = "1" -a "$hiddenAP_2g" = "0" ] && {
            log_info "wps" "wsc_monitor -i ra0 -D"
            wsc_monitor -i ra0 -D
        }
        #5g
        [ "$onoff_5g" = "1" -a "$hiddenAP_5g" = "0" ] && {
            log_info "wps" "wsc_monitor -i rai0 -D"
            wsc_monitor -i rai0 -D
        }
    fi
}

action=$1

case "$action" in

    PBC)
        wps_action_pbc_trigger ;;
    PIN)
        wps_action_pincode_trigger $2 ;;
    UPDATE)
        record_security_setting $2 ;;

    start)
        wps_actions_start ;;
    *)
        exit 0 ;;

esac
#rm -f $RUNNING
