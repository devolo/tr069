#!/bin/bash
#runs the connection request udp package generator

#check for root
if [ "$(id -u)" != "0" ]; then
	echo "Sorry, you are not root."
	exit 1
fi

IP=${1}
PORT=${2}

#check for 2 parameters
if [ "$#" -ne 2 ]; then
	echo "Illegal number of parameters"
	echo "Usage: sudo ./stun-con-req.sh ip port"
	echo "i.e.: sudo ./stun-con-req.sh 192.168.140.62 7547"
	echo
	echo "Guessing values ..."
	UDP_CONNECTION_REQUEST_ADDRESS=$(cat /opt/jboss/server/default/log/server.log | grep UDPConnectionRequestAddress | tail -1 | awk -F= '{ print $2 }')
	IP=$(echo ${UDP_CONNECTION_REQUEST_ADDRESS}|awk -F: '{ print $1 }')
	PORT=$(echo ${UDP_CONNECTION_REQUEST_ADDRESS}|awk -F: '{ print $2 }')
	echo "Using IP:${IP} PORT:${PORT}"
fi

echo "***********************"
echo "* running udp-con-req * "
echo "***********************"
python helper-stun-con-req.py ${IP} ${PORT}
