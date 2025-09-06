#!/bin/sh

debug_ps() {
	printf "#############################################ps###########################################\n"
	ps
	printf "\n"
}

debug_memory() {
	printf "#############################################memory###########################################\n"
	free
	printf "\n"
}

debug_dmesg() {
	printf "#############################################dmesg###########################################\n"
	dmesg
	printf "\n"
}

debug_interface() {
	printf "#############################################interface###########################################\n"
	ifconfig 
	printf "====================all====================\n"
	ifconfig -a
	printf "\n"
}

debug_route() {
	printf "#############################################route###########################################\n"
	route
	printf "\n"
}

debug_arp() {
	printf "#############################################arp###########################################\n"
	cat /proc/net/arp
	printf "\n"
}

debug_module() {
	printf "#############################################module###########################################\n"
	lsmod
	printf "\n"
}

debug_portstatus() {
	printf "#############################################port status###########################################\n"
	ethstt
	printf "\n"
}

debug_partiation() {
	printf "#############################################partiation###########################################\n"
	cat /proc/mtd
	printf "========================================\n"
	cat /proc/partitions
	printf "\n"
}

debug_system_obj() {
	printf "#############################################system obj##########################################\n"
	objReq wan show
	printf "========================================\n"
	objReq lan show
	printf "========================================\n"
	objReq system show
	printf "========================================\n"
	objReq route show
	printf "\n"
}

debug_system_uci() {
	printf "#############################################uci network##########################################\n"
	uci show network
	printf "========================================\n"
	uci show dhcp
	printf "========================================\n"
	uci show hwnat 
	printf "\n"
}

debug_upnp() {
	printf "#############################################upnp config##########################################\n"
	cat /var/etc/miniupnpd-ra0.conf
	printf "========================================\n"
	cat /var/etc/miniupnpd-rai0.conf
	printf "========================================\n"
	ps | grep miniupnp
	cat /var/run/miniupnpd.*
	printf "\n"
}

debug_igmpproxy() {
	printf "#############################################igmpproxy config##########################################\n"
	uci show igmpproxy
	cat /etc/config/igmpproxy
	printf "========================================\n"
	cat /var/etc/igmpproxy.conf
	printf "========================================\n"
	cat /proc/net/ip_mr_*
	printf "========================================\n"
	ps | grep igmp
	printf "\n"
}

debug_rip() {
	printf "#############################################rip config##########################################\n"
	cat /etc/quagga/ripd.conf
	printf "========================================\n"
	cat /etc/quagga/zebra.conf
	printf "========================================\n"
	ps | grep rip
	ps | grep zebra
	printf "\n"
}

debug_dhcp_lease() {
	printf "#############################################dhcp lease##########################################\n"
	cat /tmp/dhcp.leases
	printf "\n"
}

debug_resolv() {
	printf "#############################################resolv##########################################\n"
	cat /tmp/resolv.conf.auto
	printf "========================================\n"
	cat /tmp/resolv.conf
	printf "\n"
}

debug_gdata() {
	printf "#############################################config data##########################################\n"
	cat /tmp/gdata/conf.dat
	printf "\n"
}

debug_vlan() {
	printf "#############################################vlan##########################################\n"
	objReq vlan show
	printf "===================egress vlan=====================\n"
	cat /proc/net/vlan/*
	printf "===================switch=====================\n"
	cat /proc/mt7621/esw_cnt
	printf "\n"
}

debug_fw_status() {
	printf "#############################################check firmware##########################################\n"
	cat /etc/version
	cat /proc/version
	printf "===================checkfw=====================\n"
	[ -f "/tmp/checkfw" ] && { cat /tmp/checkfw ; }
	printf "===================fwstatus=====================\n"
	[ -f "/tmp/fwstatus" ] && { cat /tmp/fwstatus ; }
	printf "===================fwperc=====================\n"
	[ -f "/tmp/fwperc" ] && { cat /tmp/fwperc ; }
	printf "========================================\n"
	ls /tmp/*.img
	printf "\n"
}

debug_email_status() {
	printf "#############################################check email registor##########################################\n"
	objReq account show
	printf "========================================\n"
	[ -f "/tmp/emailReg" ] && { cat /tmp/emailReg ; }
	printf "========================================\n"
	[ -f "/tmp/emailRegRet" ] && { cat /tmp/emailRegRet ; }
	printf "\n"
}

debug_envdata() {
	printf "#############################################check email registor##########################################\n"
	gcontrol di show
	printf "========================================\n"
	gcontrol uenv show
	printf "\n"
}

usage() {
    cat <<EOF
Usage: $0 FEATURE

Features:
  run
  file
  uci
  config
  vlan
  server
  envdata
  igmp
  rip
  upnp

EOF
}


case "$1" in
    run)
        debug_ps
	debug_memory
	debug_dmesg
	debug_interface
	debug_route
	debug_arp
	debug_module
	debug_portstatus
	debug_partiation
        ;;
    dhcp)
        debug_dhcp_lease
	debug_resolv
	;;
    uci)
    	debug_system_obj
    	debug_system_uci
    	;;
    config)
        debug_gdata
	;;
    vlan)
        debug_vlan
	;;
    server)
        debug_fw_status
	debug_email_status
        ;;
    envdata)
        debug_envdata
	;;
    igmp)
        debug_igmpproxy
        ;;
    rip)
        debug_rip
        ;;
    upnp)
        debug_upnp
        ;;
    *)
        usage
        ;;
esac
