#!/bin/sh

. /lib/functions/system.sh
. /usr/share/libubox/jshn.sh
. /lib/hummer/api.sh

PATH_24G=`cat /etc/wireless/l1profile.dat | grep INDEX0_profile_path | cut -d '=' -f 2`
PATH_5G=`cat /etc/wireless/l1profile.dat | grep INDEX1_profile_path | cut -d '=' -f 2`

PATH_SKU_24G=`cat /etc/wireless/l1profile.dat | grep INDEX0_single_sku_path | cut -d '=' -f 2`
PATH_SKU_5G=`cat /etc/wireless/l1profile.dat | grep INDEX1_single_sku_path | cut -d '=' -f 2`

PATH_BF_24G=`cat /etc/wireless/l1profile.dat | grep INDEX0_bf_sku_path | cut -d '=' -f 2`
PATH_BF_5G=`cat /etc/wireless/l1profile.dat | grep INDEX1_bf_sku_path | cut -d '=' -f 2`



show_mpt_info() {

    local support enable region selectedCountry dfs_enable

    json_load "$(objReq wlanMpt json)"
    json_select "WlanMptP"
    json_get_vars name support enable region selectedCountry dfs_enable

	#  sku info
	sku_model=`cat /tmp/sysinfo/board_name`
    sku_product=`gcontrol di get modelNumber | cut -d '=' -f 2`
	sku_cert_region=$region
	
	
	# syscfg info	
    cert_region=$region
    multiregion_support=$support
    multiregion_enable=$enable
    multiregion_region=$region
    multiregion_selectedcountry=$selectedCountry
 
    wl1_dfs_enabled=$dfs_enable   


    target_name=${region}"_"${selectedCountry}


    local tmp_available_channels wl0_available_channels wl1_available_channels wl1_available_channels_dfs
    wlanMPTable=`cat /www/json/wlanMPTable.json` 
    json_load "$wlanMPTable"

    for var in channel_list_2G channel_list_5G channel_list_5G_dfs
    do
        json_select ${var}
        json_get_vars ${target_name}
        #CN    
        [ "$target_name" = "CN_USA" ] &&  tmp_available_channels=$CN_USA
        [ "$target_name" = "CN_CAN" ] &&  tmp_available_channels=$CN_CAN
        [ "$target_name" = "CN_CHN" ] &&  tmp_available_channels=$CN_CHN
        [ "$target_name" = "CN_HKG" ] &&  tmp_available_channels=$CN_HKG
        [ "$target_name" = "CN_MAC" ] &&  tmp_available_channels=$CN_MAC
        [ "$target_name" = "CN_IND" ] &&  tmp_available_channels=$CN_IND
        [ "$target_name" = "CN_PHI" ] &&  tmp_available_channels=$CN_PHI 
        [ "$target_name" = "CN_SGP" ] &&  tmp_available_channels=$CN_SGP
        [ "$target_name" = "CN_THA" ] &&  tmp_available_channels=$CN_THA
        [ "$target_name" = "CN_TWN" ] &&  tmp_available_channels=$CN_TWN
        [ "$target_name" = "CN_KOR" ] &&  tmp_available_channels=$CN_KOR
        [ "$target_name" = "CN_MYS" ] &&  tmp_available_channels=$CN_MYS
        [ "$target_name" = "CN_VNM" ] &&  tmp_available_channels=$CN_VNM
        [ "$target_name" = "CN_XAH" ] &&  tmp_available_channels=$CN_XAH
        [ "$target_name" = "CN_EEE" ] &&  tmp_available_channels=$CN_EEE    
        [ "$target_name" = "CN_AUS" ] &&  tmp_available_channels=$CN_AUS
        [ "$target_name" = "CN_NZL" ] &&  tmp_available_channels=$CN_NZL     
        [ "$target_name" = "CN_XME" ] &&  tmp_available_channels=$CN_XME
        [ "$target_name" = "CN_SAU" ] &&  tmp_available_channels=$CN_SAU
        #AH
        [ "$target_name" = "AH_USA" ] &&  tmp_available_channels=$AH_USA
        [ "$target_name" = "AH_CAN" ] &&  tmp_available_channels=$AH_CAN
        [ "$target_name" = "AH_CHN" ] &&  tmp_available_channels=$AH_CHN
        [ "$target_name" = "AH_HKG" ] &&  tmp_available_channels=$AH_HKG
        [ "$target_name" = "AH_MAC" ] &&  tmp_available_channels=$AH_MAC
        [ "$target_name" = "AH_IND" ] &&  tmp_available_channels=$AH_IND
        [ "$target_name" = "AH_PHI" ] &&  tmp_available_channels=$AH_PHI 
        [ "$target_name" = "AH_SGP" ] &&  tmp_available_channels=$AH_SGP
        [ "$target_name" = "AH_THA" ] &&  tmp_available_channels=$AH_THA
        [ "$target_name" = "AH_TWN" ] &&  tmp_available_channels=$AH_TWN
        [ "$target_name" = "AH_KOR" ] &&  tmp_available_channels=$AH_KOR
        [ "$target_name" = "AH_MYS" ] &&  tmp_available_channels=$AH_MYS
        [ "$target_name" = "AH_VNM" ] &&  tmp_available_channels=$AH_VNM
        [ "$target_name" = "AH_XAH" ] &&  tmp_available_channels=$AH_XAH
        [ "$target_name" = "AH_EEE" ] &&  tmp_available_channels=$AH_EEE    
        [ "$target_name" = "AH_AUS" ] &&  tmp_available_channels=$AH_AUS
        [ "$target_name" = "AH_NZL" ] &&  tmp_available_channels=$AH_NZL     
        [ "$target_name" = "AH_XME" ] &&  tmp_available_channels=$AH_XME
        [ "$target_name" = "AH_SAU" ] &&  tmp_available_channels=$AH_SAU
        ###############################################################
        #CA
        [ "$target_name" = "CA_CAN" ] &&  tmp_available_channels=$CA_CAN
        #KR
        [ "$target_name" = "KR_USA" ] &&  tmp_available_channels=$KR_USA
        [ "$target_name" = "KR_CAN" ] &&  tmp_available_channels=$KR_CAN
        [ "$target_name" = "KR_CHN" ] &&  tmp_available_channels=$KR_CHN
        [ "$target_name" = "KR_HKG" ] &&  tmp_available_channels=$KR_HKG
        [ "$target_name" = "KR_MAC" ] &&  tmp_available_channels=$KR_MAC
        [ "$target_name" = "KR_IND" ] &&  tmp_available_channels=$KR_IND
        [ "$target_name" = "KR_PHI" ] &&  tmp_available_channels=$KR_PHI 
        [ "$target_name" = "KR_SGP" ] &&  tmp_available_channels=$KR_SGP
        [ "$target_name" = "KR_THA" ] &&  tmp_available_channels=$KR_THA
        [ "$target_name" = "KR_TWN" ] &&  tmp_available_channels=$KR_TWN
        [ "$target_name" = "KR_KOR" ] &&  tmp_available_channels=$KR_KOR
        [ "$target_name" = "KR_MYS" ] &&  tmp_available_channels=$KR_MYS
        [ "$target_name" = "KR_VNM" ] &&  tmp_available_channels=$KR_VNM
        [ "$target_name" = "KR_XAH" ] &&  tmp_available_channels=$KR_XAH
        [ "$target_name" = "KR_EEE" ] &&  tmp_available_channels=$KR_EEE    
        [ "$target_name" = "KR_AUS" ] &&  tmp_available_channels=$KR_AUS
        [ "$target_name" = "KR_NZL" ] &&  tmp_available_channels=$KR_NZL     
        [ "$target_name" = "KR_XME" ] &&  tmp_available_channels=$KR_XME
        [ "$target_name" = "KR_SAU" ] &&  tmp_available_channels=$KR_SAU
        #US
        [ "$target_name" = "US_USA" ] &&  tmp_available_channels=$US_USA  
    #######################################################################
    
        json_select ".."
        [ "$var" = "channel_list_2G" ] && wl0_available_channels=$tmp_available_channels
        [ "$var" = "channel_list_5G" ] && wl1_available_channels=$tmp_available_channels
        [ "$var" = "channel_list_5G_dfs" ] && wl1_available_channels_dfs=$tmp_available_channels    

          
    done
    



	# MTK single sku file
    sku_file_24g=`ls -l $PATH_SKU_24G | awk '{print $11}'`
    sku_file_5g=`ls -l $PATH_SKU_5G | awk '{print $11}'`
    sku_bf_file_5g=`ls -l $PATH_BF_5G | awk '{print $11}'`



    echo "sku info"
    echo "  model               = $sku_model"
    echo "  product             = $sku_product"
    echo "  cert_region         = $sku_cert_region"
    echo ""
    echo "syscfg info"
    echo "  cert_region         = $cert_region"
    echo "  multiregion"
    echo "    support           = $multiregion_support"
    echo "    enable            = $multiregion_enable"
    echo "    region            = $multiregion_region"
    echo "    selectedcountry   = $multiregion_selectedcountry"
    echo "  2G channel list     = $wl0_available_channels"
    echo "  5G channel list     = $wl1_available_channels"
    echo "  5G DFS enable       = $wl1_dfs_enabled"

	if [ "wl1_dfs_enabled" = "1" ]; then
    echo "  5G dfs channel list = $wl1_available_channels_dfs"

	fi
	
    echo ""
    echo "MTK single sku file"
    echo "  sku_file_2g           = $sku_file_24g"
    echo "  sku_file_5g           = $sku_file_5g"
    echo "  sku_bf_file_5g        = $sku_bf_file_5g"

    echo ""

}

usage() {

    cat <<EOF
Usage: $0 [show|set_sku SKU|set_country COUNTRY]
  SKU options: US,AH,CN,CA,KR
  COUNTRY options for AH SKU: HKG,IND,PHI,SGP,TWN,THA,XAH,
 Note: The system will reboot if SKU is changed.
 
EOF
    exit 1
}


case "$1" in
    show)
        show_mpt_info
        ;;
    set_sku)
        case "$2" in
            US|AH|CN|KR|CA)

                gcontrol di set cert_region $2
                gcontrol di commit
                echo "system is reset to default..."
                
				#system_reset
				rm -f /tmp/gdata/conf.dat
				rm -rf /overlay/*
				reboot -d 3
                ;;
            *)
                echo "Wrong SKU option!"
                ;;
        esac
        ;;
	set_country)
        SKU=`gcontrol di get cert_region | cut -d"=" -f 2`
        if [ "$SKU" = "AH" ]; then

            objReq wlanMpt setparam selectedCountry $2
			wireless.sh update_mpt
            
			wifi down
			wifi up
			
		elif [ "$SKU" = "US" ]; then
		
            objReq wlanMpt setparam selectedCountry USA
			wireless.sh update_mpt
			
			wifi down
			wifi up
        else
            echo "Could not set country with the $SKU SKU!"
        fi
        ;;	
    *) usage;;
esac
