#!/bin/sh

#echo "$#, $@" > /dev/console

check_status=-1

if [ "$#" = "5" ] ; then

    ifname_cmd=$1
    ssid=$2
    WIFI_CMD_AUTHTYPE=$3
    crypto=$4
    wpaPsk=$5
    check_status=0

else
    argFile="/tmp/wlanbridgeTest.arg"
    if [ -f "/tmp/wlanbridgeTest.arg" ] ; then
    
        argFile="/tmp/wlanbridgeTest.arg"
        ifname_cmd=`cat $argFile | awk -F '\n' 'NR==1 {print $1}'`
        ssid=`cat $argFile | awk -F '\n' 'NR==2 {print $1}'`
        WIFI_CMD_AUTHTYPE=`cat $argFile | awk -F '\n' 'NR==3 {print $1}'`
        crypto=`cat $argFile | awk -F '\n' 'NR==4 {print $1}'`
        wpaPsk=`cat $argFile | awk -F '\n' 'NR==5 {print $1}'`
        check_status=0
    fi

fi

[ "$check_status" = "-1" ] && echo "FAIL" && exit 1


WIFI_CMD_SSID=$(echo "$ssid" | sed 's/[$]/\$/g')
WIFI_CMD_SSID=$(echo "$WIFI_CMD_SSID" | sed 's/[`]/\`/g')
WIFI_CMD_SSID=$(echo "$WIFI_CMD_SSID" | sed 's/["]/\"/g')


WIFI_CMD_WPAPSK=$(echo "$wpaPsk" | sed 's/[$]/\$/g')
WIFI_CMD_WPAPSK=$(echo "$WIFI_CMD_WPAPSK" | sed 's/[`]/\`/g')
WIFI_CMD_WPAPSK=$(echo "$WIFI_CMD_WPAPSK" | sed 's/["]/\"/g')



usage(){
    echo "$0 [ifname] [ssid] [OPEN|WPAPSK|WPA2PSK] [NONE|AES|TKIP] [key]"
    exit 1
}



apcli_monitor_status()
{
    ret=0
    
	TIME=0
	STATUS_TIMEOUT=8
    local check_apccli_status ifname_connStatus
	ENDTIME=`date +%s`
	ENDTIME=`expr $ENDTIME + $STATUS_TIMEOUT`
	
	while [ true ] ; do
    
        check_apccli_status=""
        ifname_connStatus=""
        check_apccli_status=`iwconfig $ifname_cmd | grep ESSID | cut -d '"' -f 2 `
        sleep 2
        ifname_connStatus=`iwpriv $ifname_cmd show connStatus && dmesg | tail -n 5 | grep 'Connected AP' | grep Disconnect`
        
        
         if [ "$check_apccli_status" != "" -a "$ifname_connStatus" = "" ]; then
        
            ret=1
            break
        fi
        
    	TIME=0
        TIME=`date +%s`
        if [ $TIME -gt $ENDTIME ] ; then
        
            break
        fi	
        
        sleep 1
        
    done
    return $ret
}

do_wlanBridge_connect()
{

    ifconfig $ifname_cmd up
    sleep 1
    
    iwpriv $ifname_cmd set SiteSurvey=1
    sleep 4
    iwpriv $ifname_cmd get_site_survey | sed '$d' > /tmp/get_site_survey


    local site_survey=""
    sleep 1
    cat /tmp/get_site_survey | grep "$WIFI_CMD_SSID" | grep $WIFI_CMD_AUTHTYPE >  /tmp/get_site_survey_ssid
    
    site_survey=`cat /tmp/get_site_survey_ssid`

    iwpriv $ifname_cmd set ApCliEnable=0
    iwpriv $ifname_cmd set ApCliSsid="$WIFI_CMD_SSID"
    iwpriv $ifname_cmd set ApCliAuthMode=$WIFI_CMD_AUTHTYPE
    iwpriv $ifname_cmd set ApCliEncrypType=$crypto
    iwpriv $ifname_cmd set ApCliWPAPSK="$WIFI_CMD_WPAPSK"
    
    [ "$WIFI_CMD_AUTHTYPE" = "WPA3PSK" ] && iwpriv $ifname_cmd set ApCliPMFMFPC=1 && iwpriv $ifname_cmd set ApCliPMFMFPR=1 && iwpriv $ifname_cmd set ApCliPMFSHA256=1
    [ "$WIFI_CMD_AUTHTYPE" = "WPA2PSK" ] && iwpriv $ifname_cmd set ApCliPMFMFPC=1 && iwpriv $ifname_cmd set ApCliPMFMFPR=0 && iwpriv $ifname_cmd set ApCliPMFSHA256=0
    [ "$WIFI_CMD_AUTHTYPE" = "WPAPSK"  ] && iwpriv $ifname_cmd set ApCliPMFMFPC=0 && iwpriv $ifname_cmd set ApCliPMFMFPR=0 && iwpriv $ifname_cmd set ApCliPMFSHA256=0
    [ "$WIFI_CMD_AUTHTYPE" = "OPEN"    ] && iwpriv $ifname_cmd set ApCliPMFMFPC=0 && iwpriv $ifname_cmd set ApCliPMFMFPR=0 && iwpriv $ifname_cmd set ApCliPMFSHA256=0
    
    iwpriv $ifname_cmd set HtBw=0
    iwpriv $ifname_cmd set ApCliEnable=1
    
    if [ "$site_survey" != "" ]; then

        count=4
        while [ $count -gt 0 -a "$site_survey" != "" ]
        do
            iwpriv $ifname_cmd set ApCliEnable=0
            
            ch=`echo $site_survey | awk 'NR==1 {print $2}' `
            ssid=`echo $site_survey | awk 'NR==1 {print $3}' `
            security=`echo $site_survey | awk 'NR==1 {print $5}' `
            excha=`echo $site_survey | awk 'NR==1 {print $8}' `
            
            [ "$ch" != "" ] && iwpriv $ifname_cmd set Channel=$ch

            iwpriv $ifname_cmd set ApCliEnable=1
            #echo "$ch $ssid $security $excha" > /dev/console
            apcli_monitor_status
            check_status=$?
            
            if [ "$check_status" = "1" ]; then 
		    
            
                break
            fi
            
            let count=$count-1
            sed -i '1d' /tmp/get_site_survey_ssid
            sleep 1
            site_survey=`cat /tmp/get_site_survey_ssid`
        done
    fi
    ifconfig $ifname_cmd down

}  
######################################################################
check_status=0
do_wlanBridge_connect

if [ "$check_status" = "1" ] ;then
    echo "PASS"
else   
    echo "FAIL"
fi






