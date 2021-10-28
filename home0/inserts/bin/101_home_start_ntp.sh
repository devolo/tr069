#!/bin/sh

# Accept connections to the NTP server
iptables -I INPUT 1 -p udp --dport 123  -j ACCEPT

# Start NTP server
/etc/init.d/ntp start
