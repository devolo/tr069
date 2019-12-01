#!/bin/sh

# Allow forwarding from local interface to external interface
iptables -A FORWARD -i ${LOCAL_INTERFACE} -o ${INTERNET_INTERFACE} -j ACCEPT

mylogger "${HOSTNAME} up"
