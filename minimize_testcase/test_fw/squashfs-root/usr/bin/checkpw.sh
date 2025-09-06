#!/bin/sh

. /usr/share/libubox/jshn.sh


json_load "$(objReq account json)"
json_select "AccountT"

local Index="1" oldpw newpw
while json_get_type Type $Index && [ "$Type" = object ]; do
	json_select "$Index"
	json_get_vars name username password

	if [ $name = "mesh" ]; then
		newpw=`echo -n "$oldpw" | openssl dgst -sha256 | cut -d ' ' -f 2`
		if [ -z $password ]; then
			echo "Update empty account..."
			objReq account setparam "mesh" password $newpw
			gnvram commit
		else
			[ $newpw = $password ] || {
				echo "account change..."
				json_load "$(objReq easyMeshBasic json)"
				json_select EasyMeshBasicP
				json_get_vars enable deviceRole
				json_select ".."
				[ "$deviceRole" = "2" -a $enable = "1" ] || {
					echo "Update account..."
					objReq account setparam "mesh" password $newpw
					gnvram commit
				}
			}
		fi
	else
		oldpw=$password
	fi

	let Index=$Index+1
	json_select ".."
done

