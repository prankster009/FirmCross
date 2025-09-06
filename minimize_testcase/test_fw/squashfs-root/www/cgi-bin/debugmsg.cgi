#!/bin/sh

FW_VERSION=`cat /etc/version`

LAN_MAC=`cat /sys/class/net/br-lan/address`
WAN_MAC=`cat /sys/class/net/eth1/address`
W2G_MAC=`cat /sys/class/net/ra0/address`
W5G_MAC=`cat /sys/class/net/rai0/address`

ESSID_2G=`iwconfig ra0 | grep ESSID | awk -F '"' '{print $2}'`
ESSID_2G_guest=`iwconfig ra1 | grep ESSID | awk -F '"' '{print $2}'`
ESSID_5G=`iwconfig rai0 | grep ESSID | awk -F '"' '{print $2}'`
WPSPIN=`objReq wlanWps show | grep routerPIN | cut -d ':' -f 2 | sed s/' '/''/g`
WIFI_PASSWORD=`objReq wlanSecurity show | grep wpaPsk | cut -d ':' -f 2 | head -n 1 | sed s/' '/''/g`
REGION=`objReq wlanMpt show | grep region | cut -d '=' -f 2 | sed s/' '/''/g`

SET_BASE_MAC=`gcontrol di get hw_mac_addr | cut -d '=' -f 2`
SET_SN=`gcontrol di get serial_number | cut -d '=' -f 2`
SET_MODULE_NAME=`gcontrol di get modelNumber | cut -d '=' -f 2`

SET_SSID=`gcontrol di get default_ssid | cut -d '=' -f 2`
SET_PASSWORD=`gcontrol di get default_passphrase | cut -d '=' -f 2`
SET_WPSPIN=`gcontrol di get wps_device_pin | cut -d '=' -f 2`
SET_REGION=`gcontrol di get cert_region | cut -d '=' -f 2`

EASYMESH_EN=`objReq easyMeshBasic show | grep "enable" | cut -d '=' -f 2 | sed s/' '/''/g`
VLAN_EN=`objReq vlanEnable show | grep "vlanEnable" | cut -d '=' -f 2 | sed s/' '/''/g`

echo "Content-type: text/html"
echo ""

echo '<!doctype html>'
echo '<html>'
echo '<head>'
echo '<meta charset="UTF-8" name="viewport" content="width=device-width; initial-scale=1.0; maximum-scale=1.0; user-scalable=0;">'
echo '<title>Sysinfo Dump</title>'
#echo '<link href="/css/fqc.css" rel="stylesheet" type="text/css">'
echo '</head>'
echo '<body class="marginBody">'
echo '<p></p>'
echo '<p class="Title">Sysinfo</p>'

echo "<p class='content'>Firmware Version: $FW_VERSION </p>"
echo "<p class='content'>Module Name: $SET_MODULE_NAME </p>"
echo "<p class='content'>Serial Number: $SET_SN </p>"

if [ $REGION == $SET_REGION ]; then
	REGIN_RET="(vaild Region)"
else
	REGIN_RET="(invalid Region, Region should be $SET_REGION)"
fi
echo "<p class='content'>Region: $REGION $REGIN_RET </p>"

echo "<p>========run info========</p>"
echo "<p>ps==============================</p>"
ps | sed 'a <br>'
echo "<p>memory==============================</p>"
free | sed 'a <br>'
echo "<p>dmesg==============================</p>"
dmesg | sed 'a <br>'
echo "<p>interface==============================</p>"
ifconfig | sed 'a <br>'
echo "<p>route==============================</p>"
route | sed 'a <br>'
echo "<p>arp==============================</p>"
cat /proc/net/arp | sed 'a <br>'
echo "<p>module==============================</p>"
lsmod | sed 'a <br>'
echo "<p>portstatus==============================</p>"
ethstt | sed 'a <br>'
#echo "<p>mtd==============================</p>"
#cat /proc/mtd | sed 'a <br>'
#echo "<p>partition==============================</p>"
#cat /proc/partitions | sed 'a <br>'
echo "<p>========dhcp========</p>"
echo "<p>dhcp_lease==============================</p>"
cat /tmp/dhcp.lease | sed 'a <br>'
echo "<p>resolv==============================</p>"
cat /tmp/resolv.conf.auto | sed 'a <br>'
cat /tmp/resolv.conf | sed 'a <br>'
echo "<p>========uci========</p>"
echo "<p>system_obj==============================</p>"
objReq wan show | sed 'a <br>'
objReq lan show | sed 'a <br>'
objReq system show | sed 'a <br>'
objReq route show | sed 'a <br>'
echo "<p>system_uci==============================</p>"
uci show network | sed 'a <br>'
uci show dhcp | sed 'a <br>'
uci show hwnat | sed 'a <br>'
echo "<p>========config========</p>"
#echo "<p>gdata==============================</p>"
#cat /tmp/gdata/conf/dat | sed 'a <br>'
echo "<p>vlan==============================</p>"
objReq vlanEnable show | sed 'a <br>'
if [ $VLAN_EN == "1" ]; then
	objReq vlan show | sed 'a <br>'
	#cat /proc/net/vlan/* | sed 'a <br>'
	#cat /proc/mt7621/esw_cnt | sed 's/[<>]/\ /g' | sed 'a <br>'
	# /proc/mt7621/esw_cnt has content like <<cpu>>, will be seen as html tags,
	# so replace '<>' to ' '(blank)
fi
echo "<p>========server========</p>"
echo "<p>fw_status==============================</p>"
cat /etc/vwesion | sed 'a <br>'
cat /etc/proc/version | sed 'a <br>'
[ -f "/tmp/checkfw" ] && { cat /tmp/checkfw ; } | sed 'a <br>'
[ -f "/tmp/fwstatus" ] && { cat /tmp/fwstatus ; } | sed 'a <br>'
[ -f "/tmp/fwperc" ] && { cat /tmp/fwperc ;  } | sed 'a <br>'
ls /tmp/*.img | sed 'a <br>'
#echo "<p>envdata==============================</p>"
#gcontrol di show | sed 'a <br>'
#gcontrol uenv show | sed 'a <br>'
#echo "<p>igmp==============================</p>"
#uci show igmpproxy | sed 'a <br>'
#cat /etc/config/igmpproxy | sed 'a <br>'
#cat /var/etc/igmpproxy.conf | sed 'a <br>'
#cat /proc/net/ip_mr_* | sed 'a <br>'
#ps | grep igmp | sed 'a <br>'
#echo "<p>rip==============================</p>"
#cat /etc/quagga/ripd.conf | sed 'a <br>'
#cat /etc/quagga/zebra.conf | sed 'a <br>'
#ps | grep rip | sed 'a <br>'
#ps | grep zebra | sed 'a <br>'
#echo "<p>upnp==============================</p>"
#cat /var/etc/miniupnpd-ra0.conf | sed 'a <br>'
#cat /var/etc/miniupnpd-rai0.conf | sed 'a <br>'
#ps | grep miniupnp | sed 'a <br>'
#cat /var/run/miniupnpd.* | sed 'a <br>'
echo "<p>========WIFI========</p>"
echo "<p>wifi config==============================</p>"
objReq wlanBasic show | sed 'a <br>'
echo "<p>wifi interface==============================</p>"
iwconfig | sed 'a <br>'
echo "<p>wifi stat==============================</p>"
iwpriv ra0 stat | sed 'a <br>'
iwpriv rai0 stat | sed 'a <br>'
echo "<p>wifi 2.4G station==============================</p>"
iwpriv ra0 show stainfo; dmesg | tail -n 50 | sed 'a <br>'
iwpriv ra1 show stainfo; dmesg | tail -n 50 | sed 'a <br>'
echo "<p>wifi 5G station==============================</p>"
iwpriv rai0 show stainfo; dmesg | tail -n 50 | sed 'a <br>'
iwpriv rai1 show stainfo; dmesg | tail -n 50 | sed 'a <br>'
echo "<p>========Easymesh========</p>"
objReq easyMeshBasic show | sed 'a <br>'
objReq easyMeshBss show | sed 'a <br>'
if [ $EASYMESH_EN == "1" ]; then
	echo "<p>Topology==============================</p>"
	mapd_cli /tmp/mapd_ctrl dump_topology_v1; cat /tmp/dump.txt | sed 'a <br>'
	echo "<p>Connect status==============================</p>"
	mapd_cli /tmp/mapd_ctrl conn_status | sed 'a <br>'
	echo "<p>Config==============================</p>"
	cat /etc/map/1905d.cfg | sed 'a <br>'
	echo "<p>Mesh info==============================</p>"
	cat /tmp/mesh.txt | sed 'a <br>'
	echo "<p>==============================</p>"
	cat /tmp/mesh_msg.txt | sed 'a <br>'
fi

echo '</body>'
echo '</html>'

exit 0
