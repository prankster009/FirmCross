#!/bin/sh
. /usr/share/libubox/jshn.sh

log() {
	echo "[Language] $@" > /dev/console
}

json_load "$(objReq system json)"
json_select SystemP
json_get_var WIZARD_STATUS doneWizard
json_get_var LANG_CONFIG language
log "Update config $LANG_CONFIG $WIZARD_STATUS"

FILEPATH="/www/json/guest-data.json"

if [ "$WIZARD_STATUS" = "1" ]; then
	WIZARD_STATUS="done"
	if [ -f /www/quicksetup -o -f /www/wizard.html -o -f /www/cgi-bin/al.cgi ]; then
		log "Wizard finish"
		rm -f /www/quicksetup /www/wizard.html /www/cgi-bin/al.cgi
		rcConf restart firewall
	fi
else
	WIZARD_STATUS=""
fi

json_load "$(cat $FILEPATH)"
json_get_var FILE_LANG lang
json_get_var FILE_SETUP setup
if [ "$FILE_LANG" = "$LANG_CONFIG" -a "$FILE_SETUP" = "$WIZARD_STATUS" ]; then
	log "Do not change lang $FILE_LANG"
else
	log "Change lang to $LANG_CONFIG"
	echo "{" > $FILEPATH
	echo "\"lang\":\"$LANG_CONFIG\"," >> $FILEPATH
	echo "\"setup\":\"$WIZARD_STATUS\"" >> $FILEPATH
	echo "}" >> $FILEPATH
fi
