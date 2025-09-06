#!/bin/sh

WPSFAIL="/tmp/wps_fail"
MESHDOWN="/tmp/meshdown"
RUNNING="/tmp/wps_action.sh-running"
# make sure only one script is running
# only can trigger either one WPS
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

trap clean_up SIGHUP SIGINT SIGTERM

clean_up() {
	log_info "easymesh/wps" "interrupt wps process"

	/usr/bin/ledstatus.sh wps_finish
	rm -f $RUNNING
	exit 1
}

usage() {
	echo "[ wps_default | wps_agent | wps_controller ]" > /dev/console
}

easymesh_setup_param() {
	json_load "$(objReq easyMeshBasic json)"
	json_select EasyMeshBasicP
	json_get_var DevRole deviceRole
	json_select ".."

	BHConfigured=$(mapd_cli /tmp/mapd_ctrl conn_status | grep conn_status | cut -d " " -f 5)
}

enable_dhcp_server(){
	log_info "easymesh/wps" "enable dhcp server"
	uci set dhcp.lan.ignore=""
	echo "" > /tmp/dhcp.leases
	uci commit dhcp
	rcConf restart dhcps
}

wps_status_monitor()
{
	log_info "easymesh/wps" "wps status monitoring..."

	now=0
	# leave time for agent to config itself & avoid wps not on time
	wps_time=160

	expire="$(date +%s)"
	expire="$(expr $expire + $wps_time)"

	while [ true ] ; do

		if [ "$BHConfigured" = "2" ]; then
			# controller and configured agent use fronthaul status
			wps_code="$(mapd_cli /tmp/mapd_ctrl conn_status | grep conn_status | cut -d " " -f 3 | cut -c 1)"
		else
			# unconfigured agent use backhaul status
			wps_code="$(mapd_cli /tmp/mapd_ctrl conn_status | grep conn_status | cut -d " " -f 5)"
		fi

		if [ "$BHConfigured" = "2" -a "$wps_code" = "4" ] || [ "$BHConfigured" != "2" -a "$wps_code" = "2" ]; then
			log_info "easymesh/wps" "connected"
			/usr/bin/ledstatus.sh wps_finish
			return 0
		fi

		if [ "$BHConfigured" = "2" -a "$wps_code" = "3" ] || [ "$BHConfigured" != "2" -a "$wps_code" = "5" ]; then
			log_info "easymesh/wps" "wps fail"
			/usr/bin/ledstatus.sh wps_fail

			if [ "$DevRole" = "2" -a "$BHConfigured" != "2" ]; then
				enable_dhcp_server
			fi

			if [ "$DevRole" = "1"  ]; then
				sleep 60 && /usr/bin/ledstatus.sh wps_finish &
			else
				echo 1 > $WPSFAIL
				sleep 60 && rm $WPSFAIL &

				if [ "$BHConfigured" = "2" ]; then
					# not lock configured agent led
					rm $MESHDOWN
				fi
			fi

			break
		fi

		now=0
		sleep 1

		now="$(date +%s)"
		if [ $now -gt $expire ] ; then
			/usr/bin/ledstatus.sh wps_fail

			if [ "$DevRole" = "2" -a "$BHConfigured" != "2" ]; then
				enable_dhcp_server
			fi

			if [ "$DevRole" = "1" ]; then
				sleep 60 && /usr/bin/ledstatus.sh wps_finish &
			else
				echo 1 > $WPSFAIL
				sleep 60 && rm $WPSFAIL &

				if [ "$BHConfigured" = "2" ]; then
					# not lock configured agent led
					rm $MESHDOWN
				fi
			fi

			break
		fi

	done

	log_info "easymesh/wps" "wps monitor down"
}

set_agent_obj() {
	objReq wan setparam proto 5
	objReq bridge setparam mode 0
	#objReq bridge setparam ip "192.168.1.1"
	#objReq bridge setparam netmask "255.255.255.0"
	gnvram commit

	log_info "easymesh/wps" "set agent obj down"
}

set_default_obj() {
	objReq system setparam doneWizard 1
	gnvram commit

	log_info "easymesh/wps" "set default obj down"
}

set_easymesh_obj() {
	objReq easyMeshBasic setparam enable 1
	objReq easyMeshBasic setparam deviceRole 2
	gnvram commit

	log_info "easymesh/wps" "set basic obj down"
}

reset_easymesh() {
	log_info "easymesh/wps" "reset easymesh"

	echo "###!UserConfigs!!!" > /etc/map/mapd_user.cfg

	echo "LowRSSIAPSteerEdge_RE=40
CUOverloadTh_2G=70
CUOverloadTh_5G_L=80
CUOverloadTh_5G_H=80
APSteerRssiTh=-54
" > /etc/mapd_strng.conf

	/usr/bin/easymesh.sh reload

	log_info "easymesh/wps" "reset easymesh down"
}

agent_rcconf() {
	log_info "easymesh/wps" "agent rcConf"
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

	rcConf run

	log_info "easymesh/wps" "agent rcConf run"
}

trigger_wps() {
	if [ "$DevRole" = "2" ]; then
		# default & agent wps both need to close dhcp server
		log_info "easymesh/wps" "agent wps, disable dhcp server!!!!!!!!!!!!!!!!!!!!!!!!!!"
		uci set dhcp.lan.ignore="1"
		uci commit dhcp
		rcConf restart dhcps
		touch $MESHDOWN
	fi

	/usr/bin/ledstatus.sh easymesh_wps_start

	wappctrl ra0 wps_pbc

	log_info "easymesh/wps" "wps triggered"
}

wps_default() {
	log_info "easymesh/wps" "default wps, change to agent mode and trigger wps..."
	set_easymesh_obj
	set_default_obj
	set_agent_obj

	agent_rcconf

	sleep 40

	trigger_wps

	log_infog "easymesh/wps" "default wps down"
}

wps_agent() {
	log_info "easymesh/wps" "agent wps, default map and trigger wps..."

	if [ "$BHConfigured" != "2" ]; then
		log_info "easymesh/wps" "agent didn't successfully config, reset default"
		reset_easymesh
	fi

	trigger_wps

	log_info "easymesh/wps" "agent wps down"
}

wps_controller() {
	log_info "easymesh/wps" "controller wps, trigger wps..."

	trigger_wps

	log_info "easymesh/wps" "controller wps down"
}

action=$1
case $action in
	wps_default)
		easymesh_setup_param
		wps_default
		wps_status_monitor
	;;
	wps_agent)
		easymesh_setup_param
		wps_agent
		wps_status_monitor
	;;
	wps_controller)
		easymesh_setup_param
		wps_controller
		wps_status_monitor
	;;
	*)
		usage
	;;
esac

rm $RUNNING

