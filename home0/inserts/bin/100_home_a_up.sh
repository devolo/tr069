#!/bin/sh

# Setup miniupnpd
# Accept SSDP used to discover the UPNP IGD server
iptables -I INPUT 1 -p udp --dport 1900 -j ACCEPT
# Accept connections to the UPNP IGD server
iptables -I INPUT 1 -p tcp --dport 6000 -j ACCEPT
# Accept connections to the TFTP server
iptables -I INPUT 1 -p udp --dport 69   -j ACCEPT
# Allow forwarding from local interface to external interface
sed -i "s/LOCAL_INTERFACE/${LOCAL_INTERFACE}/g" /etc/default/miniupnpd
sed -i "s/INTERNET_INTERFACE/${INTERNET_INTERFACE}/g" /etc/default/miniupnpd
sed -i "s/INTERNET_INTERFACE/${INTERNET_INTERFACE}/g" /etc/miniupnpd/iptables_init.sh
/etc/miniupnpd/iptables_init.sh
/usr/sbin/miniupnpd -i ${INTERNET_INTERFACE} -a ${LOCAL_IP_ADDRESS} -N -p 6000 -A "allow 7000-9000 0.0.0.0/24 7000-9000" &

service tftpd-hpa restart
mylogger "TFTP set up!"

# Allow forwarding from local interface to external interface
iptables -A FORWARD -i ${LOCAL_INTERFACE} -o ${INTERNET_INTERFACE} -j ACCEPT
