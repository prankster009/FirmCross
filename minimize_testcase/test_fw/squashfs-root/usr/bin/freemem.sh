#!/bin/sh

log() {
	echo "[free memory] $@" > /dev/console
}
. /usr/share/libubox/jshn.sh

CRONTAB_ROOT="/etc/crontabs/root"

json_load "$(objReq easyMeshBasic json)"
json_select EasyMeshBasicP
json_get_var Enable enable
json_select ".."

usage () {
	log "Wrong parameter!!!"
}

action=$1
case $action in
    dofree)
        log "run free memory!!!"
		# free memory
		sync
		echo "3" > /proc/sys/vm/drop_caches
    ;;
    setup)
		sed -i '/freemem/d' $CRONTAB_ROOT
		log "easymesh disable, auto free memory disable!!!"
		if [ "$Enable" == "1" ]; then
			random1=$(tr -dc 1-9 </dev/urandom | head -c 3)
			min=$(((random1+1) % 60))
			echo "$min 6 * * * /usr/bin/freemem.sh dofree #easymesh free memory" >> $CRONTAB_ROOT
			log "easymesh enable, auto free memory!!!"
		fi
    ;;
    *)
        usage
    ;;
esac

