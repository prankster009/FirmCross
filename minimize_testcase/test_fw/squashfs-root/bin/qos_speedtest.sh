#!/bin/sh
# qos auto mode

. /usr/share/libubox/jshn.sh
. /lib/hummer/api.sh


check_internet() {
    retval=""
    count=3
    while [ $count -gt 0  ]
    do
        if ping -c 1 www.ietf.org 2&>1 > /dev/null ; then
            break
        fi
        let count=$count-1
        sleep 1
    done

    if [ $count -eq 0  ]; then
        retval="false"
    else
        retval="true"
    fi
    echo "$retval"
}

json_load "$(objReq qos json)"
json_select "QosP"
json_get_vars enable wanRateMode

if [ "$enable" = "0" ]; then
    log_info "speedtest" "qos is disabled"
    exit 0
fi

if [ "$wanRateMode" = "1" ]; then
    log_info "speedtest" "exit due to the manual setup mode"
    exit 0
fi

# Disable qos first before we do the speedtest.
uci set qos.wan.enabled='0'
qos-start

speedtest_retry=3
while true
do
    retval=$( check_internet )
    if [ "$retval" == "true" ]; then
        log_info "speedtest" "Internet is OK"
        log_info "speedtest" "start the speedtest"
        /usr/bin/speedtest.lua > /tmp/speedtest.result
        upload_speed=$(cat /tmp/speedtest.result | grep Upload | awk '{print $4}')
        if [ -n "$upload_speed" -a $upload_speed -gt 512 ]; then
            log_info "speedtest" "upload speed is $upload_speed kbps"
            log_info "speedtest" "start qos"
            uci set qos.wan.upload="$upload_speed"
            uci set qos.wan.enabled='1'
            uci commit qos
            qos-start
            exit 0
        else
            log_info "speedtest" "failed to measure the upload speed!"
            let speedtest_retry=$speedtest_retry-1
        fi

        if [ $speedtest_retry -eq 0 ]; then
            log_info "speedtest" "stop the speedtest!"
            exit 0
        fi
    fi
    sleep 3
done
