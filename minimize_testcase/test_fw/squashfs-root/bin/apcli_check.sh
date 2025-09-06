#!/bin/sh


RUNNING="/tmp/apcli_check.sh-running"
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


PATH_24G=`cat /etc/wireless/l1profile.dat | grep INDEX0_profile_path | cut -d '=' -f 2`
PATH_5G=`cat /etc/wireless/l1profile.dat | grep INDEX1_profile_path | cut -d '=' -f 2`

SERVICE="wireless"

. /usr/share/libubox/jshn.sh

json_load "$(objReq wan json)"
json_select "WanP"
json_get_vars proto

echo "proto:$proto" > /dev/console


log() {
	echo "[apcli_check] $@" > /dev/console
}

wlanBridge_update()
{
    json_load "$(objReq wlanBridge json)"
    json_select "WlanBridgeT"
    local Index="1"

    
    while json_get_type Type $Index && [ "$Type" = object ]; do
        local  ssid ifname type authtype encrypType wpaPsk

        json_select "$Index"
        json_get_vars ssid ifname type authtype encrypType wpaPsk
        
        #echo "ssid:$ssid ifname:$ifname type:$type " > /dev/console
        #echo "authtype:$authtype encrypType:$encrypType wpaPsk:$wpaPsk" > /dev/console

        
        
        WIFI_CMD_SSID=$(echo "$ssid" | sed 's/[$]/\$/g')
		WIFI_CMD_SSID=$(echo "$WIFI_CMD_SSID" | sed 's/[`]/\`/g')
		WIFI_CMD_SSID=$(echo "$WIFI_CMD_SSID" | sed 's/["]/\"/g')
		WIFI_CMD_WPAPSK=$(echo "$wpaPsk" | sed 's/[$]/\$/g')
		WIFI_CMD_WPAPSK=$(echo "$WIFI_CMD_WPAPSK" | sed 's/[`]/\`/g')
		WIFI_CMD_WPAPSK=$(echo "$WIFI_CMD_WPAPSK" | sed 's/["]/\"/g')
        
        
        WIFI_CMD_AUTHTYPE=$authtype
        WIFI_CMD_ENCRYPTYPE=$encrypType
        
        if [ $type = "2" ]; then
            config_path=$PATH_24G
            ifname_cmd="apcli0"
            main_ifname="ra0"
            
        elif [ $type = "5" ]; then
            config_path=$PATH_5G
            ifname_cmd="apclii0"
            main_ifname="rai0"
        fi

        #let Index=$Index+1
        #json_select ".."
    done
    

}
record_wlanBridge_setting()
{

    current_channel=`iwconfig $1 | grep Channel | awk '{print $2}' | cut -d '=' -f 2`
    echo "current_channel:$current_channel" > /dev/console


    if [ $1 = "apcli0" ]; then
        Index=1
        index=0
    elif [ $1 = "apclii0" ]; then

        Index=2
        index=1
    fi

    json_load "$(objReq wlanBasic json)"
    json_select "WlanBasicT"

    local config_channel=0
    
    while json_get_type Type $Index && [ "$Type" = object ]; do
        local channel

        json_select "$Index"
        json_get_vars channel    
        config_channel=$channel

        #let Index=$Index+1
        #json_select ".."
        
    done

    if [ $config_channel != $current_channel ]; then
        objReq wlanBasic setparam $index channel $current_channel 
        gnvram commit

    fi
    
}

apcli_monitor_status()
{
    ret=0
    
	TIME=0
	STATUS_TIMEOUT=12
    
    local check_apccli_status ifname_connStatus
    
	ENDTIME=`date +%s`
	ENDTIME=`expr $ENDTIME + $STATUS_TIMEOUT`
	
	while [ true ] ; do
    
        
        check_apccli_status=""
        ifname_connStatus=""
        check_apccli_status=`iwconfig $ifname_cmd | grep ESSID | cut -d '"' -f 2 `
        ifname_connStatus=`iwpriv $ifname_cmd show connStatus && dmesg | tail -n 5 | grep 'Connected AP' | grep Disconnect`
        
        if [ "$check_apccli_status" != "" -a "$ifname_connStatus" = "" ]; then
        
            record_wlanBridge_setting $ifname_cmd
 
            # Skip internet check, let internetcheck.sh for led status
            add_apccli_minotor=`cat /etc/crontabs/root | grep APCLIENT_MONITOR`           
            if [ "$add_apccli_minotor" = "" ]; then  
                echo "*/3 * * * * /bin/apcli_monitor.sh #APCLIENT_MONITOR" >>  /etc/crontabs/root
                /etc/init.d/cron restart    
            fi
            ret=1
            break
        fi
        
    	TIME=0
		sleep 4

        TIME=`date +%s`
        if [ $TIME -gt $ENDTIME ] ; then
        
            break
        fi	
    done
    return $ret
}

    
do_wlanBridge_connect()
{
    log "wlanBridge check" 
    ifconfig $ifname_cmd up    
    
    local check_status=0

    iwpriv $ifname_cmd set SiteSurvey=1
    sleep 4
    iwpriv $ifname_cmd get_site_survey | sed '$d' > /tmp/get_site_survey


    local site_survey=""
    sleep 1
    cat /tmp/get_site_survey | grep  "$WIFI_CMD_SSID" | grep $WIFI_CMD_AUTHTYPE >  /tmp/get_site_survey_ssid
    
    site_survey=`cat /tmp/get_site_survey_ssid`

    #Reset Led to no connection
    killall -9 check_internet
    /usr/bin/ledstatus.sh no_internet_connect
    
    if [ "$site_survey" != "" ]; then

        count=5
        while [ $count -gt 0 -a "$site_survey" != "" ]
        do
            iwpriv $ifname_cmd set ApCliEnable=0
            
            ch=`echo $site_survey | awk 'NR==1 {print $2}' `
            #ssid=`echo $site_survey | awk 'NR==1 {print $3}' `
            #security=`echo $site_survey | awk 'NR==1 {print $5}' `
            excha=`echo $site_survey | awk 'NR==1 {print $8}' `

            [ "$ch" != "" ] && iwpriv $ifname_cmd set Channel=$ch
            
            if [ "$ch" -gt "4"  -a  "$ch" -lt "8" ]; then
            
                if [ "$excha" = "ABOVE" ]; then
                    iwpriv $ifname_cmd set HtExtcha=1
                fi
            fi
            
            iwpriv $ifname_cmd set ApCliEnable=1
            echo "$ch $ssid $security $excha" > /dev/console
            apcli_monitor_status
            check_status=$?
            
            if [ "$check_status" = "1" ]; then 
		    /usr/bin/check_internet
		    break
	    fi
            
            let count=$count-1
            sed -i '1d' /tmp/get_site_survey_ssid
            sleep 1
            site_survey=`cat /tmp/get_site_survey_ssid`
        done
    fi
    
    
}  
 wlanBridge_update 

if [ $proto = "6" ]; then 

    do_wlanBridge_connect

else

    check_apccli_crontabs=`cat /etc/crontabs/root | grep -n APCLIENT_MONITOR`
            
    if [ "$check_apccli_crontabs" != "" ]; then
        sed -i '/APCLIENT_MONITOR/d' /etc/crontabs/root
    
        /etc/init.d/cron restart
    
    fi    
fi


rm $RUNNING


