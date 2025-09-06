if [ $# -ne "6" ]
then
	echo "usage: JDM.sh [S/N] [MAC_addr] [Manufacture date] [cert_region] [WiFi pwd] [WPS pin]"
	exit
fi
file_sn=$(echo $1 | cut -c10-14)
file_name="JDM_"$file_sn

if [ -f "$file_name" ]
then
	rm $file_name
fi

touch $file_name

mfg_data_version="1"
echo "mfg_data_version="$mfg_data_version >> $file_name

modelNumber="E5600"
echo "modelNumber="$modelNumber >> $file_name

echo "serial_number="$1 >> $file_name

hw_mac_addr=$2
echo "hw_mac_addr="$hw_mac_addr >> $file_name

#wps_device_pin=$(head /dev/urandom | tr -dc 0-9 | head -c 8)
wps_device_pin=$6
echo "wps_device_pin="$wps_device_pin >> $file_name

uuid_key=$(cat /proc/sys/kernel/random/uuid)
echo "uuid_key="$uuid_key >> $file_name

hw_version="V00"
echo "hw_version="$hw_version >> $file_name

manufacturer_date=$3
echo "manufacturer_date="$manufacturer_date >> $file_name

hw_revision="0"
echo "hw_revision="$hw_revision >> $file_name

tc_ssid=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 32)
echo "tc_ssid="$tc_ssid >> $file_name

#tc_passphrase=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 63)
tc_passphrase="$(echo $5 | sed s/1/L/g | sed s/0/O/g)$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 53)"
tc_passphrase="$(echo ${tc_passphrase:0:3} | tr '[:lower:]' '[:upper:]')${tc_passphrase:3}"
echo "tc_passphrase="$tc_passphrase >> $file_name

cert_region=$4
echo "cert_region="$cert_region >> $file_name

MUC=$(echo $1 | cut -c10-14)
echo "default_ssid=Linksys"$MUC >> $file_name

#default_passphrase=$(echo $tc_passphrase | cut -c1-10 | sed s/L/1/g | sed s/O/0/g | tr '[:upper:]' '[:lower:]' )
default_passphrase=$5
echo "default_passphrase="$default_passphrase >> $file_name

echo "admin1_passphrase="$default_passphrase >> $file_name

echo "admin2_passphrase="$default_passphrase >> $file_name

echo "manufacturer=Linksys LLC" >> $file_name

echo "manufacturerURL=http://www.linksys.com" >> $file_name

modelDescription="Simultaneous Dual-Band Wireless-AC Gigabit Router"
echo "modelDescription="$modelDescription >> $file_name

deviceType="urn:home-linksys-com:device:Router:1"
echo "deviceType="$deviceType >> $file_name

