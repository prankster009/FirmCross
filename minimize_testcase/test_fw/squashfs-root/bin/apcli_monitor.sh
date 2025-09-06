#!/bin/sh

RUNNING="/tmp/apcli_check.sh-running"
 if [ -f "$RUNNING" ] ; then

    echo "exist $RUNNING"
    return 1
 fi

SERVICE="wireless"

. /usr/share/libubox/jshn.sh


json_load "$(objReq wan json)"
json_select "WanP"
json_get_vars proto

log() {
	echo "[apcli_check] $@" > /dev/console
}


apcli_setting()
{
    json_load "$(objReq wlanBridge json)"
    json_select "WlanBridgeT"
    local Index="1"

    
    while json_get_type Type $Index && [ "$Type" = object ]; do
        local enable ssid ifname type

        json_select "$Index"
        json_get_vars ssid ifname type
        
        [ $type = "2" ] && ifname_cmd="apcli0"
        [ $type = "5" ] && ifname_cmd="apclii0"

        #let Index=$Index+1
        #json_select ".."
    done
 
}

apcli_monitor_status()
{
    local ifname_cmd_1=$1
	TIME=0
	STATUS_TIMEOUT=20
    
    
    local check_apccli_status ifname_connStatus check_apccli_status_2 ifname_connStatus_2
    local check_wsc_status
    
	ENDTIME=`date +%s`
	ENDTIME=`expr $ENDTIME + $STATUS_TIMEOUT`
	
	while [ true ] ; do
    
        check_apccli_status=""
        ifname_connStatus=""
        check_apccli_status_2=""
        ifname_connStatus_2=""

        check_apccli_status=`iwconfig $ifname_cmd_1 | grep ESSID | cut -d '"' -f 2 `
        sleep 3
        ifname_connStatus=`iwpriv $ifname_cmd_1 show connStatus && dmesg | tail -n 5 | grep 'Connected AP' | grep Disconnect`
        sleep 3
        check_apccli_status_2=`iwconfig $ifname_cmd_1 | grep ESSID | cut -d '"' -f 2 `
        sleep 3
        ifname_connStatus_2=`iwpriv $ifname_cmd_1 show connStatus && dmesg | tail -n 5 | grep 'Connected AP' | grep Disconnect`

        if [ "$check_apccli_status" != "" -a "$ifname_connStatus" = "" -a "$check_apccli_status_2" != "" -a "$ifname_connStatus_2" = "" ]; then


            check_wsc_status=`ps | grep wsc_monitor | grep D | grep -v grep`
            [ "$check_wsc_status" = "" ] && wps_action.sh start

            break
        fi

        
    	TIME=0


        TIME=`date +%s`
        if [ $TIME -gt $ENDTIME ] ; then
        
            #log "apcli_monitor_status FAIL" 
            #iwpriv $ifname_cmd set ApCliEnable=1

            killall wsc_monitor
            sleep 1
            
            #[ ! -f "$RUNNING" ] && iwpriv $ifname_cmd set ApCliAutoConnect=1
            [ ! -f "$RUNNING" ] && {
                #/bin/apcli_check.sh
                iwpriv $ifname_cmd_1 set ApCliAutoConnect=1;
                iwpriv $ifname_cmd_1 set ApCliEnable=1;
            }
            #/usr/bin/ledstatus.sh internet_connect_fail
            break
        fi	
    done

}

    
if [ $proto = "6" ]; then 
    
    apcli_setting    
    apcli_monitor_status $ifname_cmd
    
fi





