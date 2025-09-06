#!/bin/sh
#
#       sysupgrade.sh [Path to firmware]
#

verify_gemtek_header() {
	GEMTEK_HDR="/tmp/gemtek.hdr"
	FILE_PATH="$1"
	FILE_LENGTH=$(stat -c%s $FILE_PATH)
	FW_LENGTH=$(expr $FILE_LENGTH - 16)
	dd if="$FILE_PATH" of="$GEMTEK_HDR" skip="$FW_LENGTH" bs=1 count=256 > /dev/console

	HDR_MAGIC_STRING="$(cat $GEMTEK_HDR | cut -b 1-8)"
	if [ "$HDR_MAGIC_STRING" != ".GEMTEK." ]; then
		exit -1
	fi

	HDR_FW_CRC="$(cat $GEMTEK_HDR | cut -b 9-16)"
	FW_CRC=$(dd if="$FILE_PATH" bs="$FW_LENGTH" count=1 | cksum | cut -d' ' -f1)
	FW_HEX_CRC=$(printf "%08X" $FW_CRC)
	if [ "$HDR_FW_CRC" != "$FW_HEX_CRC" ]; then
		exit -1
	fi
}

main() {
	local argc=$1; shift
	local path=$1
	#Do fw upgrade
	echo $path > /tmp/fwpath
	verify_gemtek_header "$path"
	rcConf start fwupgrade
	rcConf run
}

main $# "$@"

exit 0
