#!/bin/sh

. /usr/share/libubox/jshn.sh

log() {
    echo "[Firmware check] $@" > /dev/console
}

verify_gemtek_header() {
    log "Verify firmware header..."
    ret=0
    GEMTEK_HDR="/tmp/gemtek.hdr"
    FILE_PATH=$(cat $1)
    [ -n "$FILE_PATH" ] && {
        log "Get firmware path $FILE_PATH"
        ret=1
        FILE_LENGTH=$(stat -c%s $FILE_PATH)
        FW_LENGTH=$(expr $FILE_LENGTH - 16)
        dd if="$FILE_PATH" of="$GEMTEK_HDR" skip="$FW_LENGTH" bs=1 count=256 > /dev/console

        HDR_MAGIC_STRING="$(cat $GEMTEK_HDR | cut -b 1-8)"
        if [ "$HDR_MAGIC_STRING" != ".GEMTEK." ]; then
            log "Wrong magic string."
            ret=0
        fi

        HDR_FW_CRC="$(cat $GEMTEK_HDR | cut -b 9-16)"
        FW_CRC=$(dd if="$FILE_PATH" bs="$FW_LENGTH" count=1 | cksum | cut -d' ' -f1)
        FW_HEX_CRC=$(printf "%08X" $FW_CRC)
        if [ "$HDR_FW_CRC" != "$FW_HEX_CRC" ]; then
            log "firmware checksum error."
            ret=0
        fi
    }

    log "Check firmware Done and status [$ret]"
    return $ret
}

check_memory() {
    MEMSIZE="$(grep 'MemFree:' /proc/meminfo | tr -s ' ' | cut -d ' ' -f 2)"
    log "Free memory is $MEMSIZE"
    LESSMEMSIZE="30000"
    if [ "$MEMSIZE" -lt "$LESSMEMSIZE" ]; then
        log "Check memoey too low!!!"
        ret=0
    else
        ret=1
    fi
    return $ret
}

do_version_check() {
    [ "$1" == "$2" ] && return 1

    vs_front=`echo $1 | cut -d "." -f -1`
    vs_back=`echo $1 | cut -d "." -f 2-`

    vl_front=`echo $2 | cut -d "." -f -1`
    vl_back=`echo $2 | cut -d "." -f 2-`

    if [ "$vs_front" != "$1" ] || [ "$vl_front" != "$2" ]; then
        [ "$vs_front" -gt "$vl_front" ] && return 2
        [ "$vs_front" -lt "$vl_front" ] && return 0

        [ "$vs_front" == "$1" ] || [ -z "$vs_back" ] && vs_back=0
        [ "$vl_front" == "$2" ] || [ -z "$vl_back" ] && vl_back=0
        do_version_check "$vs_back" "$vl_back"
        return $?
    else
        [ "$1" -gt "$2" ] && return 2 || return 0
    fi
}

URL="https://update1.linksys.com"
BASEMAC=`cat /tmp/devinfo/hw_mac_addr`
if [ -n $BASEMAC ]; then
    tmpMAC=`echo ${BASEMAC:0:15}``printf "%02X\n" $((0x${BASEMAC:15:2}+1))`
    MAC=`echo $tmpMAC | sed s/:/-/g`
else
    MAC=`cat /sys/class/net/eth1/address | sed s/:/-/g`
fi
#MODLE_NAME=`gcontrol di get modelNumber | awk -F '=' '{print $2}'`
MODLE_NAME=`cat /tmp/devinfo/modelNumber`
#HW_VERSION=`gcontrol di get hw_version | awk -F '=' '{print $2}'`
HW_VERSION=`cat /tmp/devinfo/hw_revision`
VERSION=`cat /etc/version | awk -F ' ' '{print $1}'`
#SN=`gcontrol di get serial_number | awk -F '=' '{print $2}'`
SN=`cat /tmp/devinfo/serial_number`

json_load "$(objReq wan json)"
json_select WanP
json_get_var proto proto
#log "wan mode $proto"
if [ $proto = "5" -o $proto = "6" ]; then
    IFNAME="br-lan"
else
    IFNAME="eth1"
fi
IP=`ifconfig $IFNAME | grep "inet addr" | awk -F ':' '{print $2}' | cut -d " " -f 1`

#MAC="te-st-00-00-00-00"
#SN="123"
#HW_VERSION=`echo ${HW_VERSION:$((${#HW_VERSION}-1)):1}`
if [ -n $HW_VERSION ]; then
    HW_VERSION=`expr $HW_VERSION + 1`
else
    HW_VERSION='1'
fi

RETPATH="/tmp/checkfw"
[ -n "$1" -a "$1" != "upgrade" ] && { RETPATH=$1; }

CMD="$URL/api/v2/fw/update?mac_address=$MAC&hardware_version=$HW_VERSION&model_number=$MODLE_NAME&installed_version=$VERSION&ip_address=$IP&serial_number=$SN"

#log $CMD

rm -f $RETPATH
wget --no-cache --output-document - "$CMD" > $RETPATH &
num=0
ret=""
while [ -z "$ret" -a $num -le 4 ]
do
    num=$(( num+1 ))
    log "Wait to check server return!!!"
    sleep 1
    ret=`cat $RETPATH`
done
killall -9 wget

ret=""
num=0
[ "$1" = "upgrade" ] && {
log "Start Auto firmware upgrade"
doupgrade='0'
SERVERVERSION=`cat $RETPATH | grep "version" | cut -d '"' -f 4`
LOCALVERSION=`cat /etc/version`
if [ -n "$SERVERVERSION" ]; then
    log "Check firmware version"
    do_version_check $SERVERVERSION $LOCALVERSION
    case $? in
        0) log "Firmware is newer!"
            ;;
        1) log "Firmware is up to date!"
            ;;
        2) log "New firmware can be upgraded!"
            doupgrade='1'
            ;;
    esac
fi
if [ "$doupgrade" = "1" ]; then
    downloadurl=`cat $RETPATH | grep "download_url" | cut -d '"' -f 12`
    if [ -n "$downloadurl" ]; then
        log "Get url $downloadurl"
        rm -rf /tmp/*.img
        rm -f /tmp/fwstatus

        #check memory first
        check_memory
        retval=$?
        if [ "$retval" = "1" ]; then
            wget -P /tmp $downloadurl > /tmp/fwstatus 2>&1 &
            while [ "$ret" != "100" -a $num -le 1000 ]
            do
                sleep 1
                ret=`echo -ne "$(tr $'\r' $'\n' < /tmp/fwstatus | tail -n 1 | sed -r 's/^[# ]+/#/;')\r" | cut -d '%' -f 1`
                ret=`echo $ret | cut -d ' ' -f 2`
                echo $ret > /tmp/fwperc
                num=$(( num+1 ))
                #log "Check firmware time $num, ret $ret"
            done
            killall -9 wget
            rm -f /tmp/fwstatus
            if [ "$ret" = 100 ]; then
                ls /tmp/*.img > /tmp/fwpath
                verify_gemtek_header '/tmp/fwpath'
                retval=$?
                if [ "$retval" = 1 ]; then
                    log "Start firmware upgrade"
                    rcConf start fwupgrade && rcConf run
                else
                    log "check firmware fail!"
                    echo "-1" > /tmp/fwperc
                    rm -f /tmp/*.img
                fi
            else
                log "Download firmware from server fail!!"
                echo "-1" > /tmp/fwperc
                rm -f /tmp/*.img
            fi
        else
            log "Low memory, skip firmware upgrade!!!"
            echo "-1" > /tmp/fwperc
        fi
    else
        log "Can't get server firmware!!!"
        echo "-1" > /tmp/fwperc
    fi
else
    log "Don't need firmware upgrade!!!"
    echo "-1" > /tmp/fwperc
fi
}

