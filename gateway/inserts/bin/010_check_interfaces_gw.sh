#!/bin/sh

# helper function
redirect() {
    local PORT=${1}
    local PROTOCOL=${2}
    local INTERFACE=${3}
    local IP=${4}
    local DPORT=${5}

    iptables -A INPUT -i ${INTERFACE} -p ${PROTOCOL} --dport ${PORT} -j ACCEPT
    iptables -A FORWARD -i ${INTERFACE} -p ${PROTOCOL} --dport ${PORT} -d ${IP} -j ACCEPT
    iptables -A FORWARD -p ${PROTOCOL} --sport ${PORT} -s ${IP} -j ACCEPT
    iptables -t nat -A PREROUTING -i ${INTERFACE} -p ${PROTOCOL} --dport ${PORT} -j DNAT --to-destination ${IP}:${DPORT}
    mylogger "Fowarding ${PORT}/${PROTOCOL} from ${INTERFACE} to ${IP}:${PORT} ..."
}

INTERNET_INTERFACE_FOUND=$(ip add show eth0 | grep inet | awk '{ print $2 }'| awk -F/ '{ print $1 }' | xargs dig +noall +answer -x | grep ${UPSTREAM_NETWORK_NAME})

if [ "${INTERNET_INTERFACE_FOUND}" = "" ]; then
    LOCAL_INTERFACE=eth0
    INTERNET_INTERFACE=eth1
else
    LOCAL_INTERFACE=eth1
    INTERNET_INTERFACE=eth0
fi

mylogger  "LOCAL_INTERFACE=${LOCAL_INTERFACE}"
mylogger  "INTERNET_INTERFACE=${INTERNET_INTERFACE}"
