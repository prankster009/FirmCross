#!/bin/sh

log() {
	echo "[Led set] $@" > /dev/console
}

LED_NET_ORANGE=13
LED_NET_BLUE=15
LED_WPS=5
LED_PWR=10

system_ready() {
	gpio l $LED_WPS 4000 1 1 1 1
	gpio l $LED_PWR 1 4000 1 1 1
}

system_booting() {
	gpio l $LED_WPS 4000 1 1 1 1
	gpio l $LED_PWR 7 7 1 1 4000
}

wps_start() {
	gpio l $LED_WPS 4000 1 1 1 1
	gpio l $LED_PWR 10 10 1 1 4000
}

wps_fail() {
	gpio l $LED_PWR 4000 1 1 1 1
	gpio l $LED_WPS 10 10 1 1 4000
}

wps_finish() {
	gpio l $LED_PWR 1 4000 1 1 1
	gpio l $LED_WPS 4000 1 1 1 1
}

easymesh_wps_start (){
	gpio l $LED_WPS 4000 1 1 1 1
	gpio l $LED_PWR 3 3 1 1 4000
}

internet_ready () {
	gpio l $LED_NET_ORANGE 4000 1 1 1 1
	gpio l $LED_NET_BLUE 1 4000 1 1 1
}

internet_connect_fail() {
	gpio l $LED_NET_BLUE 4000 1 1 1 1
	gpio l $LED_NET_ORANGE 1 4000 1 1 1
}

no_internet_connect() {
	gpio l $LED_NET_BLUE 4000 1 1 1 1
	gpio l $LED_NET_ORANGE 5 5 1 1 4000
}

easymesh_too_far() {
	gpio l $LED_PWR 4000 1 1 1 1
	gpio l $LED_WPS 1 4000 1 1 1
}

usage() {
	log "Unknown led status!!"
}

INTERNETREADY="0"
INTERNETFAIL="1"

PWRMESHFAR="0"
PWRWPS="1"
PWRWPSFAIL="2"
PWRWPSSUCCESS="3"
PWRMESHWPS="4"

LEDSTATUSPATH="/tmp/ledstatus"
PWRLEDSTATUSPATH="/tmp/ledstatus_power"

OLDSTATUS=`cat $LEDSTATUSPATH`
PWROLDSTATUS=`cat $PWRLEDSTATUSPATH`

action=$1
case "$action" in
    system_ready)
            system_ready ;;
    system_booting)
            system_booting ;;
    wps_start)
            [ "$PWROLDSTATUS" != "$PWRWPS" ] && {
                wps_start
                echo $PWRWPS > $PWRLEDSTATUSPATH
            } ;;
    wps_fail)
            [ "$PWROLDSTATUS" != "$PWRWPSFAIL" ] && {
                wps_fail
                echo $PWRWPSFAIL > $PWRLEDSTATUSPATH
            } ;;
    wps_finish)
            [ "$PWROLDSTATUS" != "$PWRWPSSUCCESS" ] && {
                wps_finish
                echo $PWRWPSSUCCESS > $PWRLEDSTATUSPATH
            } ;;
    easymesh_wps_start)
            [ "$PWROLDSTATUS" != "$PWRMESHWPS" ] && {
                easymesh_wps_start
                echo $PWRMESHWPS > $PWRLEDSTATUSPATH
            } ;;
    easymesh_too_far)
            [ "$PWROLDSTATUS" != "$PWRMESHFAR" ] && {
                easymesh_too_far
                echo $PWRMESHFAR > $PWRLEDSTATUSPATH
            } ;;
    internet_ready)
            [ "$OLDSTATUS" != "$INTERNETREADY" ] && {
                internet_ready
		echo $INTERNETREADY > $LEDSTATUSPATH
	    } ;;
    internet_connect_fail)
            [ "$OLDSTATUS" != "$INTERNETFAIL" ] && {
                internet_connect_fail
		echo $INTERNETFAIL > $LEDSTATUSPATH
	    } ;;
    no_internet_connect)
            no_internet_connect ;;
    *)
            usage ;;
esac

