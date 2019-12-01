#!/bin/sh

ORIGINAL_INTERNET_ADDRESS=$(ip add show ${INTERNET_INTERFACE} | grep inet | awk '{ print $2 }')

mylogger "Removing ${ORIGINAL_INTERNET_ADDRESS} ..."
sudo ip addr del ${ORIGINAL_INTERNET_ADDRESS} dev ${INTERNET_INTERFACE}

sudo dhclient -v -4 -i ${INTERNET_INTERFACE}

LEASE_FOUND=$(cat /var/lib/dhcp/dhclient.leases | grep ${INTERNET_INTERFACE})

if [ "${LEASE_FOUND}" != "" ]; then
    INTERNET_IP_ADDRESS=$(try_up_to_n_times "ip addr show ${INTERNET_INTERFACE} | grep inet | awk '{ print \$2 }'| awk -F/ '{ print \$1 }'")
    write_etc_hosts
    mylogger "DHCP configuration sucessfully finished, got a default GW. INTERNET_IP_ADDRESS is now ${INTERNET_IP_ADDRESS}"
else
    killall -9 dhclient
    mylogger "Restoring ${ORIGINAL_INTERNET_ADDRESS} ..."
    sudo ip addr add ${ORIGINAL_INTERNET_ADDRESS} dev ${INTERNET_INTERFACE}

    if [ ! -z "${UPSTREAM_GATEWAY_NAME}" ]; then
	mylogger "Setup default route to ${UPSTREAM_GATEWAY_NAME}..."
	sudo ip route del default
	UPSTREAM_IP=$(try_up_to_n_times "dig +noall +answer ${UPSTREAM_GATEWAY_NAME} | awk '{ print \$5 }'")
	mylogger "Found ${UPSTREAM_IP} ..."
	sudo ip route add default via ${UPSTREAM_IP}
    fi
fi
