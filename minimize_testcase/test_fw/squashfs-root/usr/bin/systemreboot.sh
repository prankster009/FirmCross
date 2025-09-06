#!/bin/sh

log() {
	echo "[System Reboot] $@" > /dev/console
}

REBOOTSTOPPATH="/tmp/upgrade_reboot_skip"
system_reboot() {
	reboot -f -d 3
}

verify_gemtek_header() {
    log "Verify firmware header..."

    GEMTEK_HDR="/tmp/gemtek.hdr"
    FILE_PATH=$(cat /tmp/fwpath)
    FILE_LENGTH=$(stat -c%s $FILE_PATH)
    FW_LENGTH=$(expr $FILE_LENGTH - 16)
    dd if="$FILE_PATH" of="$GEMTEK_HDR" skip="$FW_LENGTH" bs=1 count=256 > /dev/console

    HDR_MAGIC_STRING="$(cat $GEMTEK_HDR | cut -b 1-8)"
    if [ "$HDR_MAGIC_STRING" != ".GEMTEK." ]; then
        log "Wrong magic string."
        exit 1
    fi

    HDR_FW_CRC="$(cat $GEMTEK_HDR | cut -b 9-16)"
    FW_CRC=$(dd if="$FILE_PATH" bs="$FW_LENGTH" count=1 | cksum | cut -d' ' -f1)
    FW_HEX_CRC=$(printf "%08X" $FW_CRC)
    if [ "$HDR_FW_CRC" != "$FW_HEX_CRC" ]; then
        log "firmware checksum error."
        exit 1
    fi

    log "Done"
}

system_upgrade() {
    ROOTFS_MTD_NO=$(cat /proc/self/mountinfo | grep "\/dev\/root" | cut -f3 -d' ' | cut -f2 -d':')
    CURR_FW_MTD_NO=
    NEXT_FW_MTD_NO=
    NEXT_BOOT_PART=
    AUTO_RECOVERY=$(gcontrol uenv get auto_recovery | awk -F"=" '{print $2}')

    log "Do firmware upgrade..."
    log "auto_recovery = $AUTO_RECOVERY"
    if [ "$AUTO_RECOVERY" = "yes" ]; then
        let CURR_FW_MTD_NO=$ROOTFS_MTD_NO-1
        if [ "$CURR_FW_MTD_NO" = "6" ]; then
            log "Current fw mtd is mtd6. Next fw mtd is mtd9 (alt_firmware)."
            NEXT_FW_MTD_NO=9
            NEXT_BOOT_PART=2
        elif [ "$CURR_FW_MTD_NO" = "7" ]; then
            log "Current fw mtd is mtd7. Next fw mtd is mtd6 (firmware)."
            NEXT_FW_MTD_NO=6
            NEXT_BOOT_PART=1
        else
            log "Unknown current fw mtd location."
            log "Failed to upgrade firmware."
            exit 2
        fi

        fwpath=`cat /tmp/fwpath`
        /sbin/mtd erase /dev/mtd${NEXT_FW_MTD_NO}
        /sbin/mtd write $fwpath /dev/mtd${NEXT_FW_MTD_NO}
        /usr/bin/gcontrol uenv set boot_part $NEXT_BOOT_PART
        /usr/bin/gcontrol uenv commit
    else
        fwpath=`cat /tmp/fwpath`
        /sbin/sysupgrade -n $fwpath
    fi

    if [ -f "$REBOOTSTOPPATH" ]; then
        log "Skip reboot!!!"
    else
        log "Reboot"
        reboot -d 3
    fi
}

system_reset() {
	local mesh_enable=$(objReq easyMeshBasic show | head -n 1 | awk -F " " '{print $3}')
	local mesh_role=$(cat /etc/map/mapd_cfg | grep DeviceRole | awk -F "=" '{print $2}')

	if [ "$mesh_enable" = "1" -a "$mesh_role" = "1" ]; then
		echo 1 > /tmp/controller_reset
		killall -SIGUSR1 mapd_iface
		sleep 5
	fi

	rm -f /tmp/gdata/conf.dat
	rm -f /tmp/gdata/mapd_user.cfg
	rm -f /tmp/gdata/agent_names
	rm -rf /overlay/*
	if [ -z $1 ]; then
		reboot -d 3
	else
		reboot
	fi
}


usage(){
    echo "$0 [ start ]"
    exit 1
}

action=$1
case "$action" in
    reboot)
            system_reboot ;;
    reset)
            system_reset $2;;
    upgrade)
            #verify_gemtek_header
            system_upgrade ;;
    *)
            usage ;;
esac

