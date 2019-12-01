#!/bin/sh

LOCAL_IP_ADDRESSES=$(ip add show ${LOCAL_INTERFACE} | grep inet | awk '{ print $2 }')
LOCAL_IP_ADDRESS=$(echo ${LOCAL_IP_ADDRESSES} | awk -F/ '{ print $1 }')
LOCAL_IP_ADDRESS_STUB=$(echo ${LOCAL_IP_ADDRESS} | awk -F. '{ print $1"."$2"."$3 }')

iptables -A INPUT -i ${LOCAL_INTERFACE}  -p tcp -m multiport --dport 53,953 -j ACCEPT
iptables -A INPUT -i ${LOCAL_INTERFACE}  -p udp              --dport 53     -j ACCEPT

mylogger "Firewall DNS set up done!"
