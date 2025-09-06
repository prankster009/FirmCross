#!/bin/sh

. /usr/share/libubox/jshn.sh

system_obj2uci() {
    json_load "$(objReq lan json)"
    json_select LanP
    json_get_vars routername

    MFG_MODE=$(gcontrol uenv get ManufactureMode | awk -F"=" '{print $2}')
    [ $MFG_MODE = "1" ] && {
	    hostname="MFG"
    }
    [ $MFG_MODE = "2" ] && {
	    hostname="Golden_MFG"
    }
    uci set system.@system[0].hostname="$routername"

    json_load "$(objReq system json)"
    json_select "SystemP"
    json_get_vars debug
    json_select ".."
    if [ "$debug" = "1" ]; then
        uci set system.@system[0].conloglevel='8'
    else
        uci set system.@system[0].conloglevel='4'
    fi

    uci commit system
}
