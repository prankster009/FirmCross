#!/bin/sh

. /usr/share/libubox/jshn.sh
doauto="0"
check_guest() {
	json_load "$(objReq wlanGuest json)"
	json_select "WlanGuestT"
	json_select "1"
	json_get_vars maxStaNum
	json_select ".."

	json_load "$(objReq lan json)"
	json_select "LanP"
	json_get_vars ipaddr
	json_select ".."

	##Check lan ip if the same as default guest
	checkguest=`echo $ipaddr | grep "192.168.33."`
	if [ -n "$checkguest" ]; then
		guestnet="192.168.34."
	else
		guestnet="192.168.33."
	fi
	echo "Get guest net=$guestnet"

	guestauthnum=`/usr/bin/ndsctl clients | head -n 1`
	echo "Get auth guest number=$guestauthnum, max client=$maxStaNum" > /dev/console
	if [ $guestauthnum == $maxStaNum -a $guestauthnum != 0 ]; then
		guestmac=`/usr/bin/ndsctl clients | grep mac | head -n 1 | cut -d "=" -f 2`
		[ -n "$guestmac" ] && {
			echo "Get first guest mac=$guestmac"
			doauto="1"
		}
	else
		echo "Guest number not full!!!"
	fi
}

if [ "$1" == "ra1" -o "$1" == "rai1" ]; then
	check_guest
	[ "$doauto" == "1" ] && {
		echo "===deauth $guestmac client limit===" > /dev/console
		/usr/bin/ndsctl deauth "$guestmac"
	}
else
	if [ "$1" == "mac" -a -n "$2" ]; then
		echo "===deauth $2 leave client===" > /dev/console
		/usr/bin/ndsctl deauth "$2"
	else
		echo "Param1=$1, cmd error !!!"
	fi
fi
