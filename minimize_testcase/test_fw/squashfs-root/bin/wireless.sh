#!/bin/sh

RUNNING="/tmp/wireless.sh-running"
# Make sure only one default script running.
while :
do
    if [ ! -f "$RUNNING" ] ; then
        break
	fi
	echo "exist $RUNNING"
	return 1
done
echo 1 > $RUNNING

# devname
#DEV_24G=MT7603.1
#DEV_5G=MT7663.1
# profile_path
PATH_24G=`cat /etc/wireless/l1profile.dat | grep INDEX0_profile_path | cut -d '=' -f 2`
PATH_5G=`cat /etc/wireless/l1profile.dat | grep INDEX1_profile_path | cut -d '=' -f 2`
# single_sku_path
PATH_SKU_24G=`cat /etc/wireless/l1profile.dat | grep INDEX0_single_sku_path | cut -d '=' -f 2`
PATH_SKU_5G=`cat /etc/wireless/l1profile.dat | grep INDEX1_single_sku_path | cut -d '=' -f 2`
# bf_sku_path
PATH_BF_24G=`cat /etc/wireless/l1profile.dat | grep INDEX0_bf_sku_path | cut -d '=' -f 2`
PATH_BF_5G=`cat /etc/wireless/l1profile.dat | grep INDEX1_bf_sku_path | cut -d '=' -f 2`

. /lib/functions/system.sh
. /usr/share/libubox/jshn.sh
. /lib/hummer/api.sh

json_load "$(objReq wan json)"
json_select "WanP"
json_get_vars proto
log_info "wifi" "wan proto:$proto"

json_load "$(objReq route json)"
json_select "RouteP"
json_get_vars NAT
log_info "wifi" "wan NAT:$NAT"

BYPASS_MAIN_SSID_2G=""
BYPASS_MAIN_SSID_5G=""

wlanMacaddr_update()
{
    log_info "wifi" "wlanMacaddr_update"
	local lan_mac=$(cat /tmp/devinfo/hw_mac_addr)
	[ -z $lan_mac ] && {
		lan_mac=$(cat /sys/class/net/eth0/address)
	}

	wlan_mac_2g=$(macaddr_add "$lan_mac" 2)
	wlan_mac_5g=$(macaddr_add "$lan_mac" 3)


    wificonf -f $PATH_24G set MacAddress $wlan_mac_2g
    wificonf -f $PATH_5G  set MacAddress $wlan_mac_5g
	log_info "wifi" "wlan_mac_2g:$wlan_mac_2g, wlan_mac_5g:$wlan_mac_5g"


}
wlanMpt_singleSKU()
{
   local Selected_Country=$1
   local tmp_PATH_SKU_24G tmp_PATH_SKU_5G  tmp_PATH_BF_5G

    # SKU
    [ "$Selected_Country" = "CHN" ] && tmp_PATH_SKU_24G=$PATH_SKU_24G.CN  && tmp_PATH_SKU_5G=$PATH_SKU_5G.CN  && tmp_PATH_BF_5G=$PATH_BF_5G.CN
    [ "$Selected_Country" = "HKG" ] && tmp_PATH_SKU_24G=$PATH_SKU_24G.HK  && tmp_PATH_SKU_5G=$PATH_SKU_5G.HK  && tmp_PATH_BF_5G=$PATH_BF_5G.HK
    [ "$Selected_Country" = "MAC" ] && tmp_PATH_SKU_24G=$PATH_SKU_24G.MO  && tmp_PATH_SKU_5G=$PATH_SKU_5G.MO  && tmp_PATH_BF_5G=$PATH_BF_5G.MO
    [ "$Selected_Country" = "IND" ] && tmp_PATH_SKU_24G=$PATH_SKU_24G.IN  && tmp_PATH_SKU_5G=$PATH_SKU_5G.IN  && tmp_PATH_BF_5G=$PATH_BF_5G.IN
    [ "$Selected_Country" = "PHI" ] && tmp_PATH_SKU_24G=$PATH_SKU_24G.PH  && tmp_PATH_SKU_5G=$PATH_SKU_5G.PH  && tmp_PATH_BF_5G=$PATH_BF_5G.PH
    [ "$Selected_Country" = "SGP" ] && tmp_PATH_SKU_24G=$PATH_SKU_24G.SG  && tmp_PATH_SKU_5G=$PATH_SKU_5G.SG  && tmp_PATH_BF_5G=$PATH_BF_5G.SG
    [ "$Selected_Country" = "THA" ] && tmp_PATH_SKU_24G=$PATH_SKU_24G.TH  && tmp_PATH_SKU_5G=$PATH_SKU_5G.TH  && tmp_PATH_BF_5G=$PATH_BF_5G.TH
    [ "$Selected_Country" = "TWN" ] && tmp_PATH_SKU_24G=$PATH_SKU_24G.TW  && tmp_PATH_SKU_5G=$PATH_SKU_5G.TW  && tmp_PATH_BF_5G=$PATH_BF_5G.TW
    [ "$Selected_Country" = "KOR" ] && tmp_PATH_SKU_24G=$PATH_SKU_24G.KR  && tmp_PATH_SKU_5G=$PATH_SKU_5G.KR  && tmp_PATH_BF_5G=$PATH_BF_5G.KR
    [ "$Selected_Country" = "MYS" ] && tmp_PATH_SKU_24G=$PATH_SKU_24G.MY  && tmp_PATH_SKU_5G=$PATH_SKU_5G.MY  && tmp_PATH_BF_5G=$PATH_BF_5G.MY
    [ "$Selected_Country" = "VNM" ] && tmp_PATH_SKU_24G=$PATH_SKU_24G.VN  && tmp_PATH_SKU_5G=$PATH_SKU_5G.VN  && tmp_PATH_BF_5G=$PATH_BF_5G.VN
    [ "$Selected_Country" = "XAH" ] && tmp_PATH_SKU_24G=$PATH_SKU_24G.XAH && tmp_PATH_SKU_5G=$PATH_SKU_5G.XAH && tmp_PATH_BF_5G=$PATH_BF_5G.XAH

    [ "$Selected_Country" = "EEE" ] && tmp_PATH_SKU_24G=$PATH_SKU_24G.CE  && tmp_PATH_SKU_5G=$PATH_SKU_5G.CE  && tmp_PATH_BF_5G=$PATH_BF_5G.CE
    [ "$Selected_Country" = "AUS" ] && tmp_PATH_SKU_24G=$PATH_SKU_24G.AU  && tmp_PATH_SKU_5G=$PATH_SKU_5G.AU  && tmp_PATH_BF_5G=$PATH_BF_5G.AU
    [ "$Selected_Country" = "NZL" ] && tmp_PATH_SKU_24G=$PATH_SKU_24G.NZ  && tmp_PATH_SKU_5G=$PATH_SKU_5G.NZ  && tmp_PATH_BF_5G=$PATH_BF_5G.NZ
    [ "$Selected_Country" = "XME" ] && tmp_PATH_SKU_24G=$PATH_SKU_24G.XME && tmp_PATH_SKU_5G=$PATH_SKU_5G.XME && tmp_PATH_BF_5G=$PATH_BF_5G.XME
    [ "$Selected_Country" = "SAU" ] && tmp_PATH_SKU_24G=$PATH_SKU_24G.SA  && tmp_PATH_SKU_5G=$PATH_SKU_5G.SA  && tmp_PATH_BF_5G=$PATH_BF_5G.SA


    [ "$Selected_Country" = "CAN" ] && tmp_PATH_SKU_24G=$PATH_SKU_24G.CA  && tmp_PATH_SKU_5G=$PATH_SKU_5G.CA  && tmp_PATH_BF_5G=$PATH_BF_5G.CA

    [ "$Selected_Country" = "USA" ] && tmp_PATH_SKU_24G=$PATH_SKU_24G.FCC && tmp_PATH_SKU_5G=$PATH_SKU_5G.FCC && tmp_PATH_BF_5G=$PATH_BF_5G.FCC


    # SKU
    ln -sf $tmp_PATH_SKU_24G $PATH_SKU_24G
    ln -sf $tmp_PATH_SKU_5G  $PATH_SKU_5G
    # BF
    ln -sf $tmp_PATH_BF_5G   $PATH_BF_5G
    log_info "wifi" "sku_file_2g:$tmp_PATH_SKU_24G"
    log_info "wifi" "sku_file_5g:$tmp_PATH_SKU_5G"
    log_info "wifi" "sku_bf_file_5g:$tmp_PATH_BF_5G"
}

wlanMpt_update()
{
    log_info "wifi" "wlanMpt_update"
    local support enable region selectedCountry dfs_enable

    json_load "$(objReq wlanMpt json)"
    json_select "WlanMptP"
    json_get_vars support enable region selectedCountry dfs_enable

    log_info "wifi" "support:$support, enable:$enable, region:$region, selectedCountry:$selectedCountry, dfs_enable:$dfs_enable"

    local CountryRegion CountryRegionABand CountryCode


    if [ "$region" = "US" ]; then

        CountryRegion=0 && CountryRegionABand=10 && CountryCode=US && wlanMpt_singleSKU USA
        objReq wlanMpt setparam selectedCountry USA

    elif [ "$region" = "CA" ]; then
        CountryRegion=0 && CountryRegionABand=10 && CountryCode=CA && wlanMpt_singleSKU CAN
        objReq wlanMpt setparam selectedCountry CAN

    elif [ "$region" = "CN" -o "$region" = "AH" -o "$region" = "KR" ] && [ "$dfs_enable" = "1" ]; then
        # dfs_enable
        [ "$selectedCountry" = "USA" ] &&  CountryRegion=0 && CountryRegionABand=10 && CountryCode=US && wlanMpt_singleSKU $selectedCountry
        [ "$selectedCountry" = "CAN" ] &&  CountryRegion=0 && CountryRegionABand=10 && CountryCode=CA && wlanMpt_singleSKU $selectedCountry
        [ "$selectedCountry" = "CHN" ] &&  CountryRegion=1 && CountryRegionABand=10 && CountryCode=CN && wlanMpt_singleSKU $selectedCountry
        [ "$selectedCountry" = "HKG" ] &&  CountryRegion=0 && CountryRegionABand=7  && CountryCode=HK && wlanMpt_singleSKU $selectedCountry
        [ "$selectedCountry" = "MAC" ] &&  CountryRegion=0 && CountryRegionABand=7  && CountryCode=MO && wlanMpt_singleSKU $selectedCountry
        [ "$selectedCountry" = "IND" ] &&  CountryRegion=0 && CountryRegionABand=7  && CountryCode=IN && wlanMpt_singleSKU $selectedCountry
        [ "$selectedCountry" = "PHI" ] &&  CountryRegion=0 && CountryRegionABand=7  && CountryCode=PH && wlanMpt_singleSKU $selectedCountry
        [ "$selectedCountry" = "SGP" ] &&  CountryRegion=1 && CountryRegionABand=7  && CountryCode=SG && wlanMpt_singleSKU $selectedCountry
        [ "$selectedCountry" = "THA" ] &&  CountryRegion=1 && CountryRegionABand=7  && CountryCode=TH && wlanMpt_singleSKU $selectedCountry
        [ "$selectedCountry" = "TWN" ] &&  CountryRegion=0 && CountryRegionABand=7  && CountryCode=TW && wlanMpt_singleSKU $selectedCountry
        [ "$selectedCountry" = "KOR" ] &&  CountryRegion=1 && CountryRegionABand=10 && CountryCode=TW && wlanMpt_singleSKU $selectedCountry
        [ "$selectedCountry" = "MYS" ] &&  CountryRegion=1 && CountryRegionABand=7  && CountryCode=MY && wlanMpt_singleSKU $selectedCountry
        [ "$selectedCountry" = "VNM" ] &&  CountryRegion=0 && CountryRegionABand=10 && CountryCode=VN && wlanMpt_singleSKU $selectedCountry
        [ "$selectedCountry" = "XAH" ] &&  CountryRegion=1 && CountryRegionABand=10 && CountryCode=TH && wlanMpt_singleSKU $selectedCountry
        [ "$selectedCountry" = "EEE" ] &&  CountryRegion=1 && CountryRegionABand=6  && CountryCode=EU && wlanMpt_singleSKU $selectedCountry
        [ "$selectedCountry" = "AUS" ] &&  CountryRegion=1 && CountryRegionABand=6  && CountryCode=AU && wlanMpt_singleSKU $selectedCountry
        [ "$selectedCountry" = "NZL" ] &&  CountryRegion=1 && CountryRegionABand=6  && CountryCode=NZ && wlanMpt_singleSKU $selectedCountry
        [ "$selectedCountry" = "XME" ] &&  CountryRegion=1 && CountryRegionABand=6  && CountryCode=EU && wlanMpt_singleSKU $selectedCountry
        [ "$selectedCountry" = "SAU" ] &&  CountryRegion=1 && CountryRegionABand=6  && CountryCode=SA && wlanMpt_singleSKU $selectedCountry

    elif [ "$region" = "CN" -o "$region" = "AH" -o "$region" = "KR" ] && [ "$dfs_enable" = "0" ]; then
        #dfs_enable = 0
        [ "$selectedCountry" = "USA" ] &&  CountryRegion=0 && CountryRegionABand=10 && CountryCode=US && wlanMpt_singleSKU $selectedCountry
        [ "$selectedCountry" = "CAN" ] &&  CountryRegion=0 && CountryRegionABand=10 && CountryCode=CA && wlanMpt_singleSKU $selectedCountry
        [ "$selectedCountry" = "CHN" ] &&  CountryRegion=1 && CountryRegionABand=10 && CountryCode=CN && wlanMpt_singleSKU $selectedCountry
        [ "$selectedCountry" = "HKG" ] &&  CountryRegion=0 && CountryRegionABand=10 && CountryCode=HK && wlanMpt_singleSKU $selectedCountry
        [ "$selectedCountry" = "MAC" ] &&  CountryRegion=1 && CountryRegionABand=10 && CountryCode=MO && wlanMpt_singleSKU $selectedCountry
        [ "$selectedCountry" = "IND" ] &&  CountryRegion=0 && CountryRegionABand=10 && CountryCode=IN && wlanMpt_singleSKU $selectedCountry
        [ "$selectedCountry" = "PHI" ] &&  CountryRegion=1 && CountryRegionABand=10 && CountryCode=PH && wlanMpt_singleSKU $selectedCountry
        [ "$selectedCountry" = "SGP" ] &&  CountryRegion=1 && CountryRegionABand=10 && CountryCode=SG && wlanMpt_singleSKU $selectedCountry
        [ "$selectedCountry" = "THA" ] &&  CountryRegion=1 && CountryRegionABand=10 && CountryCode=TH && wlanMpt_singleSKU $selectedCountry
        [ "$selectedCountry" = "TWN" ] &&  CountryRegion=0 && CountryRegionABand=10 && CountryCode=TW && wlanMpt_singleSKU $selectedCountry
        [ "$selectedCountry" = "KOR" ] &&  CountryRegion=1 && CountryRegionABand=10 && CountryCode=KR && wlanMpt_singleSKU $selectedCountry
        [ "$selectedCountry" = "MYS" ] &&  CountryRegion=1 && CountryRegionABand=10 && CountryCode=MY && wlanMpt_singleSKU $selectedCountry
        [ "$selectedCountry" = "VNM" ] &&  CountryRegion=1 && CountryRegionABand=10 && CountryCode=VN && wlanMpt_singleSKU $selectedCountry
        [ "$selectedCountry" = "XAH" ] &&  CountryRegion=1 && CountryRegionABand=10 && CountryCode=TH && wlanMpt_singleSKU $selectedCountry
        [ "$selectedCountry" = "EEE" ] &&  CountryRegion=1 && CountryRegionABand=6  && CountryCode=EU && wlanMpt_singleSKU $selectedCountry
        [ "$selectedCountry" = "AUS" ] &&  CountryRegion=1 && CountryRegionABand=6  && CountryCode=AU && wlanMpt_singleSKU $selectedCountry
        [ "$selectedCountry" = "NZL" ] &&  CountryRegion=1 && CountryRegionABand=6  && CountryCode=NZ && wlanMpt_singleSKU $selectedCountry
        [ "$selectedCountry" = "XME" ] &&  CountryRegion=1 && CountryRegionABand=6  && CountryCode=EU && wlanMpt_singleSKU $selectedCountry
        [ "$selectedCountry" = "SAU" ] &&  CountryRegion=1 && CountryRegionABand=6  && CountryCode=SA && wlanMpt_singleSKU $selectedCountry

    fi

    log_info "wifi" "CountryRegion:$CountryRegion, CountryRegionABand:$CountryRegionABand, CountryCode:$CountryCode"
    wificonf -f $PATH_24G set CountryRegion $CountryRegion
    wificonf -f $PATH_24G set CountryCode $CountryCode
    wificonf -f $PATH_24G set CountryRegionABand $CountryRegionABand

    wificonf -f $PATH_5G  set CountryRegion $CountryRegion
    wificonf -f $PATH_5G  set CountryRegionABand $CountryRegionABand
    wificonf -f $PATH_5G  set CountryCode $CountryCode

}

wlanBasic_update()
{
    log_info "wifi" "wlanBasic_update"

    json_load "$(objReq easyMeshBasic json)"
    json_select EasyMeshBasicP
    json_get_var easymesh_enable enable
    json_get_var device_role deviceRole
    json_select ".."

    json_load "$(objReq wlanBasic json)"
    json_select "WlanBasicT"
    local Index="1"

    local mapd_cfg_path="/etc/map/mapd_cfg"

    while json_get_type Type $Index && [ "$Type" = object ]; do
        local enable wifimode ssid  ifname channel type bw hiddenAP ETxBfEnCond

        json_select "$Index"
        json_get_vars enable wifimode ssid  ifname channel type bw hiddenAP ETxBfEnCond

        log_info "wifi" "#$Index enable:$enable, wifimode:$wifimode, ssid:$ssid, ifname:$ifname, channel:$channel"
		log_info "wifi" " type:$type, bw:$bw, hiddenAP:$hiddenAP, ETxBfEnCond:$ETxBfEnCond"

        local config_path
        if [ $type = "2" ]; then
            config_path=$PATH_24G
			onoff_2g=$enable
        elif [ $type = "5" ]; then
            config_path=$PATH_5G
			onoff_5g=$enable
        fi

        #update geust network SSID1
        [ "$type" = "2" -a  "$ssid" != "" ] && BYPASS_MAIN_SSID_2G="$ssid"
        [ "$type" = "5" -a  "$ssid" != "" ] && BYPASS_MAIN_SSID_5G="$ssid"



		WIFI_CMD_SSID=$(echo "$ssid" | sed 's/[$]/\$/g')
		WIFI_CMD_SSID=$(echo "$WIFI_CMD_SSID" | sed 's/[`]/\`/g')
		WIFI_CMD_SSID=$(echo "$WIFI_CMD_SSID" | sed 's/["]/\"/g')

        wificonf -f $config_path set WirelessMode $wifimode
        wificonf -f $config_path set SSID1 "$WIFI_CMD_SSID"

        if [ "$easymesh_enable" = "1" ]; then
            if [ "$channel" = "0" ]; then
                if [ "$type" = "2" ]; then
                    wificonf -f $config_path set Channel 6
                elif [ "$type" = "5" ]; then
                    wificonf -f $config_path set Channel 36
                fi
            else
                if [ "$type" = "2" ]; then
                    wificonf -f $mapd_cfg_path set ChPlanningUserPreferredChannel2G $channel
                elif [ "$type" = "5" ]; then
                    wificonf -f $mapd_cfg_path set ChPlanningUserPreferredChannel5G $channel
                    wificonf -f $mapd_cfg_path set ChPlanningUserPreferredChannel5GH $channel
                fi
            fi
        else
            wificonf -f $config_path set Channel $channel
        fi

        if  [ "$easymesh_enable" = "1" ]; then
            wificonf -f $config_path set AutoChannelSelect 0
        elif  [ "$channel" = "0" ]; then
            wificonf -f $config_path set AutoChannelSelect 2
        else
            wificonf -f $config_path set AutoChannelSelect 0
            [ $type = "2" ] && [ "$channel" -lt "5" ] && wificonf -f $config_path set HT_EXTCHA 1
            [ $type = "2" ] && [ "$channel" -gt "7" ] && wificonf -f $config_path set HT_EXTCHA 0

        fi

        wificonf -f $config_path set HideSSID 0 $hiddenAP


        wificonf -f $config_path set ETxBfEnCond $ETxBfEnCond

        if  [ $type = "2" ] && [ $bw = "0" ]; then
            wificonf -f $config_path set HT_BW 1
            wificonf -f $config_path set VHT_BW 0
            wificonf -f $config_path set HT_BSSCoexistence 1

        elif  [ $type = "2" ] && [ $bw = "2" ]; then
            wificonf -f $config_path set HT_BW 1
            wificonf -f $config_path set VHT_BW 0
            wificonf -f $config_path set HT_BSSCoexistence 0


        elif  [ $type = "5" ] && [ $bw = "0" -o $bw = "3" ]; then
            wificonf -f $config_path set HT_BW 1
            wificonf -f $config_path set VHT_BW 1

        elif [ $type = "5" ] && [ $bw = "2" ]; then
            wificonf -f $config_path set HT_BW 1
            wificonf -f $config_path set VHT_BW 0
        else

            wificonf -f $config_path set HT_BW 0
            wificonf -f $config_path set VHT_BW 0
        fi

        if  [ $easymesh_enable = "1" ]; then
            wificonf -f $config_path set MapMode 1
        else
            wificonf -f $config_path set MapMode 0
        fi

        wificonf -f $config_path set DeviceRole $device_role

		#Add StationKeepAlive
		wificonf -f $config_path set StationKeepAlive 3

        let Index=$Index+1
        json_select ".."

    done

}
wlanGuset_update()
{
    log_info "wifi" "wlanGuset_update"

    [ "$NAT" = "0" ] && {
        objReq wlanGuest setparam 0 enable 0
        objReq wlanGuest setparam 1 enable 0
    }

    [ "$onoff_2g" = "0" ] && objReq wlanGuest setparam 0 enable 0
    [ "$onoff_5g" = "0" ] && objReq wlanGuest setparam 1 enable 0



    [ "$BYPASS_MAIN_SSID_2G" != "" ] && objReq wlanGuest setparam 0 ssid ${BYPASS_MAIN_SSID_2G:0:25}-guest

    local default_ssid=`cat /tmp/devinfo/default_ssid`
    if [ "$BYPASS_MAIN_SSID_5G" = "${default_ssid}_5GHz" ] ; then
        objReq wlanGuest setparam 1 ssid ${BYPASS_MAIN_SSID_5G:0:25}-guest
    else
        [ "$BYPASS_MAIN_SSID_5G" != "" ] && objReq wlanGuest setparam 1 ssid ${BYPASS_MAIN_SSID_5G:0:20}_5GHz-guest
    fi

    json_load "$(objReq wlanGuest json)"
    json_select "WlanGuestT"
    local Index="1" gst_enable_2g=0 gst_enable_5g=0
    local enable ssid type ifname wpaPsk hiddenAP maxStaNum

    while json_get_type Type $Index && [ "$Type" = object ]; do


        json_select "$Index"
        json_get_vars enable ssid type ifname wpaPsk hiddenAP maxStaNum
        log_info "wifi" "#$Index enable:$enable, ssid:$ssid, ifname:$ifname"
        log_info "wifi" " type:$type, wpaPsk:$wpaPsk, hiddenAP:$hiddenAP, maxStaNum:$maxStaNum"

        [ $enable = "1" -a $type = "2" ] && gst_enable_2g=1
        [ $enable = "1" -a $type = "5" ] && gst_enable_5g=1

        local config_path
        [ $type = "2" ] && config_path=$PATH_24G
        [ $type = "5" ] && config_path=$PATH_5G


        wificonf -f $config_path set SSID2 "$ssid"
        wificonf -f $config_path set HideSSID 1 $hiddenAP
        wificonf -f $config_path set AuthMode 1 OPEN
        wificonf -f $config_path set EncrypType 1 NONE
        wificonf -f $config_path set MaxStaNum 1 16

        let Index=$Index+1
        json_select ".."
    done

    if [ "$gst_enable_2g" = "1"  -o "$gst_enable_5g" = "1" ]; then
        uci set nodogsplash.@instance[0].enabled=1
        iptables -I FORWARD -i $WAN_IF -o br-guest -m state --state RELATED,ESTABLISHED -j ACCEPT

        local gst_macaddr
        [ "$onoff_2g" = "0" -a "$onoff_5g" = "1" ] && {
            uci set network.guest.ifname='rai1'
            gst_macaddr=`ifconfig rai1 | grep HWaddr | awk '{print $5}'`

            [ "$gst_macaddr" != "" ] && {
                uci set network.guest.macaddr=$gst_macaddr
                ifconfig br-guest hw ether $gst_macaddr
            }

        }
        [ "$onoff_2g" = "1" -a "$onoff_5g" = "0" ] && {
            uci set network.guest.ifname='ra1'
            gst_macaddr=`ifconfig ra1 | grep HWaddr | awk '{print $5}'`

            [ "$gst_macaddr" != "" ] && {
                uci set network.guest.macaddr=$gst_macaddr
                ifconfig br-guest hw ether $gst_macaddr
            }

        }
        [ "$onoff_2g" = "1" -a "$onoff_5g" = "1" ] && {
            uci set network.guest.ifname='ra1 rai1'
            gst_macaddr=`ifconfig ra1 | grep HWaddr | awk '{print $5}'`

            [ "$gst_macaddr" != "" ] && {
                uci set network.guest.macaddr=$gst_macaddr
                ifconfig br-guest hw ether $gst_macaddr
            }
            objReq wlanGuest setparam 0 enable 1
            objReq wlanGuest setparam 1 enable 1
        }
        log_info "wifi" "br-guest MacAddr:$gst_macaddr"
        uci commit network
    else
        uci set nodogsplash.@instance[0].enabled=0
    fi

    uci set nodogsplash.@instance[0].maxclients=$maxStaNum

	WIFI_CMD_WPAPSK=$(echo "$wpaPsk" | sed 's/[$]/\$/g')
	WIFI_CMD_WPAPSK=$(echo "$WIFI_CMD_WPAPSK" | sed 's/[`]/\`/g')
	WIFI_CMD_WPAPSK=$(echo "$WIFI_CMD_WPAPSK" | sed 's/["]/\"/g')

    uci set nodogsplash.@instance[0].password=$WIFI_CMD_WPAPSK



	local lan_ipaddr=`uci get network.lan.ipaddr`

	uci set nodogsplash.@instance[0].authenticated_users="block to $lan_ipaddr/24"
	uci add_list nodogsplash.@instance[0].authenticated_users="allow tcp port 22"
	uci add_list nodogsplash.@instance[0].authenticated_users="allow tcp port 53"
	uci add_list nodogsplash.@instance[0].authenticated_users="allow udp port 53"
	uci add_list nodogsplash.@instance[0].authenticated_users="allow tcp port 80"
	uci add_list nodogsplash.@instance[0].authenticated_users="allow tcp port 443"




	uci set nodogsplash.@instance[0].users_to_router="drop to $lan_ipaddr/24"
	uci add_list nodogsplash.@instance[0].users_to_router="allow tcp port 22"
	uci add_list nodogsplash.@instance[0].users_to_router="allow tcp port 23"
	uci add_list nodogsplash.@instance[0].users_to_router="allow tcp port 53"
	uci add_list nodogsplash.@instance[0].users_to_router="allow udp port 53"
	uci add_list nodogsplash.@instance[0].users_to_router="allow udp port 67"
	uci add_list nodogsplash.@instance[0].users_to_router="allow udp port 80"
	uci add_list nodogsplash.@instance[0].users_to_router="allow udp port 443"

    uci commit nodogsplash


    WAN_IF=`uci -q get network.wan.ifname`

    local lanZoneIdx
    lanZoneIdx=$(uci show firewall | awk "/zone/ && /name='lan'/" | tr -dc '0-9')

    if [ "$proto" = "5" -o "$proto" = "6" ]; then
        uci set firewall.@zone[$lanZoneIdx].masq=1
    else
        uci delete firewall.@zone[$lanZoneIdx].masq
    fi
    uci commit firewall

}

wlanSecurity_update()
{
    log_info "wifi" "wlanSecurity_update"

    json_load "$(objReq wlanSecurity json)"
    json_select "WlanSecurityT"
    local Index="1"
    while json_get_type Type $Index && [ "$Type" = object ]; do
        local  type ifname authtype encrypType wpaPsk rs_ip rs_port rs_password

        json_select "$Index"
        json_get_vars type ifname authtype encrypType wpaPsk rs_ip rs_port rs_password
        log_info "wifi" "#$Index ifname:$ifname, type:$type, authtype:$authtype, encrypType:$encrypType, wpaPsk:$wpaPsk"
		log_info "wifi" " rs_ip:$rs_ip, rs_port:$rs_port, rs_password:$rs_password"

        local config_path

        [ $type = "2" ] && config_path=$PATH_24G
        [ $type = "5" ] && config_path=$PATH_5G


		WIFI_CMD_WPAPSK=$(echo "$wpaPsk" | sed 's/[$]/\$/g')
		WIFI_CMD_WPAPSK=$(echo "$WIFI_CMD_WPAPSK" | sed 's/[`]/\`/g')
		WIFI_CMD_WPAPSK=$(echo "$WIFI_CMD_WPAPSK" | sed 's/["]/\"/g')


        wificonf -f $config_path set AuthMode 0 $authtype
        wificonf -f $config_path set EncrypType 0 $encrypType
        wificonf -f $config_path set WPAPSK1 "$WIFI_CMD_WPAPSK"
		#wificonf -f $config_path set RADIUS_Server "$rs_ip"
		#wificonf -f $config_path set RADIUS_Port $rs_port
		#wificonf -f $config_path set RADIUS_Key1 "$rs_password"


        if [ "$authtype" = "WPA3PSK" ] ; then
            wificonf -f $config_path set PMFMFPC 0 1
            wificonf -f $config_path set PMFMFPR 0 1
            wificonf -f $config_path set PMFSHA256 0 0
            wificonf -f $config_path set RekeyMethod 0 TIME

        elif [ "$authtype" = "WPA2PSK" ] ; then
            wificonf -f $config_path set PMFMFPC 0 1
            wificonf -f $config_path set PMFMFPR 0 0
            wificonf -f $config_path set PMFSHA256 0 0
            wificonf -f $config_path set RekeyMethod 0 TIME

        elif [ "$authtype" = "OWE" ] ; then
            wificonf -f $config_path set PMFMFPC 0 1
            wificonf -f $config_path set PMFMFPR 0 1
            wificonf -f $config_path set PMFSHA256 0 0
            wificonf -f $config_path set RekeyMethod 0 DISABLE

        elif [ "$authtype" = "WPAPSKWPA2PSK" ] ; then
            wificonf -f $config_path set PMFMFPC 0 0
            wificonf -f $config_path set PMFMFPR 0 0
            wificonf -f $config_path set PMFSHA256 0 0
            wificonf -f $config_path set RekeyMethod 0 TIME

        elif [ "$authtype" = "WPA2PSKWPA3PSK" ] ; then
            wificonf -f $config_path set PMFMFPC 0 1
            wificonf -f $config_path set PMFMFPR 0 0
            wificonf -f $config_path set PMFSHA256 0 0
            wificonf -f $config_path set RekeyMethod 0 TIME

        else
            wificonf -f $config_path set PMFMFPC 0 0
            wificonf -f $config_path set PMFMFPR 0 0
            wificonf -f $config_path set PMFSHA256 0 0
            wificonf -f $config_path set RekeyMethod 0 DISABLE
        fi

        let Index=$Index+1
        json_select ".."
    done

}
wlanMacFilter_update()
{

    log_info "wifi" "wlanMacFilter_update"
    json_load "$(objReq wlanMacFilter json)"
    json_select "WlanMacFilterT"
    local Index="1"
    while json_get_type Type $Index && [ "$Type" = object ]; do
        local enable aclmode
        local mac0 mac1 mac2 mac3 mac4 mac5 mac6 mac7
        local mac8 mac9 mac10 mac11 mac12 mac13 mac14 mac15
        local mac16 mac17 mac18 mac19 mac20 mac21 mac22 mac23
        local mac24 mac25 mac26 mac27 mac28 mac29 mac30 mac31

        json_select "$Index"
        json_get_vars enable aclmode mac0 mac1 mac2 mac3 mac4 mac5 mac6 mac7 mac8 mac9 mac10 mac11 mac12 mac13 mac14 mac15 mac16 mac17 mac18 mac19 mac20 mac21 mac22 mac23 mac24 mac25 mac26 mac27 mac28 mac29 mac30 mac31

        log_info "wifi" "#$Index enable:$enable, aclmode:$aclmode"
        log_info "wifi" " mac0~7:   $mac0 $mac1 $mac2 $mac3 $mac4 $mac5 $mac6 $mac7"
        log_info "wifi" " mac8~15:  $mac8 $mac9 $mac10 $mac11 $mac12 $mac13 $mac14 $mac15"
        log_info "wifi" " mac16~23: $mac16 $mac17 $mac18 $mac19 $mac20 $mac21 $mac22 $mac23"
        log_info "wifi" " mac24~31: $mac24 $mac25 $mac26 $mac27 $mac28 $mac29 $mac30 $mac31"

        local path mac_list=""
        local dot=";"

        [ "$mac0" != "" ] && mac_list=$mac0;
        [ "$mac1" != "" ] && mac_list=$mac_list$dot$mac1;
        [ "$mac2" != "" ] && mac_list=$mac_list$dot$mac2;
        [ "$mac3" != "" ] && mac_list=$mac_list$dot$mac3;
        [ "$mac4" != "" ] && mac_list=$mac_list$dot$mac4;
        [ "$mac5" != "" ] && mac_list=$mac_list$dot$mac5;
        [ "$mac6" != "" ] && mac_list=$mac_list$dot$mac6;
        [ "$mac7" != "" ] && mac_list=$mac_list$dot$mac7;

        [ "$mac8" != "" ] && mac_list=$mac_list$dot$mac8;
        [ "$mac9" != "" ] && mac_list=$mac_list$dot$mac9;
        [ "$mac10" != "" ] && mac_list=$mac_list$dot$mac10;
        [ "$mac11" != "" ] && mac_list=$mac_list$dot$mac11;
        [ "$mac12" != "" ] && mac_list=$mac_list$dot$mac12;
        [ "$mac13" != "" ] && mac_list=$mac_list$dot$mac13;
        [ "$mac14" != "" ] && mac_list=$mac_list$dot$mac14;
        [ "$mac15" != "" ] && mac_list=$mac_list$dot$mac15;

        [ "$mac16" != "" ] && mac_list=$mac_list$dot$mac16;
        [ "$mac17" != "" ] && mac_list=$mac_list$dot$mac17;
        [ "$mac18" != "" ] && mac_list=$mac_list$dot$mac18;
        [ "$mac19" != "" ] && mac_list=$mac_list$dot$mac19;
        [ "$mac20" != "" ] && mac_list=$mac_list$dot$mac20;
        [ "$mac21" != "" ] && mac_list=$mac_list$dot$mac21;
        [ "$mac22" != "" ] && mac_list=$mac_list$dot$mac22;
        [ "$mac23" != "" ] && mac_list=$mac_list$dot$mac23;

        [ "$mac24" != "" ] && mac_list=$mac_list$dot$mac24;
        [ "$mac25" != "" ] && mac_list=$mac_list$dot$mac25;
        [ "$mac26" != "" ] && mac_list=$mac_list$dot$mac26;
        [ "$mac27" != "" ] && mac_list=$mac_list$dot$mac27;
        [ "$mac28" != "" ] && mac_list=$mac_list$dot$mac28;
        [ "$mac29" != "" ] && mac_list=$mac_list$dot$mac29;
        [ "$mac30" != "" ] && mac_list=$mac_list$dot$mac30;
        [ "$mac31" != "" ] && mac_list=$mac_list$dot$mac31;

        # rm ;
        [ "${mac_list:0:1}" == ";" ] && mac_list=${mac_list:1}


        log_info "wifi" " mac_list:$mac_list"
        wificonf -f $PATH_24G set AccessPolicy0 $aclmode
        wificonf -f $PATH_24G set AccessControlList0 "$mac_list"
        wificonf -f $PATH_24G set AccessPolicy1 $aclmode
        wificonf -f $PATH_24G set AccessControlList1 "$mac_list"

        wificonf -f $PATH_5G set AccessPolicy0 $aclmode
        wificonf -f $PATH_5G set AccessControlList0 "$mac_list"
        wificonf -f $PATH_5G set AccessPolicy1 $aclmode
        wificonf -f $PATH_5G set AccessControlList1 "$mac_list"


        let Index=$Index+1
        json_select ".."
    done

}

wlanWps_update()
{

    log_info "wifi" "wlanWps_update"

    json_load "$(objReq wlanWps json)"
    json_select "WlanWpsT"
    local Index="1"
    while json_get_type Type $Index && [ "$Type" = object ]; do
        local  enable wscConfMode wscConfStatus routerPIN WscModelNumber WscSerialNumber

        json_select "$Index"
        json_get_vars enable wscConfMode wscConfStatus routerPIN WscModelNumber WscSerialNumber
        log_info "wifi" "#$Index enable:$enable, wscConfMode:$wscConfMode, wscConfStatus:$wscConfStatus"
        log_info "wifi" " PIN:$routerPIN, Model:$WscModelNumber, SN:$WscSerialNumber"


		if [ $enable = "1" ] ; then
			wificonf -f $PATH_24G set WscConfMode 7
			wificonf -f $PATH_24G set WscConfStatus $wscConfStatus
			wificonf -f $PATH_5G set WscConfMode 7
			wificonf -f $PATH_5G set WscConfStatus $wscConfStatus
        else
			wificonf -f $PATH_24G set WscConfMode 0
			wificonf -f $PATH_24G set WscConfStatus $wscConfStatus
			wificonf -f $PATH_5G set WscConfMode 0
			wificonf -f $PATH_5G set WscConfStatus $wscConfStatus
		fi


        if [ "$routerPIN" != "" ]; then
            wificonf -f $PATH_24G set WscVendorPinCode $routerPIN
            wificonf -f $PATH_5G set WscVendorPinCode $routerPIN
        fi

        if [ "$WscModelNumber" != "" ]; then
            wificonf -f $PATH_24G set WscModelNumber $WscModelNumber
            wificonf -f $PATH_5G  set WscModelNumber $WscModelNumber
        fi

        if [ "$WscSerialNumber" != "" ]; then
            wificonf -f $PATH_24G set WscSerialNumber $WscSerialNumber
            wificonf -f $PATH_5G  set WscSerialNumber $WscSerialNumber
        fi

        #let Index=$Index+1
        #json_select ".."
    done

}


wlanBridge_update()
{
    log_info "wifi" "wlanBridge_update"

    if [ $proto = "6" ]; then
        objReq wlanBridge setparam 0 enable 1
		objReq wlanBridge setparam 1 enable 1
    else
        objReq wlanBridge setparam 0 enable 0
		objReq wlanBridge setparam 1 enable 0
    fi


    json_load "$(objReq wlanBridge json)"
    json_select "WlanBridgeT"
    local Index="1"


    while json_get_type Type $Index && [ "$Type" = object ]; do
        local  ssid ifname type authtype encrypType wpaPsk

        json_select "$Index"
        json_get_vars ssid ifname type authtype encrypType wpaPsk

        log_info "wifi" "#$Index ssid:$ssid, ifname:$ifname, type:$type"
        log_info "wifi" " authtype:$authtype, encrypType:$encrypType, wpaPsk:$wpaPsk"


        local config_path
        if [ $type = "2" ]; then
            config_path=$PATH_24G
            ifname_cmd="apcli0"

        elif [ $type = "5" ]; then
            config_path=$PATH_5G
            ifname_cmd="apclii0"
        fi

        if [ $proto = "6" -a  $type = "2" ]; then
            wificonf -f $PATH_24G set ApCliEnable 1
            wificonf -f $PATH_5G  set ApCliEnable 0

        elif [ $proto = "6" -a  $type = "5" ]; then
            wificonf -f $PATH_24G set ApCliEnable 0
            wificonf -f $PATH_5G  set ApCliEnable 1
        else
            wificonf -f $PATH_24G set ApCliEnable 0
            wificonf -f $PATH_5G  set ApCliEnable 0
        fi

		WIFI_CMD_SSID=$(echo "$ssid" | sed 's/[$]/\$/g')
		WIFI_CMD_SSID=$(echo "$WIFI_CMD_SSID" | sed 's/[`]/\`/g')
		WIFI_CMD_SSID=$(echo "$WIFI_CMD_SSID" | sed 's/["]/\"/g')


		WIFI_CMD_WPAPSK=$(echo "$wpaPsk" | sed 's/[$]/\$/g')
		WIFI_CMD_WPAPSK=$(echo "$WIFI_CMD_WPAPSK" | sed 's/[`]/\`/g')
		WIFI_CMD_WPAPSK=$(echo "$WIFI_CMD_WPAPSK" | sed 's/["]/\"/g')

        wificonf -f $config_path set ApCliSsid "$WIFI_CMD_SSID"
        wificonf -f $config_path set ApCliAuthMode $authtype
        wificonf -f $config_path set ApCliEncrypType $encrypType
        wificonf -f $config_path set ApCliWPAPSK "$WIFI_CMD_WPAPSK"


        if [ "$authtype" = "WPA3PSK" ] ; then
            wificonf -f $config_path set ApCliPMFMFPC 1
            wificonf -f $config_path set ApCliPMFMFPR 1
            wificonf -f $config_path set ApCliPMFSHA256 1

        elif [ "$authtype" = "WPA2PSK" ] ; then
            wificonf -f $config_path set ApCliPMFMFPC 1
            wificonf -f $config_path set ApCliPMFMFPR 0
            wificonf -f $config_path set ApCliPMFSHA256 0

        elif [ "$authtype" = "WPAPSK"  ] ; then
            wificonf -f $config_path set ApCliPMFMFPC 0
            wificonf -f $config_path set ApCliPMFMFPR 0
            wificonf -f $config_path set ApCliPMFSHA256 0

        else
            wificonf -f $config_path set ApCliPMFMFPC 0
            wificonf -f $config_path set ApCliPMFMFPR 0
            wificonf -f $config_path set ApCliPMFSHA256 0
        fi

        #let Index=$Index+1
        #json_select ".."
    done

}

wlanWMM_update()
{
    log_info "wifi" "wlanWMM_update Qos"
    json_load "$(objReq qos json)"
    json_select "QosP"
    json_get_vars wmmEnable wmmNoAckEnable

    # WMM Support
    PATH_24G=`cat /etc/wireless/l1profile.dat | grep INDEX0_profile_path | cut -d '=' -f 2`
    PATH_5G=`cat /etc/wireless/l1profile.dat | grep INDEX1_profile_path | cut -d '=' -f 2`

    local p_WmmCapable p_AckPolicy

    p_WmmCapable=`wificonf -f $PATH_24G get WmmCapable 0`
    p_AckPolicy=`wificonf -f  $PATH_5G  get AckPolicy  2`

    if [ "$wmmEnable" = "0" ]; then
        wificonf -f $PATH_24G set WmmCapable 0
        wificonf -f $PATH_5G  set WmmCapable 0

    else
        wificonf -f $PATH_24G set WmmCapable 1
        wificonf -f $PATH_5G  set WmmCapable 1

        # Acknowledgement policy
        if [ "$wmmNoAckEnable" = "1" ]; then
            wificonf -f  $PATH_24G set AckPolicy  2 1
            wificonf -f  $PATH_24G set AckPolicy  3 1
            wificonf -f  $PATH_5G  set AckPolicy  2 1
            wificonf -f  $PATH_5G  set AckPolicy  3 1

        else
            wificonf -f  $PATH_24G set AckPolicy  2 0
            wificonf -f  $PATH_24G set AckPolicy  3 0
            wificonf -f  $PATH_5G  set AckPolicy  2 0
            wificonf -f  $PATH_5G  set AckPolicy  3 0
        fi
    fi
}

wireless_MFG_check()
{
	MFG_MODE=$(gcontrol uenv get ManufactureMode | awk -F"=" '{print $2}')

	[ "$MFG_MODE" = "" -o "$MFG_MODE" = "0" ] && {
		# 2.4G
		echo "Wireless Normal Mode" > /dev/console

		# 5G
	}

	[ "$MFG_MODE" = "1" ] && {

		echo "Wireless Manufcture Mode" > /dev/console
		# 2.4G
		wificonf -f $PATH_24G set HT_BSSCoexistence 0
		# 5G
	}

	[ "$MFG_MODE" = "2" ] && {
		echo "Wireless Golden Mode" > /dev/console
	}

	[ "$MFG_MODE" = "3" ] && {
		echo "Wireless EasyMesh Certification Mode" > /dev/console

		nvram_set 2860 BssidNum 2
		nvram_set rtdev BssidNum 2

		nvram_set 2860 MAP_Ext "32;32;32;32;32;32;32;32"
		nvram_set rtdev MAP_Ext "32;32;32;32;32;32;32;32"
		nvram_set 2860 map_controller 1
		nvram_set 2860 map_agent 1
		nvram_set 2860 map_root 0
		nvram_set 2860 bh_type wifi
		nvram_set 2860 HT_BW 0
		nvram_set rtdev HT_BW 0

		nvram_set 2860 RRMEnable "1;1"
		nvram_set rtdev RRMEnable "1;1"

		nvram_set 2860 VHT_BW 0
		nvram_set rtdev VHT_BW 0
		nvram_set 2860 AutoChannelSelect 0
		nvram_set rtdev AutoChannelSelect 0
		nvram_set 2860 SteerEnable 1
		nvram_set 2860 MapMode 4
		nvram_set rtdev MapMode 4

		nvram_set 2860 radio_band "24G;5G;5G;"
		nvram_set 2860 Channel 6
		nvram_set rtdev Channel 36

		nvram_set 2860 DBDC_MODE 0
		nvram_set rtdev DBDC_MODE 0

		nvram_set lan_inf_name eth0
		nvram_set br_inf_name br-lan

		wificonf -f $PATH_24G set IgmpSnEnable 0
		wificonf -f $PATH_24G set WscConfMode 0
		wificonf -f $PATH_24G set WscConfStatus "1;1;1;1"
		wificonf -f $PATH_24G set AuthMode OPEN
		wificonf -f $PATH_24G set EncrypType NONE
		wificonf -f $PATH_24G set ETxBfEnCond 0
		wificonf -f $PATH_24G set HT_BSSCoexistence 0
		wificonf -f $PATH_24G set RekeyMethod DISABLE
		wificonf -f $PATH_24G set SKUenable 0
		wificonf -f $PATH_24G set StationKeepAlive 0
		wificonf -f $PATH_24G set CountryCode ""
		wificonf -f $PATH_24G set CountryRegion 5
		wificonf -f $PATH_24G set CountryRegionABand 7

		wificonf -f $PATH_5G set IgmpSnEnable 0
		wificonf -f $PATH_5G set WscConfMode 0
		wificonf -f $PATH_5G set WscConfStatus "1;1;1;1"
		wificonf -f $PATH_5G set AuthMode OPEN
		wificonf -f $PATH_5G set EncrypType NONE
		wificonf -f $PATH_5G set ETxBfEnCond 0
		wificonf -f $PATH_5G set HT_BSSCoexistence 0
		wificonf -f $PATH_5G set RekeyMethod DISABLE
		wificonf -f $PATH_5G set SKUenable 0
		wificonf -f $PATH_5G set StationKeepAlive 0
		wificonf -f $PATH_5G set PMFMFPC 0
		wificonf -f $PATH_5G set CountryCode ""
		wificonf -f $PATH_5G set CountryRegion 5
		wificonf -f $PATH_5G set CountryRegionABand 7
	}

}

easymesh_config_sync()
{
    log_info "wifi" "easymesh_config_sync"

    local em_enable

    json_load "$(objReq easyMeshBasic json)"
    json_select EasyMeshBasicP
    json_get_var em_enable enable
    json_select ".."

    if [ "$em_enable" = "1" ]; then
        json_load "$(objReq easyMeshBss json)"
        json_select EasyMeshBssP
        #local authType encrypType authType5G encrypType5G
        local ssid wpaPsk ssid5G wpaPsk5G
        #json_get_vars ssid authType encrypType wpaPsk ssid5G authType5G encrypType5G wpaPsk5G
        json_get_vars ssid wpaPsk ssid5G wpaPsk5G
        json_select ".."

        log_info "wifi" "sync #easymesh ssid:$ssid, authtype:$authType"
        log_info "wifi" "sync #easymesh encrypType:$encrypType, wpaPsk:$wpaPsk"
        log_info "wifi" "sync #easymesh ssid5G:$ssid5G, authtype5G:$authType5G"
        log_info "wifi" "sync #easymesh encrypType5G:$encrypType5G, wpaPsk5G:$wpaPsk5G"

        objReq wlanBasic setparam 0 ssid "$ssid"
        objReq wlanBasic setparam 1 ssid "$ssid5G"

        #objReq wlanSecurity setparam 0 authtype "$authType"
        #objReq wlanSecurity setparam 0 encrypType "$encrypType"
        objReq wlanSecurity setparam 0 wpaPsk "$wpaPsk"

        #objReq wlanSecurity setparam 1 authtype "$authType5G"
        #objReq wlanSecurity setparam 1 encrypType "$encrypType5G"
        objReq wlanSecurity setparam 1 wpaPsk "$wpaPsk5G"
        
        #update IdleTimeout setting
        wificonf -f $PATH_24G set IdleTimeout 60
        wificonf -f $PATH_5G  set IdleTimeout 80
        
    else
        json_load "$(objReq wlanSecurity json)"
        json_select "WlanSecurityT"
        local Index="1"

        while json_get_type Type $Index && [ "$Type" = object ]; do
            #local authtype encrypType
            local type wpaPsk
            json_select "$Index"
            #json_get_vars type authtype encrypType wpaPsk
            json_get_vars type wpaPsk
            json_select ".."

            log_info "wifi" "sync #$Index type:$type, authtype:$authtype, encrypType:$encrypType, wpaPsk:$wpaPsk"

            if [ "$type" = "2" ]; then
                #objReq easyMeshBss setparam authType "$authtype"
                #objReq easyMeshBss setparam encrypType "$encrypType"
                if [ -n "$wpaPsk" ]; then
                    objReq easyMeshBss setparam wpaPsk "$wpaPsk"
                fi
            elif [ "$type" = "5" ]; then
                #objReq easyMeshBss setparam authType5G "$authtype"
                #objReq easyMeshBss setparam encrypType5G "$encrypType"
                if [ -n "$wpaPsk" ]; then
                    objReq easyMeshBss setparam wpaPsk5G "$wpaPsk"
                fi
            fi

            let Index=$Index+1
        done

        json_load "$(objReq wlanBasic json)"
        json_select "WlanBasicT"
        Index="1"

        while json_get_type Type $Index && [ "$Type" = object ]; do
            local ssid
            json_select "$Index"
            json_get_vars ssid type
            json_select ".."

            log_info "wifi" "sync #$Index type:$type, ssid:$ssid"

            if [ "$type" = "2" ]; then
                 objReq easyMeshBss setparam ssid "$ssid"
            elif [ "$type" = "5" ]; then
                 objReq easyMeshBss setparam ssid5G "$ssid"
            fi

            let Index=$Index+1
        done
        
        #update IdleTimeout setting
        wificonf -f $PATH_24G set IdleTimeout 300
        wificonf -f $PATH_5G  set IdleTimeout 480

    fi

    gnvram commit
}

update_wireless_config()
{
    log_info "wifi" "update_wireless_config"

    easymesh_config_sync

    wlanMacaddr_update
    wlanMpt_update
    wlanBasic_update
    wlanSecurity_update
    wlanGuset_update
    wlanMacFilter_update
    wlanBridge_update
    wlanWps_update
    # Add wmm check
    wlanWMM_update

    # MFG check
    wireless_MFG_check


    log_info "wifi" "update_wireless_config end"
    rcConf restart upnpd
}

wireless_services_stop()
{
    log_info "wifi" "wireless_services_stop"
    WAN_IF=`uci -q get network.wan.ifname`
    iptables -D FORWARD -i $WAN_IF -o br-guest -m state --state RELATED,ESTABLISHED -j ACCEPT

    log_info "wifi" "wireless_services_stop end"
}

wireless_start()
{
    log_info "wifi" "wireless_start $1"
    update_wireless_config

    wifi reload

    log_info "wifi" "wireless_start end"
}


wireless_stop()
{

    log_info "wifi" "wireless_stop $1"

    wireless_services_stop
    wifi down

    log_info "wifi" "wireless_stop end"
}

wireless_restart()
{
    wireless_stop $1
    wireless_start $1

}

usage(){
    echo "$0 [update_config|start|stop|restart]"

}

action=$1
network=$2

case "$action" in

    update_config)
        update_wireless_config ;;

    start)
        wireless_start $network ;;

    stop)
        wireless_stop $network ;;

    restart)
        wireless_restart $network ;;

    update_wlanBridge)
        wlanBridge_update ;;

    update_mpt)
        wlanMpt_update ;;
    *)
        usage ;;

esac

rm $RUNNING
