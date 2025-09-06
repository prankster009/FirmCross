#!/bin/sh
# 2018 Hua Shao <hua.shao@mediatek.com>


profile_backup() {
	echo "profile_backup"
}


profile_diff() {
	echo "profile_diff"
}



# vifs_up and vifs_down accept ifname patterns, for example:
#
#	 vifs_up ra0			 -- ra0
#	 vifs_up rai0			-- rai0
#	 vifs_up ra?			 -- ra0, ra1, ..., ra9, raa, rab, ....
#	 vifs_up ra*			 -- ra0, rai0, ra1, rai1asdfasdfasdf, ....
#	 vifs_up ra[0-9]		 -- ra0, ra1, ..., ra9
#	 vifs_up ra1[1-3]		-- ra11, ra12, ra13
#	 vifs_up ra[0-9]*		-- ra0, ra1, ..., ra10, ra11, ....

vifs_up() {
	[ "$1" == "" ] && exit
	local ifname=$1 # can be pattern
	local bridge=$2 # usually br-lan
	cd /sys/class/net
	for vif in `set +f;ls -d *${ifname} 2>/dev/null;set -f`; do
		disabled=`uci -q get wireless.${vif}.disabled`
		if [ "${disabled}" == "1" ]; then continue; fi
		ifconfig ${vif} up;
		[ "${bridge}" == "" -o "${vif}" == "" ] || {
			brvifs=`uci get network.lan.ifname`
			if echo ${brvifs} | grep -q ${vif}; then
				echo "already there!" > /dev/null;
			else
				uci set network.lan.ifname="${brvifs} ${vif}";
				uci commit;
			fi
			brctl addif ${bridge} ${vif} 2>/dev/null || true;
			ubus call network.interface.lan add_device "{\"name\":\"${vif}\"}" 2>/dev/null || true;
		}
	done
}

vifs_down() {
	[ "$1" == "" ] && exit
	local ifname=$1 # can be pattern
	local bridge=$2 # usually br-lan
	cd /sys/class/net
	for vif in `set +f;ls -d *${ifname} 2>/dev/null;set -f`; do
		ifconfig $vif down;
	done

	[ "${bridge}" == "" -o "${vif}" == "" ] || {
		brvifs=`uci get network.lan.ifname`
		if echo ${brvifs} | grep -q ${vif}; then
			echo "will remove ${vif} from ${bridge}!" > /dev/null;
			brvifs=`uci get network.lan.ifname | sed "s/${vif}//g"`
			uci set network.lan.ifname="${brvifs}";
			uci commit;
		fi
		brctl delif ${bridge} ${vif} 2>/dev/null || true;
		ubus call network.interface.lan remove_device "{\"name\":\"${vif}\"}" 2>/dev/null || true;
	}
}


# common API for mt76xx drivers
# $1 = devname
# $2 = driver
mt76xx_up() {
	local devname=`echo $1 | sed 's/\./_/g'`
	local driver=$2
	local devs

	[ -f /lib/modules/`uname -r`/${driver}.ko ] && modprobe ${driver}.ko

	if [ "$devname" == "" ]; then
		for devname in $L1DEVNAMES; do
			eval init_compatible=\$${devname}_init_compatible
			if [ "${init_compatible}" == "${driver}" ]; then
				devs="$devname $devs"
			fi
		done
	else
		devs=$devname
	fi

	for devname in $devs; do
		# 1. call uci2dat to save uci changes into profile
		eval profile=\${${devname}_profile_path}
		eval main_ifname=\$${devname}_main_ifname
		eval ext_ifname=\$${devname}_ext_ifname

		uci2dat -d ${devname} -f ${profile}
		vifs_up ${main_ifname} br-lan
		set -f
		vifs_up ${ext_ifname}[0-9]* br-lan
		set +f
	done
}




# $1 = devname
# $2 = driver
mt76xx_down() {
	local devname=`echo $1 | sed 's/\./_/g'`
	local driver=$2
	local devs

	if [ "$devname" == "" ]; then
		for devname in $L1DEVNAMES; do
			eval init_compatible=\$${devname}_init_compatible
			if [ "${init_compatible}" == "${driver}" ]; then
				devs="$devs $devname"
			fi
		done
	else
		devs=$devname
	fi

	for devname in $devs; do
		# 1. call uci2dat to save uci changes into profile(DBDC Mode)
		eval profile=\${${devname}_profile_path}
		eval main_ifname=\$${devname}_main_ifname
		eval ext_ifname=\$${devname}_ext_ifname

		uci2dat -d ${devname} -f ${profile}
		vifs_down ${main_ifname} br-lan
		set -f
		vifs_down ${ext_ifname}[0-9]* br-lan
		set +f
	done
}


# $1 = devname
# $2 = driver
mt76xx_reload() {
	local devname=`echo $1 | sed 's/\./_/g'`
	local devnames=${devname}
	local driver=$2
	local need_restart=0
	local need_downup=0
	if [ "${devnames}" == "" ]; then
		if [ "${driver}" == "" ]; then
			echo "Invalid arguments! Both devname and driver are empty."
		fi
		for dev in ${L1DEVNAMES}; do
			eval compat=\${${dev}_init_compatible}
			if [ "${compat}" == "${driver}" ]; then
				devnames="${dev} ${devnames}"
			fi
		done
	fi

	for devname in ${devnames}; do
		eval profile=\${${devname}_profile_path}

		# 0. backup profiles first
		mkdir -p /tmp/mtk/wifi
		local profile_bak=`echo ${profile} | awk -F "/" '{print $(NF-0)}'`
		profile_bak=/tmp/mtk/wifi/${profile_bak}.bak
		cp ${profile} ${profile_bak} || true

		# 1. call uci2dat to save uci changes into profile
		uci2dat -d ${devname} -f ${profile}

		# 2. check if we can do quick reload, "uci changes wireless" is a possible alternative
		datdiff ${profile_bak} ${profile} > /tmp/mtk/wifi/datdiff-${devname}.tmp
		if cat /tmp/mtk/wifi/datdiff-${devname}.tmp | grep -q BssidNum=; then
			# need call mt76xx_restart
			need_restart=1
			mt76xx_restart "" "${driver}"
		fi

		if cat /tmp/mtk/wifi/datdiff-${devname}.tmp\
			| grep -Eq '(HT_LDPC|VHT_SGI|VHT_BW_SIGNAL|VHT_LDPC|E2pAccessMode|HT_BSSCoexistence)='; then
			need_downup=1
		fi

		# 3. quick reload
		if [ "0" == "${need_downup}"  -a "0" == "${need_restart}" ]; then
			datdiff -x ${profile_bak} ${profile} > /tmp/mtk/wifi/datdiff-${devname}.sh
			cat /tmp/mtk/wifi/datdiff-${devname}.sh
			mt76xx_up "${devname}" "${driver}"
			sh /tmp/mtk/wifi/datdiff-${devname}.sh 2>/dev/null
		fi
	done

	#4 . normal reload (Both single band mode and DBDC mode)
	if [ "1" == "${need_downup}" -a "0" == "${need_restart}" ]; then
		# normal reload
		mt76xx_down "" "${driver}"
		mt76xx_up "" "${driver}"
	fi

	#5 . normal restart
	if [ "1" == "${need_restart}" ]; then
		# In order to display vifs in UI correctly
		uci2dat
		dat2uci
		[ -f "/tmp/mtk/wifi/reboot_required" ] && /sbin/wifi down && reboot -f >/dev/null 2>&1
	fi

	# remove tmp files
	# rm -f /tmp/mtk/wifi/*.dat.bak   || true
	# rm -f /tmp/mtk/wifi/*.sh  || true
	# rm -f /tmp/mtk/wifi/*.tmp || true
}




# $1 = devname
# $2 = driver
mt76xx_restart() {
	local devname=`echo $1 | sed 's/\./_/g'`
	local driver=$2

	[ -f /lib/modules/`uname -r`/${driver}.ko ] || echo "failed to detect ${driver}.ko"
	if [ -d /sys/module/${driver} ]; then
		mt76xx_down "${devname}" "${driver}"
		rmmod ${driver};
		modprobe ${driver}.ko;
		mt76xx_up "${devname}" "${driver}"
	else
		# if wifi driver is built-in, it's necessary action to reboot the device
		mkdir -p /tmp/mtk/wifi
		echo reboot_required > /tmp/mtk/wifi/reboot_required
	fi

}


# $1 = devname
# $2 = driver
mt76xx_detect() {
	dat2uci -l /etc/wireless/l1profile.dat -u /etc/config/wireless
}


# $1 = devname
# $2 = driver
mt76xx_status() {
	iwconfig
}

# $1 = devname
# $2 = driver
mt76xx_hello() {
	echo "mt76xx_hello($@)"
}

