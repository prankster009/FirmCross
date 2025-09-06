#!/bin/sh
#
#       backup-config.sh [Path to config]
#

main() {
	local argc=$1; shift
	local path=$1

	cp -f /tmp/gdata/conf.dat /tmp/conf.dat
	md5sum /tmp/conf.dat > /tmp/conf.md5sum
	tar -zcvf $path -C /tmp conf.dat conf.md5sum >/dev/null 2>&1

	rm -f /tmp/conf.dat /tmp/conf.md5sum
}

main $# "$@"

exit 0
