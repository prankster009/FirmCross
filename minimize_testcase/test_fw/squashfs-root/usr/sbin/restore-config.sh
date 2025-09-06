#!/bin/sh
#
#       restore-config.sh [Path to config]
#

main() {
	local argc=$1; shift
	local path=$1

	tar -zxvf $path -C /tmp
	if [ -f /tmp/conf.dat ] && [ -f /tmp/conf.md5sum ]; then
		#check md5sum
		gmd5=`cat /tmp/conf.md5sum`
		fmd5=`md5sum /tmp/conf.dat`
		if [ "$fmd5" == "$gmd5" ]; then
			cp -f /tmp/conf.dat /tmp/gdata/conf.dat
			sync
			rcConf start sysreboot
			rcConf run
		else
			exit -1
		fi
	else
		exit -1
	fi

}

main $# "$@"

exit 0
