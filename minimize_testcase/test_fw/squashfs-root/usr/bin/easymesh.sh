#!/bin/sh

RUNNING="/tmp/easymesh.sh-running"
# make sure only one script is running
while :
do
	if [ ! -f "$RUNNING" ] ; then
		break
	fi
	echo "exist $RUNNING" > /dev/console
	return 1
done
echo 1 > $RUNNING

. /usr/share/libubox/jshn.sh
. /lib/hummer/api.sh

usage() {
	echo "[ update_config | update_bss_config | renew | reload | start | stop | switch_reg ]" > /dev/console
}

easymesh_setup_param() {
	json_load "$(objReq easyMeshBasic json)"
	json_select EasyMeshBasicP
	json_get_var Enable enable
	json_get_var DevRole deviceRole
	json_select ".."
}

encryp2code() {
	encryp_code="0x0008"
	if [ "$1" = "AES" ]; then
		encryp_code="0x0008"
	else
		log_info "easymesh" "unknown encryption type $1, use aes..."
	fi
	echo "$encryp_code"
}

auth2code() {
	auth_code="0x0020"
	#case $1 in
	#	OPEN)
	#		auth_code="0x0001"
	#	;;
	#	WPA2PSK)
	#		auth_code="0x0020"
	#	;;
	#	WPA3PSK)
	#		auth_code="0x0060"
	#	;;
	#	*)
	#		log_info "easymesh" "unknown authentication type $1, use wpa2psk..."
	#	;;
	#esac
	echo "$auth_code"
}

space_handler() {
	echo "$1" | sed -r 's/( |\\)/\\\1/g'
}

write_bss_config() {
	log_info "easymesh" "writing bss config..."

	json_load "$(objReq easyMeshBss json)"
	json_select EasyMeshBssP
	json_get_var ssid ssid
	json_get_var auth_type authType
	json_get_var encryp_type encrypType
	json_get_var wpapsk wpaPsk
	json_get_var ssid_5g ssid5G
	json_get_var auth_type_5g authType5G
	json_get_var encryp_type_5g encrypType5G
	json_get_var wpapsk_5g wpaPsk5G
	json_select ".."

	ssid=$(space_handler "$ssid")
	ssid_5g=$(space_handler "$ssid_5g")

	wpapsk=$(space_handler "$wpapsk")
	wpapsk_5g=$(space_handler "$wpapsk_5g")

	log_info "easymesh" "ssid: $ssid, wpapsk: $wpapsk"
	log_info "easymesh" "authtype: $auth_type, encryptype5G: $encryp_type"
	log_info "easymesh" "ssid5G: $ssid_5g, wpapsk5G: $wpapsk_5g"
	log_info "easymesh" "authtype5G: $auth_type_5g, encryptype5G: $encryp_type_5g"

	auth_code=$(auth2code $auth_type)
	encryp_code=$(encryp2code $encryp_type)
	auth_code_5g=$(auth2code $auth_type_5g)
	encryp_code_5g=$(encryp2code $encryp_type_5g)

	echo "#ucc_bss_info
1,ff:ff:ff:ff:ff:ff 8x $ssid $auth_code $encryp_code $wpapsk 1 1 hidden-N
2,ff:ff:ff:ff:ff:ff 11x $ssid_5g $auth_code_5g $encryp_code_5g $wpapsk_5g 1 1 hidden-N
3,ff:ff:ff:ff:ff:ff 12x $ssid_5g $auth_code_5g $encryp_code_5g $wpapsk_5g 1 1 hidden-N
" > /etc/map/wts_bss_info_config

	log_info "easymesh" "write bss config down"
}

modify_switch_reg() {
	# To make switch related MC register setting for eth on platform mt7621
	switch reg w 10 ffffffe0
	switch reg w 34 8160816

	log_info "easymesh" "modify switch reg down"
}

kill_daemon() {
	rm -rf /tmp/wapp_ctrl
	killall -15 mapd
	killall -15 wapp
	killall -15 p1905_managerd
	killall -15 bs20

	killall mapd_iface
	sleep 5
	rmmod mapfilter

	log_info "easymesh" "kill daemon down"
}

start_daemon() {
	log_info "easymesh" "WAPP starting..."
	wapp_openwrt.sh > /dev/console&

	# must sleep or the behavior will be abnormal
	sleep 3

	log_info "easymesh" "1905 starting..."
	if [ "$DevRole" = "1" ]; then
		p1905_managerd -r0 -f "/etc/map/1905d.cfg" -F "/etc/wts_bss_info_config" > /dev/console&
	else
		p1905_managerd -r1 -f "/etc/map/1905d.cfg" -F "/etc/wts_bss_info_config" > /dev/console&
	fi

	sleep 3

	log_info "easymesh" "MAP_Daemon starting..."
	mapd -G "/etc/wts_bss_info_config" -I "/etc/map/mapd_cfg" -O "/etc/mapd_strng.conf" > /dev/console&

	sleep 3

	log_info "easymesh" "start daemon down"
}

controller_setup() {
	iwpriv ra0 set bhbss=1;
	iwpriv rai0 set bhbss=1;
	iwpriv ra0 set DisConnectAllSta=
	iwpriv rai0 set DisConnectAllSta=

	log_info "easymesh" "controller setup down"
}

write_basic_config() {
	log_info "easymesh" "writing basic config..."

	mapd_cfg_path="/etc/map/mapd_cfg"
	p1905_cfg_path="/etc/map/1905d.cfg"

	if [ "$Enable" = "1" ]; then
		log_info "easymesh" "write enable config"

		case $DevRole in
			0)
				# auto
				wificonf -f $mapd_cfg_path set DeviceRole 0
			;;
			1)
				# controller
				wificonf -f $mapd_cfg_path set DeviceRole 1
				wificonf -f $mapd_cfg_path set lan_interface eth0
				wificonf -f $p1905_cfg_path set map_root 1
				wificonf -f $p1905_cfg_path set lan eth0
				controller_setup
			;;
			2)
				# agent
				wificonf -f $mapd_cfg_path set DeviceRole 2
				wificonf -f $mapd_cfg_path set lan_interface eth0
				wificonf -f $p1905_cfg_path set lan eth0
			;;
			*)
				log_info "easymesh" "Unknown device role!"
				return 1
		esac

		wificonf -f $mapd_cfg_path set MapEnable 1

		iwpriv ra0 set mapEnable=1
		iwpriv rai0 set mapEnable=1

	elif [ "$Enable" = "0" ]; then
		log_info "easymesh" "write disable config"

		wificonf -f $mapd_cfg_path set MapEnable 0

		iwpriv ra0 set mapEnable=0
		iwpriv rai0 set mapEnable=0
	fi

	al_mac=$(cat /sys/class/net/br-lan/address)

	wificonf -f $p1905_cfg_path set map_controller_alid $al_mac
	wificonf -f $p1905_cfg_path set map_agent_alid $al_mac

	log_info "easymesh" "write basic config down"
}


get_operating_mode()
{
	card0_profile_path=`cat /etc/wireless/l1profile.dat | grep INDEX0_profile_path |awk -F "[=;]" '{ print $2 }'`
	MapMode=`cat ${card0_profile_path} | grep MapMode | awk -F "=" '{ print $2 }'`

}
#Function reads interface name from the l1profile
prepare_ifname_card()
{
	echo "$card_idx"
	card_ext_ifname=`cat /etc/wireless/l1profile.dat | grep INDEX${card_idx}_ext_ifname |awk -F "=" '{ print $2 }'`
	echo $card_ext_ifname
	card_profile_path=`cat /etc/wireless/l1profile.dat | grep INDEX${card_idx}_profile_path |awk -F "=" '{ print $2 }'`
	echo $card_profile_path
	card_apcli_ifname=`cat /etc/wireless/l1profile.dat | grep INDEX${card_idx}_apcli_ifname |awk -F "=" '{ print $2 }'`
	echo $card_apcli_ifname
	card_main_ifname=`cat /etc/wireless/l1profile.dat | grep INDEX${card_idx}_main_ifname |awk -F "=" '{ print $2 }'`
	card_bssid_num=`cat ${card_profile_path} | grep BssidNum | awk -F "=" '{ print $2 }'`
	echo $card_bssid_num
	iwconfig ${card_main_ifname} | grep "Access Point"
	card_exist=$?
	echo $card_exist
	if [ $card_exist == 0 ]
	then
		active_cards=`expr $active_cards + 1`
		bssid_num=0
		while [ $bssid_num -lt $card_bssid_num ]
		do
			if [ -z ${if_list} ]
			then
			if_list="${card_ext_ifname}${bssid_num}"
			else
			if_list="${if_list};${card_ext_ifname}${bssid_num}"
			fi
			bssid_num=`expr $bssid_num + 1`
		done
		if_list="${if_list};${card_apcli_ifname}0"
		echo ${card_main_ifname} >> main_ifname
		echo ${card_apcli_ifname}"0" >> apcli_ifname
	fi
	echo $if_list
}
prepare_ifame_band()
{
	card_ext_ifname=`cat /etc/wireless/l1profile.dat | grep INDEX${card_idx}_ext_ifname |awk -F "[=;]" '{ print $2 }'`
	echo $card_ext_ifname
	card_profile_path=`cat /etc/wireless/l1profile.dat | grep INDEX${card_idx}_profile_path |awk -F "[=;]" '{ print $2 }'`
	echo $card_profile_path
	card_apcli_ifname=`cat /etc/wireless/l1profile.dat | grep INDEX${card_idx}_apcli_ifname |awk -F "[=;]" '{ print $2 }'`
	echo $card_apcli_ifname
	card_main_ifname=`cat /etc/wireless/l1profile.dat | grep INDEX${card_idx}_main_ifname |awk -F "[=;]" '{ print $2 }'`
	card_bssid_num=`cat ${card_profile_path} | grep BssidNum | awk -F "=" '{ print $2 }'`
	echo $card_bssid_num
	iwconfig ${card_main_ifname} | grep "Access Point"
	card_exist=$?
	echo $card_exist
	if [ $card_exist == 0 ]
	then
		active_cards=`expr $active_cards + 1`
		bssid_num=0
		while [ $bssid_num -lt $card_bssid_num ]
		do
			if [ -z ${if_list} ]
			then
			if_list="${card_ext_ifname}${bssid_num}"
			else
			if_list="${if_list};${card_ext_ifname}${bssid_num}"
			fi
			bssid_num=`expr $bssid_num + 1`
		done
		if_list="${if_list};${card_apcli_ifname}0"
		echo ${card_main_ifname} >> main_ifname
		echo ${card_apcli_ifname}"0" >> apcli_ifname
	fi
	echo $if_list
	card_ext_ifname=`cat /etc/wireless/l1profile.dat | grep INDEX${card_idx}_ext_ifname |awk -F "[=;]" '{ print $3 }'`
	echo $card_ext_ifname
	card_profile_path=`cat /etc/wireless/l1profile.dat | grep INDEX${card_idx}_profile_path |awk -F "[=;]" '{ print $3 }'`
	echo $card_profile_path
	card_apcli_ifname=`cat /etc/wireless/l1profile.dat | grep INDEX${card_idx}_apcli_ifname |awk -F "[=;]" '{ print $3 }'`
	echo $card_apcli_ifname
	card_main_ifname=`cat /etc/wireless/l1profile.dat | grep INDEX${card_idx}_main_ifname |awk -F "[=;]" '{ print $3 }'`
	card_bssid_num=`cat ${card_profile_path} | grep BssidNum | awk -F "=" '{ print $2 }'`
	echo $card_bssid_num
	iwconfig ${card_main_ifname} | grep "Access Point"
	card_exist=$?
	echo $card_exist
	if [ $card_exist == 0 ]
	then
		active_cards=`expr $active_cards + 1`
		bssid_num=0
		while [ $bssid_num -lt $card_bssid_num ]
		do
			if [ -z ${if_list} ]
			then
			if_list="${card_ext_ifname}${bssid_num}"
			else
			if_list="${if_list};${card_ext_ifname}${bssid_num}"
			fi
			bssid_num=`expr $bssid_num + 1`
		done
		if_list="${if_list};${card_apcli_ifname}0"
		echo ${card_main_ifname} >> main_ifname
		echo ${card_apcli_ifname}"0" >> apcli_ifname
	fi
	echo $if_list
}
prepare_ifname()
{
	card_idx=0
	active_cards=0
	rm -rf apcli_ifname main_ifname
	while [ $card_idx -le 2 ]
	do
		card=`cat /etc/wireless/l1profile.dat | grep INDEX${card_idx}= | awk -F "=" '{ print $2 }'`
		echo "$card"
		if [ -z "$card" ]
		then
			echo "No card"
		else
		if [ "$card" = "MT7615D" -o "$card" = "MT7915" -o "$card" = "MT7629" ]
		then
			echo "7615D detected"
			prepare_ifame_band
		else
			prepare_ifname_card
		fi
		fi
		card_idx=`expr $card_idx + 1`
	done
}

#call routine for SDK specfic config preparation(ra_band/ bh_priority etc)
prepare_platform_variables()
{
	#prepare_ifname
	radio_band="24G;5G;5G"
	lan_iface=`uci get network.lan.ifname`
	wan_iface=`uci get network.wan.ifname`
#derive almac from br mac
	br0_mac=$(cat /sys/class/net/br-lan/address)
	ctrlr_al_mac=$br0_mac
	agent_al_mac=$br0_mac
}

#call routine to prepare wapp configuration files
#call routine to prepare 1905 config file
prepare_1905_config()
{
		DeviceRole=`cat /etc/map/mapd_cfg | grep DeviceRole | awk -F "=" '{ print $2 }'`
		lan_iface=`uci get network.lan.ifname`
		wan_iface=`uci get network.wan.ifname`
		bridge_name="br-lan"
		brctl addif $bridge_name $lan_iface
		sed -i "s/radio_band=.*/radio_band=${radio_band}/g" /etc/map/1905d.cfg
		sed -i "s/map_controller_alid=.*/map_controller_alid=${ctrlr_al_mac}/g" /etc/map/1905d.cfg
		sed -i "s/map_agent_alid=.*/map_agent_alid=${agent_al_mac}/g" /etc/map/1905d.cfg
		# sed -i "s/bss_config_priority=.*/bss_config_priority=${if_list}/g" /etc/map/1905d.cfg
		if [ $DeviceRole = "1" ]
		then
			sed -i "s/map_agent=.*/map_agent=0/g" /etc/map/1905d.cfg
			sed -i "s/map_root=.*/map_root=1/g" /etc/map/1905d.cfg
		else
			sed -i "s/map_agent=.*/map_agent=1/g" /etc/map/1905d.cfg
			sed -i "s/map_root=.*/map_root=0/g" /etc/map/1905d.cfg
		fi

		####delete all lan= wan=
		sed -i '/lan=/d' /etc/map/1905d.cfg
		sed -i '/wan=/d' /etc/map/1905d.cfg
		lastlinestr='$a '
		lanstr='lan='
		wanstr='wan='
		lan_insert_str=$lastlinestr$lanstr$lan_iface
		`sed -i "$lan_insert_str" /etc/map/1905d.cfg`
		#######mode
		if [ $DeviceRole = "2" -a $Enable = "1" ]; then
			echo "prepare_1905_config bridge mode"
			log_info "easymesh" "bridge wan $wan_iface into $bridge_name"
			wan_insert_str=$lastlinestr$wanstr$wan_iface
			`sed -i "$wan_insert_str" /etc/map/1905d.cfg`
			brctl addif $bridge_name $wan_iface
		fi
}

prepare_logging_config()
{
echo "
/tmp/log/log.mapd {
	size 64K
	copytruncate
	rotate 2
}
" > /etc/logrotate.d/mapd.log.conf
}

#call routines for mapd_cfg.txt preparation
prepare_mapd_config()
{
	need_loop=1
	line_count=1
	sed -i "s/lan_interface=.*/lan_interface=${lan_iface}/g" /etc/map/mapd_cfg
	sed -i "s/wan_interface=.*/wan_interface=${wan_iface}/g" /etc/map/mapd_cfg
	while [ $need_loop == "1" ]
	do
		line=`sed -n "$line_count"p /etc/map/mapd_user.cfg`
		echo "$line"
		if [ -z "$line" ]
		then
			need_loop=0
		else
			key=`echo ${line} | awk -F "=" '{ print $1 }'`
			value=`echo ${line} | awk -F "=" '{ print $2 }'`
			# can't do it together or will be broken
			value=$(echo "$value" | sed -r 's/(\/|\.|\^|\$|\*|\\|\+|\?|\(|\)|\[|\{|\||\-|\]|\&)/\\\1/g')
			echo "Key = ${key}, value = ${value}"
			sed -i "s/${key}=.*/${key}=${value}/g" /etc/map/mapd_cfg
		fi
		line_count=`expr $line_count + 1`
	done
}


Cert_switch_config()
{
	# GMAC1 need To config swith vlan
	# platform mt7621(only for certification mode use)
	# support openwrt
	if [ -f /etc/kernel.config ]; then
	  echo "easymesh in openwrt version"
	  . /etc/kernel.config
	  if [ "$CONFIG_RALINK_MT7621" = "y" -o\
	  "$CONFIG_MT7621_ASIC" = "y" ]; then
		echo "easymesh board name is 7621"
		if [ "${MapMode}" = "4" ]; then
		echo "mapmode is certification mode, config switch_setup "
		  . /lib/network/switch.sh
		  setup_switch
		fi
	  fi
	fi

}

cert_switch_changes()
{
	card_gsw_setting=`cat /proc/device-tree/gsw@0/compatible`
	echo $card_gsw_setting
	if [ "$card_gsw_setting" = "mediatek,mt753x" ] ;then
		echo "found green card with MT7631 switch"
		switch reg w 34 8160816
		switch reg w 4 60
		switch reg w 10 ffffffff
	fi
	#card_gsw_setting=`cat /proc/device-tree/rtkgswsys@1b100000/compatible`
	#echo $card_gsw_setting
	#if [ "$card_gsw_setting" = "mediatek,rtk-gsw" ] ;then
	#	echo "found red card with switch RTL8367S"
	#fi
}

disconnect_all_sta()
{
	need_loop=1
	loop_count=1
	while [ $loop_count -le $active_cards ]
	do
		if_name=`sed -n "${loop_count}"p ./main_ifname`
		`iwpriv ${if_name} set DisConnectAllSta=`
		loop_count=`expr $loop_count + 1`
	done
}

ApCliIntfUp()
{
	need_loop=1
	loop_count=1
	while [ $loop_count -le $active_cards ]
	do
		if_name=`sed -n "${loop_count}"p ./apcli_ifname`
		`ifconfig | grep "br" > br_name`
		bridge_name=`cat br_name | awk '{ print $1}'`
		`ifconfig ${if_name} up`
		`brctl addif ${bridge_name} ${if_name}`
		`iwpriv ${if_name} set ApCliEnable=0`
		loop_count=`expr $loop_count + 1`
	done
	if [ $DeviceRole = "2" -a $Enable = "1" ]; then
		ifconfig $wan_iface up
	fi
	sleep 2
}

SwitchSetting()
{
	log_info "easymesh" "set switch setting for wan onboarding"
	#Rule 1:  P5 1905 multicast forwarding to WAN port(P4)
	#step 1: enable port 5 ACL function
	switch reg w 2504 ff0403

	#step 2:ACL pattern
	# pattern 16bit
	switch reg w 94 ffff0180
	#check MAC header OFST_TP=000   offset=0  check p5 frame
	switch reg w 98 82000
	#function:0101 ACL rule  rule0
	switch reg w 90 80005004

	switch reg w 94 ffffc200
	#check MAC header OFST_TP=000   offset=2  check p5 frame
	switch reg w 98 82002
	#function:0101 ACL rule1
	switch reg w 90 80005005

	switch reg w 94 ffff0013
	#check MAC header offset=4  check p5 frame
	switch reg w 98 82004
	#function:0101 ACL rule2
	switch reg w 90 80005006

	switch reg w 94 ffff893A
	switch reg w 98 8200c
	switch reg w 90 80005007

	#step3: ACL mask entry
	switch reg w 94 0xf0
	switch reg w 98 0
	#FUNC= 0x0101
	switch reg w 90 80009001

	#step4: ACL rule control :force forward to P4 or P1
	#PORT_EN = 1 forward to P4; if forward to P1, 18000284
	switch reg w 94 18001084
	switch reg w 98 0
	#func=1011   ACL rule control
	switch reg w 90 8000B001

	#Rule 2:  P0/P4 1905 multicast forwarding to P5 port
	#step 1:  enable port 4 function, if you want to enable port 0. Switch reg w 2004 ff403
	switch reg w 2404 ff0403

	#step 2:ACL pattern
	#pattern 16bit
	switch reg w 94 ffff0180
	#check MAC header OFST_TP=000   offset=0  check p4 frame, if P0, 80100
	switch reg w 98 81000
	#function:0101 ACL rule  rule0
	switch reg w 90 80005000

	switch reg w 94 ffffc200
	#check MAC header OFST_TP=000   offset=2  check p4 frame, if P0, 80102
	switch reg w 98 81002
	#function:0101 ACL rule1
	switch reg w 90 80005001

	switch reg w 94 ffff0013
	#check MAC header offset=4  check p4 frame, if P0, 80104
	switch reg w 98 81004
	#function:0101 ACL rule2
	switch reg w 90 80005002

	#step 3: ACL mask entry
	switch reg w 94 7
	switch reg w 98 0
	#FUNC= 0x0101
	switch reg w 90 80009000

	#step 4: ACL rule control :force forward to P5
	#PORT_EN = 1 dp=5
	switch reg w 94 18002084
	switch reg w 98 0
	#func=1011   ACL rule control
	switch reg w 90 8000B000
}


ModifySwitchReg()
{
	# To make switch related MC register setting for eth on platform mt7621
	# support lsdk
	if [ -f /sbin/config.sh ]; then
	  echo "easymesh in lsdk ver"
	  . /sbin/config.sh
	fi

	# support openwrt
	if [ -f /etc/kernel.config ]; then
	  echo "easymesh in openwrt ver"
	  . /etc/kernel.config
	fi

	if [ "$platform" == "MT7621" -o "$platform" == "MT7622" ]; then
	  echo "easymesh board name is 7621"
	  switch reg w 10 ffffffe0
	  switch reg w 34 8160816
	fi
}

DHCP_INIT()
{
	DeviceRole=`cat /etc/map/mapd_cfg|\
		grep DeviceRole|awk -F "=" '{print $2}'`
	echo "DeviceRole: $DeviceRole (0: Auto 1:Controller 2:Agent)"
	DHCP_CTRL=`cat /etc/map/mapd_cfg|\
		grep DhcpCtl| awk -F "=" '{print $2}'`
	ThrdPrtCon=`cat /etc/map/mapd_cfg|grep ThirdPartyConnection\
		|awk -F "=" '{print $2}'`
	echo "DHCP Server setting: $DeviceRole $DHCP_CTRL $ThrdPrtCon"
	if [ $DHCP_CTRL = "1" ];then
		if [ $ThrdPrtCon == "1" ];then
		echo "Role($DeviceRole ) ThrdPrtCon($ThrdPrtCon):\
		Disable DHCP Server!"
			uci set dhcp.lan.ignore=1
			uci commit
			/etc/init.d/dnsmasq reload
		fi
		BRIF=`cat /etc/map/1905d.cfg | grep "br_inf" | awk -F "=" '{print $2}'`
		nowip=`ifconfig "$BRIF" | grep "inet addr"`
		[ -z "$nowip" ] && {
			setip=`uci get network.lan.ipaddr`
			ifconfig "$BRIF" "$setip"
		}
	fi
	sleep 1
}

StartStandAloneBS()
{
	sleep 3
	echo "WAPP starting..."
	wapp_openwrt.sh > /dev/null
	sleep 3
	echo "BS2.0 Daemon starting..."
	bs20 &
	sleep 3
	disconnect_all_sta
	echo "Stand Alone BS2.0 is ready"
}

StartMapTurnkey()
{
	DeviceRole=`cat /etc/map/mapd_cfg|\
	grep DeviceRole|awk -F "=" '{ print $2 }'`
	echo $DeviceRole
	if [ $DeviceRole = "2" ]
	then
		SwitchSetting
	fi
	ulimit -c unlimited
	#Controller
	echo "dhcp starting..."
	DHCP_INIT
	echo "WAPP starting..."
	wapp_openwrt.sh > /dev/console
	echo "1905 starting..."
	if [ $DeviceRole = "1" ]
	then
		p1905_managerd -r0 -f "/etc/map/1905d.cfg" -F "/etc/map/wts_bss_info_config" > /dev/console&
	else
		p1905_managerd -r1 -f "/etc/map/1905d.cfg" -F "/etc/map/wts_bss_info_config" > /dev/console&
	fi
	echo "MAP Daemon starting..."
	mapd -I "/etc/map/mapd_cfg" -O "/etc/mapd_strng.conf" > /dev/console&
	ModifySwitchReg
	sleep 3
	/usr/bin/check_internet
}

ramips_board_name() {
	local name

	[ -f /tmp/sysinfo/board_name ] && name=$(cat /tmp/sysinfo/board_name)
	[ -z "$name" ] && name="unknown"

	echo "${name%-[0-9]*M}"
}

EasyMesh_openwrt() {
	board=$(ramips_board_name)
	platform=${board:0:6}
	echo "##################################$platform"

	prepare_ifname
	get_operating_mode
	prepare_platform_variables
	prepare_1905_config
	prepare_mapd_config

	echo "remove mtfwd module"
	#Enable QuickChChange feature.

	ulimit -c unlimited

	if [ "${MapMode}" = "0" ];
		then
		echo "Non MAP mode"
		need_loop=1
		loop_count=1
		while [ $loop_count -le $active_cards ]
		do
			if_name=`sed -n "${loop_count}"p ./main_ifname`
			iwpriv ${if_name} set mapEnable=0
			loop_count=`expr $loop_count + 1`
		done
		#wapp_openwrt.sh
		modprobe mtfwd
		sleep 1
	elif [ ${MapMode} = "2" ];
		then
		rmmod mapfilter
		echo "BS2.0 mode"
		while [ $loop_count -le $active_cards ]
		do
			if_name=`sed -n "${loop_count}"p ./main_ifname`
			iwpriv ${if_name} set mapEnable=2
			loop_count=`expr $loop_count + 1`
		done
		sleep 1
		StartStandAloneBS
		modprobe mtfwd
		sleep 1
	elif [ ${MapMode} = "4" ];
		then
		echo ">>>====================================================<<<" > /dev/console
		echo ">>>|| MAP certification mode!!! manually run script: ||<<<" > /dev/console
		echo ">>>||         /usr/bin/EasyMesh_openwrt.sh           ||<<<" > /dev/console
		echo ">>>====================================================<<<" > /dev/console
		#sleep 1
		#rmmod mtfwd
		#echo "Certification"
		#Cert_switch_config
		#cert_switch_changes
		#mkdir /libmapd
		#cp /usr/lib/libmapd_interface_client.so /libmapd/
		#modprobe mapfilter
		#ApCliIntfUp
		#map_config_agent.lua start
		#echo 458752 > /proc/sys/net/core/rmem_max
	else
		if [ "${MapMode}" = "1" ];
		then
			echo "TurnKeyMode"
			sleep 1
			rmmod mtfwd
			mkdir /libmapd
			cp /usr/lib/libmapd_interface_client.so /libmapd/
			modprobe mapfilter
			ApCliIntfUp
			need_loop=1
			loop_count=1
			while [ $loop_count -le $active_cards ]
			do
				if_name=`sed -n "${loop_count}"p ./main_ifname`
				iwpriv ${if_name} set mapEnable=1
				loop_count=`expr $loop_count + 1`
			done
			sleep 1
			StartMapTurnkey
		fi
	fi
}

start_easymesh() {
	log_info "easymesh" "starting"

	EasyMesh_openwrt

	mapd_iface /tmp/mapd_ctrl > /dev/console &

	log_info "easymesh" "start down"
}

stop_easymesh() {
	log_info "easymesh" "stopping"

	EasyMesh_openwrt

	# prevent parsing wrong topology
	rm /tmp/dump.txt
	rm /tmp/mesh.txt

	log_info "easymesh" "stop down"
}

send_renew_msg() {
	if [ "$Enable" = "1" -a  "$DevRole" = "1" ]; then
		mapd_cli /tmp/mapd_ctrl renew
		log_info "easymesh" "renew down"
	fi
}

user_channel() {
	if [ "$Enable" != "1" -o  "$DevRole" != "1" ]; then
		return
	fi

	local channel5g channel2g

	channel5g="$(gnvram get WlanBasicT1_channel)"
	channel2g="$(gnvram get WlanBasicT0_channel)"

	if [ "$channel5g" != "0" ]; then
		wificonf -f /etc/map/mapd_cfg set ChPlanningUserPreferredChannel5G ${channel5g}
		wificonf -f /etc/map/mapd_cfg set ChPlanningUserPreferredChannel5GH ${channel5g}
		mapd_cli /tmp/mapd_ctrl set user_preferred_channel ${channel5g}
		log_info "easymesh" "change user channel ${channel5g} down"
	else
		wificonf -f /etc/map/mapd_cfg set ChPlanningUserPreferredChannel5G ""
		wificonf -f /etc/map/mapd_cfg set ChPlanningUserPreferredChannel5GH ""
		log_info "easymesh" "clear 5G user channel down"
	fi

	if [ "$channel2g" != "0" ]; then
		wificonf -f /etc/map/mapd_cfg set ChPlanningUserPreferredChannel2G ${channel2g}
		mapd_cli /tmp/mapd_ctrl set user_preferred_channel ${channel2g}
		log_info "easymesh" "change user channel ${channel2g} down"
	else
		wificonf -f /etc/map/mapd_cfg set ChPlanningUserPreferredChannel2G ""
		log_info "easymesh" "clear 2G user channel down"
	fi

}

back_up() {
	if [ ! -f "/tmp/gdata/mapd_user.cfg" ] ||
		[ "$(cmp -s /tmp/gdata/mapd_user.cfg /etc/map/mapd_user.cfg; echo $?)" = "1" ]; then

		log_info "easymesh" "backup map user config"
		cp /etc/map/mapd_user.cfg /tmp/gdata/mapd_user.cfg
	fi
}

check_manufacture_mode() {
	MFG_MODE=$(gcontrol uenv get ManufactureMode | awk -F "=" '{print $2}')

	if [ $MFG_MODE = "3" ]; then
		echo "============== certification easymesh config ===============" > /dev/console
		bss_config_priority="ra0;ra1;rai0;rai1;apcli0;apclii0"
		wificonf -f /etc/map/1905d.cfg set lan eth0
		wificonf -f /etc/map/1905d.cfg set bss_config_priority $bss_config_priority
		wificonf -f /etc/map/mapd_default.cfg set bss_config_priority $bss_config_priority
		wificonf -f /etc/map/mapd_default.cfg set MapEnable 1
		wificonf -f /etc/map/mapd_default.cfg set lan_interface eth0
		wificonf -f /etc/map/mapd_default.cfg set wan_interface eth1
		wificonf -f /etc/map/mapd_default.cfg set BandSwitchTime 0
		wificonf -f /etc/map/mapd_default.cfg set AutoBHSwitching 0
		wificonf -f /etc/map/mapd_default.cfg set ChPlanningEnable 0
		wificonf -f /etc/map/mapd_default.cfg set NetworkOptimizationEnabled 0
		wificonf -f /etc/map/mapd_default.cfg set DhcpCtl 0
		wificonf -f /etc/map/1905d.cfg set config_agent_port 9000
		wificonf -f /etc/map/1905d.cfg set map_ver R1
		wificonf -f /etc/map/1905d.cfg set bh_type eth
		wificonf -f /etc/wapp_ap_wlan0.conf set gas_cb_delay 0
		wificonf -f /etc/wapp_ap_ra0.conf set gas_cb_delay 0
		wificonf -f /etc/wapp_ap_rai0.conf set gas_cb_delay 0
		wificonf -f /etc/wapp_ap_rax0.conf set gas_cb_delay 0
		wificonf -f /etc/wapp_ap_wlan0_default.conf set gas_cb_delay 0
		wificonf -f /etc/wapp_ap_ra0_default.conf set gas_cb_delay 0
		wificonf -f /etc/wapp_ap_rai0_default.conf set gas_cb_delay 0
		wificonf -f /etc/wapp_ap_rax0_default.conf set gas_cb_delay 0

		sed -i '/MAP_Turnkey/d' /etc/map/mapd_cfg
		sed -i '/MAP_Turnkey/d' /etc/map/mapd_default.cfg

		if [ $DevRole = "1" ]; then
			wificonf -f /etc/map/mapd_user.cfg set DeviceRole 1
		elif [ $DevRole = "2" ]; then
			wificonf -f /etc/map/mapd_user.cfg set DeviceRole 2
		fi
	fi
}

switch_reg() {
	MFG_MODE=$(gcontrol uenv get ManufactureMode | awk -F "=" '{print $2}')

	if [ "$Enable" = "1" -a "$DevRole" = "2" ]; then
		SwitchSetting
	fi
}

action=$1
log_info "easymesh" "get command: $action"
case $action in
	update_config)
		easymesh_setup_param
		write_basic_config
		check_manufacture_mode
	;;
	update_bss_config)
		easymesh_setup_param
		write_bss_config
	;;
	renew)
		easymesh_setup_param

		/bin/wireless.sh update_config

		write_bss_config
		user_channel

		send_renew_msg
	;;
	reload)
		easymesh_setup_param
		kill_daemon
		if [ "$Enable" = "1" ]; then

			if [ "$(cmp -s /tmp/gdata/mapd_user.cfg /etc/map/mapd_user.cfg; echo $?)" = "1" ]; then
				# if backup exist and different, get backup config
				log_info "easymesh" "restore backup map user config"
				cp /tmp/gdata/mapd_user.cfg /etc/map/mapd_user.cfg
			fi

			write_bss_config
			start_easymesh
			log_info "easymesh" "enable"
		else
			stop_easymesh
			log_info "easymesh" "disable down"
		fi
		/usr/bin/freemem.sh setup
	;;
	start)
		easymesh_setup_param
		kill_daemon
		write_basic_config
		start_easymesh
		log_info "easymesh" "start"
	;;
	stop)
		kill_daemon
		log_info "easymesh" "stop"
	;;
	back_up)
		back_up
	;;
	switch_reg)
		easymesh_setup_param
		switch_reg
	;;
	*)
		usage
	;;
esac

rm $RUNNING
