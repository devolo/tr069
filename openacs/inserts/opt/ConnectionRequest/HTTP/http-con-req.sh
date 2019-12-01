#!/bin/bash
#Does a http connection request to the specified URL using default connection request password Admin:devolo
#Does not need root

if [ "$#" -gt 3 ] || [ "$#" -lt 1 ]; then
	echo "Illegal number of arguments"
	echo "Example:  ./http-con-req.sh http://192.168.142.518:8085/1207a4257329a58cd06d3c1184171f81/Service_GateWay/ACS"
	echo "Default Username: Admin"
	echo "Default Password: devolo"
	exit 1
fi

URL=${1}
USERNAME=${2:-"Admin"}
USERPASS=${3:-"devolo"}

curl --output /dev/null  --verbose --digest --user $USERNAME:$USERPASS ${URL}


