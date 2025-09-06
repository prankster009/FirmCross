#!/bin/sh

RUNNING="/tmp/easymesh_main.sh-running"
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
	echo "[ wps | wps_status | start | stop | restart]"
}

easymesh_setup_param() {
	json_load "$(objReq easyMeshBasic json)"
	json_select EasyMeshBasicP
	json_get_var Enable enable
	json_get_var DevRole deviceRole
	json_select ".."
}

set_agent_obj() {
	objReq wan setparam proto 5
	objReq bridge setparam mode 0
	#objReq bridge setparam ip "192.168.1.1"
	#objReq bridge setparam netmask "255.255.255.0"
	gnvram commit

	log_info "easymesh/main" "set agent obj down"
}

set_controller_obj() {
	objReq wlanMacFilter setparam 0 enable 0

	objReq wlanGuest setparam 0 enable 0
	objReq wlanGuest setparam 1 enable 0

	objReq wlanBasic setparam 0 hiddenAP 0
	objReq wlanBasic setparam 1 hiddenAP 0

	gnvram commit

	log_info "esaymesh/main" "set controller obj done"
}

set_dhcp_obj() {
	objReq wan setparam proto 1
	objReq bridge setparam mode 0
	objReq bridge setparam ip ""
	objReq bridge setparam netmask ""
	gnvram commit

	log_info "easymesh/main" "set dhcp obj down"
}

agent_rcconf() {
	log_info "easymesh/main" "agent rcConf"
	#wan
	rcConf restart firewall
	rcConf restart wan
	rcConf restart hwnat
	rcConf restart upnpd
	rcConf restart ipv6
	rcConf restart routername
	#bridge, network
	rcConf restart lan
	#system
	rcConf restart sysconfig

	log_info "easymesh/main" "agent rcConf run"
}

controller_rcconf() {
	log_info "easymesh/main" "controller rcConf"
	#network
	rcConf restart lan

	log_info "easymesh/main" "controller rcConf run"
}

get_wps_status() {
	# echo wps status based on device role
	wps_status="wps_unknown"

	# get backhaul status
	bh_status="$(mapd_cli /tmp/mapd_ctrl conn_status | grep conn_status | cut -d " " -f 5)"

	if [ "$bh_status" = "2" ]; then
		# controller and configured agent use fronthaul status
		fh_status="$(mapd_cli /tmp/mapd_ctrl conn_status | grep conn_status | cut -d " " -f 3 | cut -c 1)"

		case $fh_status in
			1)
				wps_status="wps_triggered";;
			3)
				wps_status="wps_failed";;
			4)
				wps_status="wps_successful";;
		esac

	else
		# unconfigured agent use backhaul status

		case $bh_status in
			2)
				wps_status="wps_successful";;
			4)
				wps_status="wps_triggered";;
			5)
				wps_status="wps_failed";;
		esac

	fi

	echo $wps_status
}

start_service() {
	log_info "easymesh/main" "start service"
	# prevent user disabling easymesh and changing device role together
	mapd_role="$(wificonf -f /etc/map/mapd_cfg get DeviceRole)"

	if [ "$Enable" = "1" -a "$DevRole" = "1" ]; then
		log_info "easymesh/main" "set controller..."
		#if [ "$mapd_role" = "2" ]; then
		#	set_dhcp_obj
		#fi
		# write bss config when open easymesh or change role from agent to controller
		set_controller_obj
		/usr/bin/easymesh.sh update_bss_config
		controller_rcconf
	elif [ "$Enable" = "1" -a "$DevRole" = "2" ]; then
		log_info "easymesh/main" "set agent..."
		set_agent_obj
		agent_rcconf
	elif [ "$Enable" = "0" -a "$mapd_role" = "1" ]; then
		log_info "easymesh/main" "close controller..."
		controller_rcconf
	#elif [ "$Enable" = "0" -a "$mapd_role" = "2" ]; then
	#	log_info "easymesh/main" "close agent..."
	#	set_dhcp_obj
	#	agent_rcconf
	fi

	log_info "easymesh/main" "start service down"
}

stop_service() {
	log_info "easymesh/main" "stop service"
	/usr/bin/easymesh.sh stop
	log_info "easymesh/main" "stop service down"
}

wps() {
	log_info "easymesh/main" "start wps"

	local wizard_done
	json_load "$(objReq system json)"
	json_select SystemP
	json_get_var wizard_done doneWizard
	json_select ".."

	if [ "$Enable" = "0" -a "$wizard_done" = "1" ]; then
		log_info "easymesh/main" "mesh not enable, not trigger WPS"
		rm $RUNNING
		return 1
	fi

	/usr/bin/ledstatus.sh system_booting

	/usr/bin/meshtopo
	cp /tmp/mesh.txt /tmp/mesh_old

	if [ "$Enable" = "0" -a "$wizard_done" = "0" ]; then
		/usr/bin/easymesh_wps.sh wps_default &
	elif [ "$Enable" = "1" -a "$DevRole" = "1" ]; then
		/usr/bin/easymesh_wps.sh wps_controller &
	elif [ "$Enable" = "1" -a "$DevRole" = "2" ]; then
		/usr/bin/easymesh_wps.sh wps_agent &
	else
		log_info "easymesh/main" "Unknown wps type!!!!!!!!"
		rm $RUNNING
		return 1
	fi
	log_info "easymesh/main" "start wps down"
}

wps_cancel() {
	# only controller UI can cancel WPS, so stop ap wsc
	iwpriv ra0 set WscStop=1; iwpriv rai0 set WscStop=1

	# kill wps script also light the LED
	ps | grep easymesh_wps.sh | grep -v grep | awk '{print $1}' | xargs kill

	/usr/bin/easymesh.sh reload
}

renew() {
	/usr/bin/easymesh.sh renew
}

check_diff() {
	log_info "easymesh/main" "check obj and config difference"
	# if obj not change, don't restart service
	map_enable="$(wificonf -f /etc/map/mapd_cfg get MapEnable)"
	mapd_role="$(wificonf -f /etc/map/mapd_cfg get DeviceRole)"
	target=$1

	if [ "$map_enable" = "$Enable" -a "$mapd_role" = "$DevRole" ]; then
		if [ "$target" = "basic" ]; then
			log_info "easymesh/main" "no change role or enable, exit..."
			rm $RUNNING
			exit 0
		elif [ "$target" = "bss" ]; then
			log_info "easymesh/main" "no change role or enable, do renew..."
			renew
			rm $RUNNING
			exit 0
		fi
	fi

	log_info "easymesh/main" "check difference down"
}

action=$1
case $action in
	wps)
		log_info "easymesh/main" "get command: wps"
		easymesh_setup_param
		wps
	;;
	wps_status)
		log_info "easymesh/main" "get command: wps_status"
		easymesh_setup_param
		get_wps_status
	;;
	wps_cancel)
		log_info "easymesh/main" "get command: wps_cancel"
		wps_cancel
	;;
	renew)
		log_info "easymesh/main" "get command: renew"
		renew
	;;
	start)
		log_info "easymesh/main" "get command: start"
		easymesh_setup_param
		check_diff basic # bss
		start_service
		/usr/bin/freemem.sh setup
	;;
	stop)
		log_info "easymesh/main" "get command: stop"
		easymesh_setup_param
		check_diff basic
		stop_service
	;;
	restart)
		log_info "easymesh/main" "get command: restart"
		easymesh_setup_param
		stop_service
		start_service
	;;
	*)
		usage
	;;
esac

rm $RUNNING


