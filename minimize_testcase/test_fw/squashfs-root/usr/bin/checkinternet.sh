#!/bin/sh

log() {
	echo "[internet status] $@" > /dev/console
}

sleep 3
log "Start to check internet status"

_SERVER1="8.8.8.8"
_SERVER2="9.9.9.9"

if [ -z $1 ]; then
	PINGIF=""
else
	PINGIF="-I $1"
fi

LEDSTATUSPATH="/tmp/ledstatus"
rm -f $LEDSTATUSPATH

while [ 1 ];
do
	result="$(ping -q -c 2 -W 1 $PINGIF $_SERVER1 2&>1 > /dev/null; echo $?)"
	if [ $result = "1" ]; then
		result="$(ping -q -c 2 -W 1 $PINGIF $_SERVER2 2&>1 > /dev/null; echo $?)"
	fi

	if [ $result = "0" ]; then
		/usr/bin/ledstatus.sh internet_ready
	else
		/usr/bin/ledstatus.sh internet_connect_fail
	fi
	sleep 30
done
