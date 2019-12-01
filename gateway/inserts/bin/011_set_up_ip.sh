#!/bin/sh

ORIGINAL_LOCAL_IP_ADDRESS=$(try_up_to_n_times "ip add show ${LOCAL_INTERFACE} | grep inet | awk '{ print \$2 }'")

mylogger "Removing ${ORIGINAL_LOCAL_IP_ADDRESS} ..."
sudo ip addr del ${ORIGINAL_LOCAL_IP_ADDRESS} dev ${LOCAL_INTERFACE}

mylogger "Using ${IP_ADDRES_BYTE_TO_SERVE} as byte in 192.168.X.${OWN_IP_ADDRES_BYTE} ... !"

mylogger "Adding IP 192.168.${IP_ADDRES_BYTE_TO_SERVE}.${OWN_IP_ADDRES_BYTE} to ${LOCAL_INTERFACE} ..."
LOCAL_IP_ADDRESS="192.168.${IP_ADDRES_BYTE_TO_SERVE}.${OWN_IP_ADDRES_BYTE}"
sudo ip addr add "${LOCAL_IP_ADDRESS}" dev ${LOCAL_INTERFACE}
write_etc_hosts
mylogger "Adding route 192.168.${IP_ADDRES_BYTE_TO_SERVE}.0/24 to ${LOCAL_INTERFACE} ..."
sudo ip route add "192.168.${IP_ADDRES_BYTE_TO_SERVE}.0/24" dev ${LOCAL_INTERFACE}
