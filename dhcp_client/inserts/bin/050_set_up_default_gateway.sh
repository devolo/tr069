#!/bin/sh

## docker uses ORIGINAL_LOCAL_IP_ADDRESS ...
ORIGINAL_LOCAL_IP_ADDRESS=$(try_up_to_n_times "ip add show ${LOCAL_INTERFACE} | grep inet | awk '{ print \$2 }'| awk -F/ '{ print \$1 }' ")

## docker uses NETWORK_FULL_NAME ...
NETWORK_FULL_NAME=$(try_up_to_n_times "dig +noall +answer -x ${ORIGINAL_LOCAL_IP_ADDRESS} | awk '{ print \$5 }' | awk -F. '{ print \$2 }'")
mylogger "Found NETWORK_FULL_NAME=\"${NETWORK_FULL_NAME}\""

## GW_NAME is the name of the network in docker-compose.yml and by convention the gate name...
GW_NAME=${NETWORK_FULL_NAME#*_}
mylogger "GW_NAME=${GW_NAME}"

## cut off docker networking ...
mylogger "Removing ${ORIGINAL_LOCAL_IP_ADDRESS} from ${LOCAL_INTERFACE} ..."
sudo ip addr del ${ORIGINAL_LOCAL_IP_ADDRESS} dev ${LOCAL_INTERFACE}

## try DHCP ...
OLD_VERSION_USED=$(cat /etc/issue | grep 12)
if [ "${OLD_VERSION_USED}" = "" ]; then
    sudo dhclient -v -4 -i ${LOCAL_INTERFACE}
else
    sudo dhclient -v -4 ${LOCAL_INTERFACE}
fi
LEASE_FOUND=$(cat /var/lib/dhcp/dhclient.leases | grep ${LOCAL_INTERFACE})

if [ "${LEASE_FOUND}" != "" ]; then
    LOCAL_IP_ADDRESS=$(try_up_to_n_times "ip addr show ${LOCAL_INTERFACE} | grep inet | awk '{ print \$2 }'| awk -F/ '{ print \$1 }'")
    write_etc_hosts
    mylogger "DHCP configuration sucessfully finished, got a default GW. LOCAL_IP_ADDRESS is now ${LOCAL_IP_ADDRESS}"
else
    killall -9 dhclient
    mylogger "Restoring ${ORIGINAL_LOCAL_IP_ADDRESS} assigned by docker ..."
    sudo ip addr add ${ORIGINAL_LOCAL_IP_ADDRESS} dev ${LOCAL_INTERFACE}

    DEFAULT_ROUTE_AVAILABLE=$(ip route show | grep default)
    if [ "${DEFAULT_ROUTE_AVAILABLE}" != "" ]; then
	mylogger "Deleting old default route..."
	sudo ip route del default
    fi

    GW_IP=$(try_up_to_n_times "dig +noall +answer ${GW_NAME} | awk '{ print \$5 }'")
    mylogger "Found ${GW_IP} ..."
    sudo ip route add default via ${GW_IP}

    mylogger "Route set to ${GW_IP}!"
fi
