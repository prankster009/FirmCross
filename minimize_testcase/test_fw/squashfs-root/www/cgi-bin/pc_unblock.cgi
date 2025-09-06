#!/bin/sh
#
# This CGI provide APP to get itself MAC address
# http://192.168.1.1?mac=11:22:33:44:55:66

. /usr/share/libubox/jshn.sh

PC_UNBLOCK_FILE="/tmp/pc_unblock"
MESSAGE=

MAC=$(echo $QUERY_STRING | grep "mac" | cut -d'&' -f 1 | cut -d'=' -f 2)
PWD=$(echo $QUERY_STRING | grep "pwd" | cut -d'&' -f 2 | cut -d'=' -f 2)

if [ -z "$MAC" -o -z "$PWD" ]; then
    MESSAGE="Failure"
else
    PC_PWD=$(objReq pc show | grep setupPasswd | cut -c 29-)
    if [ -n "$PC_PWD" -a "$PC_PWD" = "$PWD" ]; then
        MESSAGE="Success"
    else
        MESSAGE="Failure"
    fi
fi

echo "Content-type: application/json"
echo ""

echo "{\"status\":{\"message\":\"$MESSAGE\"}}"

if [ "$MESSAGE" = "Success" ]; then
    # Remove the old setting
    grep -q "$MAC" $PC_UNBLOCK_FILE
    RET="$?"
    if [ "$RET" = "0" ]; then
        JOB_ID=$(grep "$MAC" $PC_UNBLOCK_FILE | awk '{print $1}')
        atrm $JOB_ID
        sed -i "/$MAC/d" $PC_UNBLOCK_FILE
    fi

    # Find the obj index
    json_load "$(objReq pcPolicy json)"
    json_select "PcPolicyT"
    Index="1"
    BLOCK_TYPE="0"
    while json_get_type Type $Index && [ "$Type" = object ]; do
        json_select "$Index"
        json_get_vars targetMac blockType

        if [ "$targetMac" == "$MAC" ]; then
            BLOCK_TYPE="$blockType"
            break
        fi
        let Index=$Index+1
        json_select ".."
    done

    # Add the new setting
    at now + 15 minutes << EOF
sed -i "/$MAC/d" $PC_UNBLOCK_FILE
rcConf restart firewall
rcConf run
EOF

    JOB_ID=$(at -l | head -n 1 | awk '{print $1}')
    echo "$JOB_ID $MAC $BLOCK_TYPE" >> $PC_UNBLOCK_FILE

    rcConf restart firewall
    rcConf run
fi

exit 0
