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


echo "Content-type: text/html"
echo ""

echo '<!doctype html>'
echo '<html>'
echo '<head>'
echo '<meta charset="UTF-8" name="viewport" content="width=device-width; initial-scale=1.0; maximum-scale=1.0; user-scalable=0;">'
echo '<title>FQC</title>'
echo '<link href="/css/fqc.css" rel="stylesheet" type="text/css">'
echo '</head>'
echo '<body class="marginBody">'
echo '<p></p>'
echo '<p class="Title">FQC info</p>'

echo "<p class='content'>Firmware Version: $FW_VERSION </p>"
echo "<p class='content'>Module Name: $SET_MODULE_NAME </p>"
echo "<p class='content'>Serial Number: $SET_SN </p>"

if [ $REGION == $SET_REGION ]; then
	REGIN_RET="(vaild Region)"
else
	REGIN_RET="(invalid Region, Region should be $SET_REGION)"
fi
echo "<p class='content'>Region: $REGION $REGIN_RET </p>"

#SHOW_SET_BASE_MAC=`echo $SET_BASE_MAC | sed s/://g`
#echo "<p class='content'>Base MAC: $SHOW_SET_BASE_MAC </p>"

SHOW_LABLE_MAC=`echo $WAN_MAC | sed s/://g | tr '[a-z]' '[A-Z]'`
echo "<p class='content'>Label MAC: $SHOW_LABLE_MAC </p>"

ULAN_MAC=`echo $LAN_MAC | tr '[a-z]' '[A-Z]'`
if [ $LAN_MAC == $SET_BASE_MAC -o $ULAN_MAC == $SET_BASE_MAC ]; then
	MAC_RET="(vaild MAC)"
else
	MAC_RET="(invalid MAC, should be $SET_BASE_MAC)"
fi
echo "<p class='content'>Lan MAC: $LAN_MAC $MAC_RET</p>"
echo "<p class='content'>Wan MAC: $WAN_MAC </p>"
echo "<p class='content'>WiFi 2.4G MAC: $W2G_MAC </p>"
echo "<p class='content'>WiFi 5G MAC: $W5G_MAC </p>"

if [ $ESSID_2G == $SET_SSID ]; then
	CHK_ESSID_2G_RET="(valid 2.4G SSID)"
else
	CHK_ESSID_2G_RET="(invalid 2.4G SSID, should be $SET_SSID)"
fi

if [ $ESSID_5G == $SET_SSID'_5GHz' ]; then
	CHK_ESSID_5G_RET="(valid 5G SSID)"
else
	CHK_ESSID_5G_RET="(invalid 5G SSID, should be $SET_SSID'_5GHz')"
fi

echo "<p class='content'>2.4G ESSID: $ESSID_2G $CHK_ESSID_2G_RET </p>"
echo "<p class='content'>5G ESSID: $ESSID_5G $CHK_ESSID_5G_RET </p>"

if [ $WIFI_PASSWORD == $SET_PASSWORD ]; then
	PASSWORD_RET="(valid password)"
else
	PASSWORD_RET="(invalid password, should be $SET_PASSWORD)"
fi
echo "<p class='content'>Default wifi password: $WIFI_PASSWORD $PASSWORD_RET </p>"

if [ $WPSPIN == $SET_WPSPIN ]; then
	WPSPIN_RET="(valid WPS PIN)"
else
	WPSPIN_RET="(invalid WPS PIN, should be $SET_WPSPIN)"
fi
echo "<p class='content'>Default WPS PIN: $WPSPIN $WPSPIN_RET </p>"

BootMode=`gcontrol uenv get ManufactureMode | cut -d '=' -f 2`
BootPart=`gcontrol uenv get boot_part | cut -d '=' -f 2`
echo "<p class='content'>Mode: $BootMode , Part: $BootPart</p>"

echo '</body>'
echo '</html>'

exit 0
