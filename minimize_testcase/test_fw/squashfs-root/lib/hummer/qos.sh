#!/bin/sh

. /usr/share/libubox/jshn.sh
. /lib/hummer/api.sh

flush_classify_rules() {
    while uci -q delete qos.@classify[0]; do :; done
}

setup_classify_rules() {
    json_load "$(objReq qosPolicy json)"
    json_select "QosPolicyT"
    local Index="1"
    while json_get_type Type $Index && [ "$Type" = object ]; do
        local serviceName priority category deviceMac
        local serviceProto1 servicePortStart1 servicePortEnd1
        local serviceProto2 servicePortStart2 servicePortEnd2
        local serviceProto3 servicePortStart3 servicePortEnd3
        local qosTarget

        json_select "$Index"
        json_get_vars serviceName priority category deviceMac \
            serviceProto1 servicePortStart1 servicePortEnd1 \
            serviceProto2 servicePortStart2 servicePortEnd2 \
            serviceProto3 servicePortStart3 servicePortEnd3

        # Check priority
        if [ "$priority" = "0" ]; then      # low
            qosTarget='Low'
        elif [ "$priority" = "1" ]; then    # normal
            qosTarget='Normal'
        elif [ "$priority" = "2" ]; then    # medium
            qosTarget='Medium'
        elif [ "$priority" = "3" ]; then    # high
            qosTarget='High'
        else
            qosTarget='Normal'
        fi

        if [ "$category" = "0" ]; then      # applications
            log_info "qos" "add application: $serviceName"
            case "$serviceName" in
                "msn") # MSN Messenger
                    uci add qos classify
                    uci set qos.@classify[-1].target=$qosTarget
                    uci set qos.@classify[-1].proto=tcp
                    uci set qos.@classify[-1].dstports='443,1863'
                    uci set qos.@classify[-1].comment="$serviceName"
                    ;;
                "skype") # Skype
                    uci add qos classify
                    uci set qos.@classify[-1].target=$qosTarget
                    uci set qos.@classify[-1].proto=tcp
                    uci set qos.@classify[-1].dstports='80,443,30809'
                    uci set qos.@classify[-1].comment="$serviceName"
                    ;;
                "ym") # Yahoo Messenger
                    uci add qos classify
                    uci set qos.@classify[-1].target=$qosTarget
                    uci set qos.@classify[-1].proto=tcp
                    uci set qos.@classify[-1].dstports='5000,5001,5050'
                    uci set qos.@classify[-1].comment="$serviceName"
                    ;;
                "wlm") # Windows Live Messenger
                    uci add qos classify
                    uci set qos.@classify[-1].target=$qosTarget
                    uci set qos.@classify[-1].proto=tcp
                    uci set qos.@classify[-1].dstports='5000,5001'
                    uci set qos.@classify[-1].comment="$serviceName"
                    uci add qos classify
                    uci set qos.@classify[-1].target=$qosTarget
                    uci set qos.@classify[-1].proto=udp
                    uci set qos.@classify[-1].dstports='5055'
                    uci set qos.@classify[-1].comment="$serviceName"
                    ;;
                "aim") # AIM
                    uci add qos classify
                    uci set qos.@classify[-1].target=$qosTarget
                    uci set qos.@classify[-1].proto=tcp
                    uci set qos.@classify[-1].dstports='443,5190'
                    uci set qos.@classify[-1].comment="$serviceName"
                    uci add qos classify
                    uci set qos.@classify[-1].target=$qosTarget
                    uci set qos.@classify[-1].proto=udp
                    uci set qos.@classify[-1].dstports='443,5190'
                    uci set qos.@classify[-1].comment="$serviceName"
                    ;;
                "wmp") # Windows Media Player
                    uci add qos classify
                    uci set qos.@classify[-1].target=$qosTarget
                    uci set qos.@classify[-1].proto=udp
                    uci set qos.@classify[-1].dstports='1024:5000'
                    uci set qos.@classify[-1].comment="$serviceName"
                    uci add qos classify
                    uci set qos.@classify[-1].target=$qosTarget
                    uci set qos.@classify[-1].proto=udp
                    uci set qos.@classify[-1].dstports='5004,5005'
                    uci set qos.@classify[-1].comment="$serviceName"
                    uci add qos classify
                    uci set qos.@classify[-1].target=$qosTarget
                    uci set qos.@classify[-1].proto=tcp
                    uci set qos.@classify[-1].dstports='80,554,8080'
                    uci set qos.@classify[-1].comment="$serviceName"
                    uci add qos classify
                    uci set qos.@classify[-1].target=$qosTarget
                    uci set qos.@classify[-1].proto=tcp
                    uci set qos.@classify[-1].dstports='1755'
                    uci set qos.@classify[-1].comment="$serviceName"
                    uci add qos classify
                    uci set qos.@classify[-1].target=$qosTarget
                    uci set qos.@classify[-1].proto=udp
                    uci set qos.@classify[-1].dstports='1755'
                    uci set qos.@classify[-1].comment="$serviceName"
                    ;;
                "real") # RealPlayer
                    uci add qos classify
                    uci set qos.@classify[-1].target=$qosTarget
                    uci set qos.@classify[-1].proto=udp
                    uci set qos.@classify[-1].dstports='6970:7170'
                    uci set qos.@classify[-1].comment="$serviceName"
                    uci add qos classify
                    uci set qos.@classify[-1].target=$qosTarget
                    uci set qos.@classify[-1].proto=tcp
                    uci set qos.@classify[-1].dstports='554,7070'
                    uci set qos.@classify[-1].comment="$serviceName"
                    ;;
                "qtime") # QuickTime
                    uci add qos classify
                    uci set qos.@classify[-1].target=$qosTarget
                    uci set qos.@classify[-1].proto=tcp
                    uci set qos.@classify[-1].dstports='80'
                    uci set qos.@classify[-1].comment="$serviceName"
                    ;;
                "itunes") #iTunes
                    uci add qos classify
                    uci set qos.@classify[-1].target=$qosTarget
                    uci set qos.@classify[-1].proto=tcp
                    uci set qos.@classify[-1].dstports='3689'
                    uci set qos.@classify[-1].comment="$serviceName"
                    uci add qos classify
                    uci set qos.@classify[-1].target=$qosTarget
                    uci set qos.@classify[-1].proto=udp
                    uci set qos.@classify[-1].dstports='3689'
                    uci set qos.@classify[-1].comment="$serviceName"
                    ;;
                "ymj") # Yahoo Music Jukebox
                    uci add qos classify
                    uci set qos.@classify[-1].target=$qosTarget
                    uci set qos.@classify[-1].proto=tcp
                    uci set qos.@classify[-1].dstports='443,80'
                    uci set qos.@classify[-1].comment="$serviceName"
                    ;;
                "rhap") # Rhapsody
                    uci add qos classify
                    uci set qos.@classify[-1].target=$qosTarget
                    uci set qos.@classify[-1].proto=udp
                    uci set qos.@classify[-1].dstports='6370:32000'
                    uci set qos.@classify[-1].comment="$serviceName"
                    uci add qos classify
                    uci set qos.@classify[-1].target=$qosTarget
                    uci set qos.@classify[-1].proto=tcp
                    uci set qos.@classify[-1].dstports='7070,443,4040,8080,80,554'
                    uci set qos.@classify[-1].comment="$serviceName"
                    uci add qos classify
                    uci set qos.@classify[-1].target=$qosTarget
                    uci set qos.@classify[-1].proto=tcp
                    uci set qos.@classify[-1].dstports='1755'
                    uci set qos.@classify[-1].comment="$serviceName"
                    uci add qos classify
                    uci set qos.@classify[-1].target=$qosTarget
                    uci set qos.@classify[-1].proto=udp
                    uci set qos.@classify[-1].dstports='1755'
                    uci set qos.@classify[-1].comment="$serviceName"
                    ;;
                *)
                    for cnt in 1 2 3; do
                        proto=$(eval echo \$serviceProto$cnt)
                        portStart=$(eval echo \$servicePortStart$cnt)
                        portEnd=$(eval echo \$servicePortEnd$cnt)
                        if [ "$proto" = "1" -o "$proto" = "3" ]; then #tcp, both
                            uci add qos classify
                            uci set qos.@classify[-1].target=$qosTarget
                            uci set qos.@classify[-1].proto=tcp
                            if [ "$portStart" = "$portEnd" ]; then
                                uci set qos.@classify[-1].dstports="$portStart"
                            else
                                uci set qos.@classify[-1].dstports="$portStart:$portEnd"
                            fi
                            uci set qos.@classify[-1].comment="$serviceName"
                        fi
                        if [ "$proto" = "2" -o "$proto" = "3" ]; then #udp, both
                            uci add qos classify
                            uci set qos.@classify[-1].target=$qosTarget
                            uci set qos.@classify[-1].proto=udp
                            if [ "$portStart" = "$portEnd" ]; then
                                uci set qos.@classify[-1].dstports="$portStart"
                            else
                                uci set qos.@classify[-1].dstports="$portStart:$portEnd"
                            fi
                            uci set qos.@classify[-1].comment="$serviceName"
                        fi
                    done
                    ;;
            esac

        elif [ "$category" = "1" ]; then    # online games
            log "qos" "add online game: $serviceName"
            case "$serviceName" in
                "nwn2") # Neverwinter Nights 2
                    uci add qos classify
                    uci set qos.@classify[-1].target=$qosTarget
                    uci set qos.@classify[-1].proto=tcp
                    uci set qos.@classify[-1].dstports='1200,27030:27039'
                    uci set qos.@classify[-1].comment="$serviceName"
                    uci add qos classify
                    uci set qos.@classify[-1].target=$qosTarget
                    uci set qos.@classify[-1].proto=udp
                    uci set qos.@classify[-1].dstports='27000:27019'
                    uci set qos.@classify[-1].comment="$serviceName"
                    ;;
                "et") # Enemy Territory
                    uci add qos classify
                    uci set qos.@classify[-1].target=$qosTarget
                    uci set qos.@classify[-1].proto=tcp
                    uci set qos.@classify[-1].dstports='6073,2302:2400'
                    uci set qos.@classify[-1].comment="$serviceName"
                    uci add qos classify
                    uci set qos.@classify[-1].target=$qosTarget
                    uci set qos.@classify[-1].proto=udp
                    uci set qos.@classify[-1].dstports='6073,2302:2400'
                    uci set qos.@classify[-1].comment="$serviceName"
                    ;;
                "wic") # World In Conflict
                    uci add qos classify
                    uci set qos.@classify[-1].target=$qosTarget
                    uci set qos.@classify[-1].proto=tcp
                    uci set qos.@classify[-1].dstports='4000'
                    uci set qos.@classify[-1].comment="$serviceName"
                    uci add qos classify
                    uci set qos.@classify[-1].target=$qosTarget
                    uci set qos.@classify[-1].proto=tcp
                    uci set qos.@classify[-1].dstports='6112:6119'
                    uci set qos.@classify[-1].comment="$serviceName"
                    uci add qos classify
                    uci set qos.@classify[-1].target=$qosTarget
                    uci set qos.@classify[-1].proto=udp
                    uci set qos.@classify[-1].dstports='6112:6119'
                    uci set qos.@classify[-1].comment="$serviceName"
                    ;;
                "cod4") # Call of Duty 4
                    uci add qos classify
                    uci set qos.@classify[-1].target=$qosTarget
                    uci set qos.@classify[-1].proto=tcp
                    uci set qos.@classify[-1].dstports='7000,1024:6000'
                    uci set qos.@classify[-1].comment="$serviceName"
                    uci add qos classify
                    uci set qos.@classify[-1].target=$qosTarget
                    uci set qos.@classify[-1].proto=udp
                    uci set qos.@classify[-1].dstports='7000,1024:6000'
                    uci set qos.@classify[-1].comment="$serviceName"
                    ;;
                "sins") # Sins of a Solar Empire
                    uci add qos classify
                    uci set qos.@classify[-1].target=$qosTarget
                    uci set qos.@classify[-1].proto=tcp
                    uci set qos.@classify[-1].dstports='6003,7002'
                    uci set qos.@classify[-1].comment="$serviceName"
                    uci add qos classify
                    uci set qos.@classify[-1].target=$qosTarget
                    uci set qos.@classify[-1].proto=udp
                    uci set qos.@classify[-1].dstports='27005,27010,27011,27015,27018,27026'
                    uci set qos.@classify[-1].comment="$serviceName"
                    ;;
                "hl2ob") # Half-Life 2: The Orange Box
                    uci add qos classify
                    uci set qos.@classify[-1].target=$qosTarget
                    uci set qos.@classify[-1].proto=tcp
                    uci set qos.@classify[-1].dstports='27910'
                    uci set qos.@classify[-1].comment="$serviceName"
                    uci add qos classify
                    uci set qos.@classify[-1].target=$qosTarget
                    uci set qos.@classify[-1].proto=udp
                    uci set qos.@classify[-1].dstports='27910'
                    uci set qos.@classify[-1].comment="$serviceName"
                    ;;
                "crysis") # Crysis
                    uci add qos classify
                    uci set qos.@classify[-1].target=$qosTarget
                    uci set qos.@classify[-1].proto=tcp
                    uci set qos.@classify[-1].dstports='27660'
                    uci set qos.@classify[-1].comment="$serviceName"
                    uci add qos classify
                    uci set qos.@classify[-1].target=$qosTarget
                    uci set qos.@classify[-1].proto=udp
                    uci set qos.@classify[-1].dstports='27660'
                    uci set qos.@classify[-1].comment="$serviceName"
                    ;;
                "fl") # Frontlines
                    uci add qos classify
                    uci set qos.@classify[-1].target=$qosTarget
                    uci set qos.@classify[-1].proto=tcp
                    uci set qos.@classify[-1].dstports='8080,27900,7777:7783'
                    uci set qos.@classify[-1].comment="$serviceName"
                    uci add qos classify
                    uci set qos.@classify[-1].target=$qosTarget
                    uci set qos.@classify[-1].proto=udp
                    uci set qos.@classify[-1].dstports='8080,27900,7777:7783'
                    uci set qos.@classify[-1].comment="$serviceName"
                    ;;
                "wh") # Warhammer 40,000: Dawn of War: Soulstorm
                    uci add qos classify
                    uci set qos.@classify[-1].target=$qosTarget
                    uci set qos.@classify[-1].proto=udp
                    uci set qos.@classify[-1].dstports='27950,27960,27965,27952'
                    uci set qos.@classify[-1].comment="$serviceName"
                    ;;
                "stalker") # S.T.A.L.K.E.R.: Shadow of Chernobyl
                    uci add qos classify
                    uci set qos.@classify[-1].target=$qosTarget
                    uci set qos.@classify[-1].proto=tcp
                    uci set qos.@classify[-1].dstports='3783,6515,6667,13139,27900,28900,29900,29901'
                    uci set qos.@classify[-1].comment="$serviceName"
                    ;;
                "wow") # World Of Warcraft
                    uci add qos classify
                    uci set qos.@classify[-1].target=$qosTarget
                    uci set qos.@classify[-1].proto=tcp
                    uci set qos.@classify[-1].dstports='3724,6112,6881:6999'
                    uci set qos.@classify[-1].comment="$serviceName"
                    ;;
                "sc") # Supreme Commander
                    uci add qos classify
                    uci set qos.@classify[-1].target=$qosTarget
                    uci set qos.@classify[-1].proto=udp
                    uci set qos.@classify[-1].dstports='6112,9103,30340,30341'
                    uci set qos.@classify[-1].comment="$serviceName"
                    ;;
                "tq") # Titan Quest: Immortal Throne
                    uci add qos classify
                    uci set qos.@classify[-1].target=$qosTarget
                    uci set qos.@classify[-1].proto=tcp
                    uci set qos.@classify[-1].dstports='42800,49152:49172,49272:49292'
                    uci set qos.@classify[-1].comment="$serviceName"
                    uci add qos classify
                    uci set qos.@classify[-1].target=$qosTarget
                    uci set qos.@classify[-1].proto=udp
                    uci set qos.@classify[-1].dstports='42800,49152:49172,48272:49292'
                    uci set qos.@classify[-1].comment="$serviceName"
                    ;;
                "b2142") # Battlefield 2142
                    uci add qos classify
                    uci set qos.@classify[-1].target=$qosTarget
                    uci set qos.@classify[-1].proto=tcp
                    uci set qos.@classify[-1].dstports='18000,18300,4711,17475,18510,27900,28910,1024:1124,29900,29901'
                    uci set qos.@classify[-1].comment="$serviceName"
                    uci add qos classify
                    uci set qos.@classify[-1].target=$qosTarget
                    uci set qos.@classify[-1].proto=udp
                    uci set qos.@classify[-1].dstports='18000,18300,16567,29900,1024:1124,1500:4900,27900:27901,55123:55125'
                    uci set qos.@classify[-1].comment="$serviceName"
                    ;;
                "hl2eo") # Half-Life 2: Episode One
                    uci add qos classify
                    uci set qos.@classify[-1].target=$qosTarget
                    uci set qos.@classify[-1].proto=tcp
                    uci set qos.@classify[-1].dstports='6003,7002'
                    uci set qos.@classify[-1].comment="$serviceName"
                    uci add qos classify
                    uci set qos.@classify[-1].target=$qosTarget
                    uci set qos.@classify[-1].proto=udp
                    uci set qos.@classify[-1].dstports='27005,27015,27010,27011'
                    uci set qos.@classify[-1].comment="$serviceName"
                    ;;
                "hom") # Heroes of Might & Magic V
                    uci add qos classify
                    uci set qos.@classify[-1].target=$qosTarget
                    uci set qos.@classify[-1].proto=tcp
                    uci set qos.@classify[-1].dstports='6668,40000:42999'
                    uci set qos.@classify[-1].comment="$serviceName"
                    uci add qos classify
                    uci set qos.@classify[-1].target=$qosTarget
                    uci set qos.@classify[-1].proto=udp
                    uci set qos.@classify[-1].dstports='44000,45000,42500,8888,8889'
                    uci set qos.@classify[-1].comment="$serviceName"
                    ;;
                "gwf") # Guild Wars Factions 1 and 2
                    uci add qos classify
                    uci set qos.@classify[-1].target=$qosTarget
                    uci set qos.@classify[-1].proto=tcp
                    uci set qos.@classify[-1].dstports='6112'
                    uci set qos.@classify[-1].comment="$serviceName"
                    uci add qos classify
                    uci set qos.@classify[-1].target=$qosTarget
                    uci set qos.@classify[-1].proto=udp
                    uci set qos.@classify[-1].dstports='6112'
                    uci set qos.@classify[-1].comment="$serviceName"
                    ;;
                *)
                    for cnt in 1 2 3; do
                        proto=$(eval echo \$serviceProto$cnt)
                        portStart=$(eval echo \$servicePortStart$cnt)
                        portEnd=$(eval echo \$servicePortEnd$cnt)
                        if [ "$proto" = "1" -o "$proto" = "3" ]; then #tcp, both
                            uci add qos classify
                            uci set qos.@classify[-1].target=$qosTarget
                            uci set qos.@classify[-1].proto=tcp
                            if [ "$portStart" = "$portEnd" ]; then
                                uci set qos.@classify[-1].dstports="$portStart"
                            else
                                uci set qos.@classify[-1].dstports="$portStart:$portEnd"
                            fi
                            uci set qos.@classify[-1].comment="$serviceName"
                        fi
                        if [ "$proto" = "2" -o "$proto" = "3" ]; then #udp, both
                            uci add qos classify
                            uci set qos.@classify[-1].target=$qosTarget
                            uci set qos.@classify[-1].proto=udp
                            if [ "$portStart" = "$portEnd" ]; then
                                uci set qos.@classify[-1].dstports="$portStart"
                            else
                                uci set qos.@classify[-1].dstports="$portStart:$portEnd"
                            fi
                            uci set qos.@classify[-1].comment="$serviceName"
                        fi
                    done
                    ;;
            esac
        elif [ "$category" = "2" ]; then    # mac address
            deviceIp="$(cat /proc/net/arp | grep -i $deviceMac | cut -d' ' -f 1)"
            log_info "qos" "add mac address: $deviceMac ($deviceIp)"
            uci add qos classify
            uci set qos.@classify[-1].target=$qosTarget
            uci set qos.@classify[-1].srchost="$deviceIp"
            uci set qos.@classify[-1].comment="$deviceMac"

        elif [ "$category" = "3" ]; then    # voice device
            deviceIp="$(cat /proc/net/arp | grep -i $deviceMac | cut -d' ' -f 1)"
            log_info "qos" "add voice device: $deviceMac ($deviceIp)"
            uci add qos classify
            uci set qos.@classify[-1].target=$qosTarget
            uci set qos.@classify[-1].srchost="$deviceIp"
            uci set qos.@classify[-1].comment="$deviceMac"
        fi

        let Index=$Index+1
        json_select ".."
    done
}

qos_obj2uci() {
    json_load "$(objReq qos json)"
    json_select "QosP"
    json_get_vars enable wanRateMode wanRateUnitType wanRateKbps wanRateMbps


    if [ "$enable" = "0" ]; then
        log_info "qos" "disabled"
        uci set qos.wan.enabled='0'
        uci commit qos
        exit 0
    fi

    if [ "$wanRateMode" = "1" ]; then
        log_info "qos" "manual setup mode, wanRateUnitType:$wanRateUnitType, wanRateKbps:$wanRateKbps, wanRateMbps:$wanRateMbps"
        uci set qos.wan.enabled='1'
        uci set qos.wan.download=''

        if [ "$wanRateUnitType" = "0" ]; then
            uci set qos.wan.upload="$wanRateKbps"
        elif [ "$wanRateUnitType" = "1" ]; then
            uci set qos.wan.upload="$(($wanRateMbps * 1024))"
        fi
    else
        log_info "qos" "auto setup mode"
        uci set qos.wan.enabled='0'
        uci set qos.wan.download=''
        uci set qos.wan.upload='512' # default 512 kbps
        # detect upload speed
        qos_speedtest.sh &
    fi



    flush_classify_rules
    setup_classify_rules
    uci commit qos
}

qos_start() {
    qos_obj2uci
    qos-start
}

qos_stop() {
    qos-stop
}
