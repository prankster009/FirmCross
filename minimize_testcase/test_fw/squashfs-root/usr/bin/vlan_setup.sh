#!/bin/sh
. /usr/share/libubox/jshn.sh
. /lib/hummer/state.sh
. /lib/hummer/api.sh

VID_HEX=0
HEX_ARRAY="0123456789abcdef"
dec_to_hex() {
    vlan_tag=$1
    result=""
    while [ $vlan_tag -gt 0 ]; do
        rem_val=`expr $vlan_tag % 16`
        vlan_tag=`expr $vlan_tag / 16`
        case $rem_val in
            15)
                hex_digits='f'
                ;;
            14)
                hex_digits='e'
                ;;
            13)
                hex_digits='d'
                ;;
            12)
                hex_digits='c'
                ;;
            11)
                hex_digits='b'
                ;;
            10)
                hex_digits='a'
                ;;
            *)
                hex_digits="$rem_val"
                ;;
        esac
        result="${hex_digits}${result}"
    done
    if [ ${#result} = 1 ]; then
        result="00${result}"
    elif [ ${#result} = 2 ]; then
        result="0${result}"
    fi
    VID_HEX=${result}
}
# arguments are $1=lan_port, $2=vlan id, $3=vlan priority
# The egress frame to associate WAN port need to
# carry out the VLAN tagged
set_tagged_vlan() {
    echo "set tagged vlan"
    #switch reg w 44 111117
    switch reg w 44 171111
    switch reg w 50 2da824a0 #change Q5 from default priority 4 to 5
    lan_port=$1
    vid=$2
    dec_to_hex $vid
    PRIO_HEX=${HEX_ARRAY:$3:1}

    case $lan_port in
        0)
	# Set ACL Pattern 
	switch reg w 94 ff0${VID_HEX}
	switch reg w 98 8ff0e
	switch reg w 90 80005000

	switch reg w 94 1
	switch reg w 98 0
	switch reg w 90 80009000

	#switch reg w 94 ${prio}0
	#switch reg w 98 0 
	#switch reg w 90 8000b000

	switch reg w 2004 ${PRIO_HEX}ff1803 #set security mode
	#switch reg w 2004 ff0c03
        switch reg w 2010 81000000 # set user port
        switch reg w 94 10110001 # port member 4 and 0 (11 = 0001 0001)
        switch reg w 98 202 # egress tag enable for port 4 and port 0
        switch reg w 90 80001${VID_HEX} # set vlan id
        ;;
        3)
	# Set ACL Pattern 
	switch reg w 94 ff0${VID_HEX}
	switch reg w 98 8ff0e
	switch reg w 90 80005001

	switch reg w 94 2
	switch reg w 98 0
	switch reg w 90 80009001

	#switch reg w 94 ${prio}0
	#switch reg w 98 0 
	#switch reg w 90 8000b001

	switch reg w 2304 ${PRIO_HEX}ff1803 #set security mode
	#switch reg w 2304 ff0c03
        switch reg w 2310 81000000 # set user port
        switch reg w 94 10180001 # port member 4 and 3 (18 = 0001 1000)
        switch reg w 98 280 # egress tag enable for port 4 and port 3
        switch reg w 90 80001${VID_HEX} # set vlan id
        ;;
        2)
	# Set ACL Pattern 
	switch reg w 94 ff0${VID_HEX}
	switch reg w 98 8ff0e
	switch reg w 90 80005002

	switch reg w 94 3
	switch reg w 98 0
	switch reg w 90 80009002

	#switch reg w 94 ${prio}0
	#switch reg w 98 0 
	#switch reg w 90 8000b002

	switch reg w 2204 ${PRIO_HEX}ff1803 #set security mode
	#switch reg w 2204 ff0c03
        switch reg w 2210 81000000 # set user port
        switch reg w 94 10140001 # port member 4 and 2 (14 = 0001 0100)
        switch reg w 98 220 # egress tag enable for port 4 and port 2
        switch reg w 90 80001${VID_HEX} # set vlan id
        ;;
        1)
	# Set ACL Pattern 
	switch reg w 94 ff0${VID_HEX}
	switch reg w 98 8ff0e
	switch reg w 90 80005003

	switch reg w 94 3
	switch reg w 98 0
	switch reg w 90 80009003

	#switch reg w 94 ${prio}0
	#switch reg w 98 0 
	#switch reg w 90 8000b003

	switch reg w 2104 ${PRIO_HEX}ff1803 #set security mode
	#switch reg w 2104 ff0c03
        switch reg w 2110 81000000 # set user port
        switch reg w 94 10120001 # port member 0 and 1 (12 = 0001 0010)
        switch reg w 98 208 # egress tag enble for port 4 and port 1
        switch reg w 90 80001${VID_HEX} # set vlan id
        ;;
        *)
        ;;
    esac
}

# arguments are $1=lan_port, $2=vlan id
# The egress frame to associate WAN port need to
# carry out the VLAN tagged
set_untagged_vlan() {
    echo "set untagged vlan"
    lan_port=$1
    prio=`expr $3 \* 2`
    dec_to_hex $2
    PRIO_HEX=${HEX_ARRAY:$prio:1}
    echo "PRIO: ${PRIO_HEX}"
    case $lan_port in
        0)
        switch reg w 2004 ff0003 # set security mode
        switch reg w 2010 81000000 # set user port
        switch reg w 2014 1${PRIO_HEX}${VID_HEX} # set vlan id of port 4
        switch reg w 94 10110001  # port member 4 and 0 (11 = 0001 0001)
        switch reg w 98 200 # egress tag enable for port 4
        switch reg w 90 80001${VID_HEX} # set vlan id
        ;;
        3)
        switch reg w 2304 ff0003 # set security mode
        switch reg w 2310 81000000
        switch reg w 2314 1${PRIO_HEX}${VID_HEX} # set vlan id of port 3
        switch reg w 94 10180001 # port member 4 and 3 (18 = 0001 1000)
        switch reg w 98 200 # egress tag enable for port 4
        switch reg w 90 80001${VID_HEX} # set vlan id
        ;;
        2)
        switch reg w 2204 ff0003 # set security mode
        switch reg w 2210 81000000
        switch reg w 2214 1${PRIO_HEX}${VID_HEX} # set vlan id of port 2
        switch reg w 94 10140001 # port member 0 and 2 (14 = 0001 0100)
        switch reg w 98 200 # egress tag enable for port 4
        switch reg w 90 80001${VID_HEX} # set vlan id
        ;;
        1)
        switch reg w 2104 ff0003 # set security mode
        switch reg w 2110 81000000
        switch reg w 2114 1${PRIO_HEX}${VID_HEX} # set vlan id of port 1
        switch reg w 94 10120001 # port member 4 and 1 (12 = 0001 0010)
        switch reg w 98 200 # egress tag enable for port 4
        switch reg w 90 80001${VID_HEX} # set vlan id
        ;;
        *)
        ;;
    esac
}

# arguments are $1=vlan id $2=prio $3=iftagged 0/1
# The egress frame to associate WAN port need to
# carry out the VLAN tagged
set_wan_vlan() {
    dec_to_hex $1
    prio=`expr $2 \* 2`
    PRIO_HEX=${HEX_ARRAY:$prio:1}
     
    switch reg w 2510 81000000
    switch reg w 2410 81000000

    switch reg w 2504 ff0003
    switch reg w 2404 ff0c03

    switch reg w 2514 1${PRIO_HEX}${VID_HEX}
    switch reg w 2414 10${VID_HEX}

    switch reg w 94 10300001 # port member 4 and 5 (30 = 0011 0000)
    if [ "$3" = "1" ]; then
        switch reg w 98 a00 # egress tag enable for port 4 and 5
        switch reg w 2410 81000001
    else
        switch reg w 98 800 # egress tag enable for port 5
    fi
    switch reg w 90 80001${VID_HEX} # set vlan id
}

#usage(){
#	echo "wan vlan_id prio iftagged"
#	echo "lan_tagged lan_port, vlan_id, vlan_priority"
#	echo "lan_untagged lan_port, vlan_id, vlan_priority"
#	exit 1
#}

setup_vlan_switch() {
    json_load "$(objReq vlanEnable json)"
    json_select "VlanEnableP"
    json_get_var vlanEnable vlanEnable
    json_load "$(objReq wan json)"
    json_select "WanP"
    json_get_vars ifname proto

    if [ "$vlanEnable" = "1" -a "$proto" != "$WAN_PROTO_BRIDGE" -a "$proto" != "$WAN_PROTO_WLAN_BRIDGE" ]; then
        json_load "$(objReq vlan json)"
        json_select "VlanT"
        local Index="1"
        while json_get_type Type $Index && [ "$Type" = object ]; do
            json_select "$Index"
            json_get_vars descName enable portVID portTag portPriotity portService
            if [ "$enable" = "1" ]; then
                log_info "network/vlan" "#$Index descName:$descName, portVID:$portVID, portTag:$portTag, portPriotity:$portPriotity, portService:$portService"
                port2_wan=0
                port3_wan=0
		switch reg w 50 2da824a0 #change Q5 from default priority 4 to 5
                #check port2/port3 vid are the same
                #port2
                vid2=$(echo $portVID | cut -d ';' -f 4)
                tag2=$(echo $portTag | cut -d ';' -f 4)
                pri2=$(echo $portPriotity | cut -d ';' -f 4)
                service2=$(echo $portService | cut -d ';' -f 4)
                #port3
                vid3=$(echo $portVID | cut -d ';' -f 5)
                tag3=$(echo $portTag | cut -d ';' -f 5)
                pri3=$(echo $portPriotity | cut -d ';' -f 5)
                service3=$(echo $portService | cut -d ';' -f 5)
                if [ -n "$vid2" -a -n "$vid3" -a "$vid2" == "$vid3" ]; then
                    log_info "network/vlan" "both port get the same vid!!!"
                    dec_to_hex $vid2
	            # Set ACL pattern
		    #switch reg w 44 111117
                    switch reg w 44 171111
		    switch reg w 94 ff0${VID_HEX}
		    switch reg w 98 8ff0e
		    switch reg w 90 80005000
	            # ACL Rule 0 Use Pattern 0
		    switch reg w 94 1
		    switch reg w 98 0
		    switch reg w 90 80009000
	            # ACL Rule 0 enter UP prio queue
		    switch reg w 94 ${pri2}0
		    switch reg w 98 0
		    switch reg w 90 8000b000
                    # 1. port2 and port3 are both untagged
		    if [ "$tag2" = "0" -a "$tag3" = "0" ]; then
			log_info "network/vlan" "both port untagged"
                        pri3=`expr $pri3 \* 2`
                        PRIO3_HEX=${HEX_ARRAY:$pri3:1}
		        switch reg w 2304 ff0003
		        switch reg w 2310 81000000 # set user port
		        switch reg w 2314 1${PRIO3_HEX}${VID_HEX} # set vlan id of port 4
                        pri2=`expr $pri2 \* 2`
                        PRIO2_HEX=${HEX_ARRAY:$pri2:1}
		        switch reg w 2204 ff0003
		        switch reg w 2210 81000000
		        switch reg w 2214 1${PRIO2_HEX}${VID_HEX} # set vlan id of port 3
		        switch reg w 94 101c0001 # port number 4, 2 and 3 (1c = 0001 1100)
		        switch reg w 98 200 # egress tag enable only for port 4
		        switch reg w 90 80001${VID_HEX} # set vlan id
                    fi
                    # 2. port2 and port3 are both tagged
		    if [ "$tag2" = "1" -a "$tag3" = "1" ]; then
			log_info "network/vlan" "both port tagged"
                        PRIO3_HEX=${HEX_ARRAY:$pri3:1}
                        switch reg w 2304 ${PRIO3_HEX}ff1803
		        #switch reg w 2304 ff0c03
		        switch reg w 2310 81000000 # set user port
                        PRIO2_HEX=${HEX_ARRAY:$pri2:1}
                        switch reg w 2204 ${PRIO2_HEX}ff1803 #set security mode
		        #switch reg w 2204 ff0c03
		        switch reg w 2210 81000000 # set user port
		        switch reg w 94 101c0001 # port member 4, 2 and 3 (1c = 0001 1100)
		        switch reg w 98 2a0 # egress tag enable for port 2, 3 and port 4
		        switch reg w 90 80001${VID_HEX} # set vlan id
		    fi
                    # 3. port2 is tagged and port3 is untagged
		    if [ "$tag2" = "1" -a "$tag3" = "0" ]; then
		        log_info "network/vlan" "port tagged, port untagged"
		        pri3=`expr $pri3 \* 2`
		        PRIO3_HEX=${HEX_ARRAY:$pri3:1}
		        switch reg w 2304 ff0003 #set security mode
		        switch reg w 2310 81000000 # set user port
		        switch reg w 2314 1${PRIO3_HEX}${VID_HEX}
                        PRIO2_HEX=${HEX_ARRAY:$pri2:1}
                        switch reg w 2204 ${PRIO2_HEX}ff1803 #set security mode
		        #switch reg w 2204 ff0c03
		        switch reg w 2210 81000000 # set user port
		        switch reg w 94 101c0001 # port number 4, 2 and 3 (1c = 0001 1100)
		        switch reg w 98 220 # egress tag enable for port 4 and 2
		        switch reg w 90 80001${VID_HEX} # set vlan id
		    fi
                    # 4. port2 is untagged and port3 is tagged
		    if [ "$tag2" = "0" -a "$tag3" = "1" ]; then
			log_info "network/vlan" "port untagged, port tagged"
		        pri2=`expr $pri2 \* 2`
		        PRIO2_HEX=${HEX_ARRAY:$pri2:1}
		        switch reg w 2204 ff0003
		        switch reg w 2210 81000000
		        switch reg w 2214 1${PRIO2_HEX}${VID_HEX}
                        PRIO3_HEX=${HEX_ARRAY:$pri3:1}
                        switch reg w 2304 ${PRIO3_HEX}ff1803 #set security mode
		        #switch reg w 2304 ff0c03
		        switch reg w 2310 81000000 # set user port
		        switch reg w 94 101c0001 # port number 4, 2 and 3 (1c = 0001 1100)
		        switch reg w 98 280 # egress tag enable for port 4 and 3
		        switch reg w 90 80001${VID_HEX}
		    fi
		else
                    for i in 5 4                                            #Only check port2 and port3 value
                    do
                        pn=$(expr $i - 2)                                   #Get lan port number
                        vid=$(echo $portVID | cut -d ';' -f $i)             #Get lan vid
                        tag=$(echo $portTag | cut -d ';' -f $i)             #Get lan tag status
                        pri=$(echo $portPriotity | cut -d ';' -f $i)        #Get lan priority
                        service=$(echo $portService | cut -d ';' -f $i)     #Get lan port service
                        if [ -n "$vid" -a -n "$tag" -a -n "$pri" ]; then
                            if [ "$tag" = "1" ]; then
                                log_info "network/vlan" "set tagged lan port$pn with [vid=$vid, tag=$tag, prio=$pri, service=$service]"
                                set_tagged_vlan $pn $vid $pri
                            elif [ "$tag" = "0" ]; then
                                log_info "network/vlan" "set untagged lan port$pn with [vid=$vid, tag=$tag, prio=$pri, service=$service]"
                                set_untagged_vlan $pn $vid $pri
                            else
                                echo "Unknown tagged status"
                            fi
                        else
                            case $pn in
                                    2) port2_wan=1 ;;
                                    3) port3_wan=1 ;;
                            esac
                        fi
                    done
                fi

                wvid=$(echo $portVID | cut -d ';' -f 1)             #Get wan vid
                wtag=$(echo $portTag | cut -d ';' -f 1)             #Get wan tag status
                wpri=$(echo $portPriotity | cut -d ';' -f 1)        #Get wan priority
                wservice=$(echo $portService | cut -d ';' -f 1)     #Get wan service
                log_info "network/vlan" "set wan port with [vid=$wvid, tag=$wtag, prio=$wpri, service=$wservice]"
                log_info "network/vlan" "set mapping port2=$port2_wan, port3=$port3_wan"
                switch vlan set 0 1 11${port2_wan}${port3_wan}0011
                set_wan_vlan $wvid $wpri $wtag
            fi
            let Index=$Index+1
            json_select ".."
        done
    fi
}

setup_vlan_wan_priority() {
        json_load "$(objReq vlanEnable json)"
        json_select "VlanEnableP"
        json_get_var vlanEnable vlanEnable
        json_load "$(objReq wan json)"
        json_select "WanP"
        json_get_vars ifname proto
	vlan_wan_ifname=""
	vlan_wan_priority=""
	if [ "$vlanEnable" = "1" -a "$proto" != "$WAN_PROTO_BRIDGE" -a "$proto" != "$WAN_PROTO_WLAN_BRIDGE" ]; then
                json_load "$(objReq vlan json)"
                json_select "VlanT"
                local Index="1"
                while json_get_type Type $Index && [ "$Type" = object ]; do
                        json_select "$Index"
                        json_get_vars enable portVID portPriotity
                        if [ "$enable" = "1" ]; then
                                wvid=$(echo $portVID | cut -d ';' -f 1)
                                wpri=$(echo $portPriotity | cut -d ';' -f 1)
                                vlan_wan_ifname="$ifname"."$wvid"
                                vlan_wan_priority=$wpri
			fi
			let Index=$Index+1
			json_select ".."
		done
	fi
        [ -n $vlan_wan_ifname -a -n $vlan_wan_priority ] && {
                for i in 0 1 2 3 4 5 6 7
                do
                        /sbin/vconfig set_egress_map $vlan_wan_ifname $i $vlan_wan_priority
                done
        }
}

remove_vlan_wan_interface() {
        for i in $(ifconfig -a | grep "eth1.*" | cut -d ' ' -f 1)
        do
            vconfig rem $i 2&>1 > /dev/null
        done
}

usage(){
        echo "vlan_config"
        echo "wan_priority_add"
        echo "wan_priority_remove"
        exit 1
}

action=$1
case "$action" in
    vlan_config)
            log_info "network/vlan" "Start vlan config"
            setup_vlan_switch;;
    wan_priority_add)
            log_info "network/vlan" "add wan priority"
            setup_vlan_wan_priority;;
    wan_priority_remove)
            log_info "network/vlan" "remove wan priority"
            remove_vlan_wan_interface;;
    *)
            usage ;;
esac

