#!/bin/sh
RED='\033[0;31m'
NC='\033[0m'
echo -e "----- ${RED}EasyMesh SCRIPT${NC} -----"
check_default="$1"

mode="$1"
echo "param1 mode=$mode"
echo "param1  0--> router mode on dev"
echo "param1  1--> bridge mode on dev"

ramips_board_name() {
	local name

	[ -f /tmp/sysinfo/board_name ] && name=$(cat /tmp/sysinfo/board_name)
	[ -z "$name" ] && name="unknown"

	echo "${name%-[0-9]*M}"
}

board=$(ramips_board_name)
platform=${board:0:6}
echo "##################################$platform"

clean()
{
	rm -rf /tmp/wapp_ctrl
	killall -15 mapd
	killall -15 wapp
	killall -15 p1905_managerd
	killall -15 bs20
	sleep 5
	rmmod mapfilter
	echo -e "----- ${RED}killed all apps ${NC} -----"
}
#call routine to decide operating mode
get_operating_mode()
{
	card0_profile_path=`cat /etc/wireless/l1profile.dat | grep INDEX0_profile_path |awk -F "[=;]" '{ print $2 }'`
	#MapEnable=`cat ${card0_profile_path} | grep MapEnable | awk -F "=" '{ print $2 }'`
	#MapTurnKey=`cat ${card0_profile_path} | grep MAP_Turnkey | awk -F "=" '{ print $2 }'`
	#BSEnable=`cat ${card0_profile_path} | grep BSEnable | awk -F "=" '{ print $2 }'`
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
	if [ $active_cards == "2" ]
	then
		radio_band="24G;5G;5G"
	elif [ $active_cards == "3" ]
	then
		radio_band="24G;5GH;5GL"
	fi
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
		bridge_name=`cat br_name | awk '{ print $1}'`
		brctl addif $bridge_name $lan_iface
		sed -i "s/radio_band=.*/radio_band=${radio_band}/g" /etc/map/1905d.cfg
		sed -i "s/map_controller_alid=.*/map_controller_alid=${ctrlr_al_mac}/g" /etc/map/1905d.cfg
		sed -i "s/map_agent_alid=.*/map_agent_alid=${agent_al_mac}/g" /etc/map/1905d.cfg
		sed -i "s/bss_config_priority=.*/bss_config_priority=${if_list}/g" /etc/map/1905d.cfg
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
		if [ $mode = "1" ]; then
			echo "prepare_1905_config bridge mode"
			wan_insert_str=$lastlinestr$wanstr$wan_iface
			`sed -i "$wan_insert_str" /etc/map/1905d.cfg`
			brctl addif $bridge_name $wan_iface
		else
			brctl delif $bridge_name $wan_iface
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

#preapre config file for map steering parameters
prepare_mapd_strng_configs()
{
	if [ ! -f "/etc/mapd_strng.conf" -o "$check_default" = "default" ];then
		echo "Make mapd_strng.conf"
echo "LowRSSIAPSteerEdge_RE=40
CUOverloadTh_2G=70
CUOverloadTh_5G_L=80
CUOverloadTh_5G_H=80
" > /etc/mapd_strng.conf
	fi
}
#call routines for mapd_cfg.txt preparation
prepare_mapd_config()
{
	need_loop=1
	line_count=1
	cp /etc/map/mapd_default.cfg /etc/map/mapd_cfg
	if [ "$check_default" = "default" ];then
		need_loop=0
		cat "###!UserConfigs!!!" > /etc/map/mapd_user.cfg
	fi
	sed -i "s/lan_interface=.*/lan_interface=${lan_iface}/g" /etc/map/mapd_cfg
	sed -i "s/wan_interface=.*/wan_interface=${wan_iface}/g" /etc/map/mapd_cfg
	while [ $need_loop == "1" ]
	do
		line=`sed -n "$line_count"p /etc/map/mapd_user.cfg`
		echo $line
		if [ -z $line ]
		then
			need_loop=0
		else
			key=`echo ${line} | awk -F "=" '{ print $1 }'`
			value=`echo ${line} | awk -F "=" '{ print $2 }'`
			echo "Key = ${key}, value = ${value}"
			sed -i "s/${key}=.*/${key}=${value}/g" /etc/map/mapd_cfg
		fi 	
		line_count=`expr $line_count + 1`
	done
	enhanced_logging=`cat /etc/map/mapd_cfg | grep "EnhancedLogging" | awk -F "=" '{ print $2 }'`
	if [ $enhanced_logging = "1" ]
	then
		prepare_logging_config
	fi
	sed -i "s/bss_config_priority=.*/bss_config_priority=${if_list}/g" /etc/map/mapd_cfg
	prepare_mapd_strng_configs
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
	sleep 2
}


SwitchSetting()
{
	if [ "$platform" == "MT7621" -o "$platform" == "MT7622" ]; then
	  echo "easymesh board name is 7621"
	#Rule 1:  P5 1905 multicast forwarding to WAN port(P4)
	  #step 1: enable port 5 ACL function
	   switch  reg w 2504 ff0403

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
	  switch  reg w 2404 ff0403  

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
	fi
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
	  echo "ModifySwitchReg easymesh board name is 7621"
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
		else
		echo "Role($DeviceRole ) ThrdPrtCon($ThrdPrtCon):\
		Enable DHCP Server!"
			if [ -z "$(uci -q get network.lan.ipaddr)" ];then
				echo "no IP, reload network ip to 192.168.1.1"
				uci -q set network.lan.ipaddr=192.168.1.1;
				ifconfig ${bridge_name} 192.168.1.1 up
				uci set dhcp.lan.ignore=\"\"
				uci commit
				/etc/init.d/dnsmasq reload
				/etc/init.d/network reload
			 else
				br_ip=`uci -q get network.lan.ipaddr`
				echo "br_ip: $br_ip"
				ifconfig br-lan $br_ip up
				uci set dhcp.lan.ignore=\"\"
				uci commit
				/etc/init.d/dnsmasq reload
			fi
		fi
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
		if [ $mode = "1" ]
		then
	SwitchSetting
		fi
	fi
	ulimit -c unlimited
	#Controller

	echo "dhcp starting..."
	DHCP_INIT
	echo "WAPP starting..."
	wapp_openwrt.sh > /dev/null
	echo "1905 starting..."
	if [ $DeviceRole = "1" ]
	then
		p1905_managerd -r0 -f "/etc/map/1905d.cfg" -F "/etc/map/wts_bss_info_config" > /dev/console&
	else
		p1905_managerd -r1 -f "/etc//map/1905d.cfg" -F "/etc/map/wts_bss_info_config" > /dev/console&
	fi
	echo "MAP Daemon starting..."
	if [ $enhanced_logging = "1" ]
	then
		mapd -I "/etc/map/mapd_cfg" -O "/etc/mapd_strng.conf" > /tmp/log/log.mapd&
	else
		mapd -I "/etc/map/mapd_cfg" -O "/etc/mapd_strng.conf" > /dev/console&
	fi
	ModifySwitchReg
	sleep 3
	echo -e "----- ${RED}MAP DEVICE STARTED${NC} -----"
}

clean
prepare_ifname
get_operating_mode
prepare_platform_variables
prepare_1905_config
prepare_mapd_config


echo "kill fwdd daemon and remove mtfwd module"
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
	wapp_openwrt.sh
	modprobe mtfwd
	sleep 1
	fwdd -p ra0 apcli0 -p rai0 apclii0 -p rax0 apclix0 -p wlan0 wlan-apcli0 -e eth0 5G&
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
	fwdd -p ra0 apcli0 -p rai0 apclii0 -p rax0 apclix0 -p wlan0 wlan-apcli0 -e eth0 5G&
elif [ ${MapMode} = "4" ];
	then
	killall -15 fwdd
	sleep 1
	rmmod mtfwd
	echo "Certification"
	Cert_switch_config
	cert_switch_changes
	mkdir /libmapd
	cp /usr/lib/libmapd_interface_client.so /libmapd/
	modprobe mapfilter
	ApCliIntfUp
	map_config_agent.lua start
	echo 458752 > /proc/sys/net/core/rmem_max
else
	if [ "${MapMode}" = "1" ];
	then
		echo "TurnKeyMode"
		killall -15 fwdd
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





