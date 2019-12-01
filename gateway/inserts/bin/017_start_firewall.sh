#!/bin/sh

LOCAL_IP_ADDRESSES=$(ip add show ${LOCAL_INTERFACE} | grep inet | awk '{ print $2 }')
LOCAL_IP_ADDRESS=$(echo ${LOCAL_IP_ADDRESSES} | awk -F/ '{ print $1 }')
INTERNET_IP_ADDRESS=$(ip addr show ${INTERNET_INTERFACE} | grep inet | awk '{ print $2 }'| awk -F/ '{ print $1 }')

# firewall
iptables -F
iptables -P FORWARD DROP
iptables -P INPUT   DROP
iptables -P OUTPUT  ACCEPT
iptables -t nat -I POSTROUTING -o ${INTERNET_INTERFACE} -j SNAT --to-source ${INTERNET_IP_ADDRESS}
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -i ${LOCAL_INTERFACE} -s ${INTERNET_IP_ADDRESS} -j ACCEPT
iptables -A INPUT -i ${INTERNET_INTERFACE} -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -i ${LOCAL_INTERFACE} -s ${LOCAL_IP_ADDRESSES} -j ACCEPT
iptables -A FORWARD -i ${INTERNET_INTERFACE} -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -s 127.0.0.0/8 -d 127.0.0.0/8 -i lo -j ACCEPT
iptables -A INPUT  -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT
iptables -A INPUT   -m conntrack --ctstate INVALID -j DROP
iptables -A OUTPUT  -m conntrack --ctstate INVALID -j DROP
iptables -A FORWARD -m conntrack --ctstate INVALID -j DROP

# engage
sudo echo 1 > /proc/sys/net/ipv4/conf/${LOCAL_INTERFACE}/proxy_arp
sudo echo 1 > /proc/sys/net/ipv4/ip_forward

## allow ICMP for debugging
iptables -A INPUT -p icmp --icmp-type echo-request -j ACCEPT
iptables -A OUTPUT -p icmp --icmp-type echo-reply -j ACCEPT

mylogger "LOCAL_IP_ADDRESS=${LOCAL_IP_ADDRESS}"

mylogger "Firewall set up!"
