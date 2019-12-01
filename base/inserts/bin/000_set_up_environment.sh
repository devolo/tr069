#!/bin/sh

try_up_to_n_times ()
{
    local RESULT=""
    local COMMAND="${1}"
    local TRIES=${2:-60}
    while [ -z "${RESULT}" ]; do
	RESULT=$(sh -c "${COMMAND}")
	if [ -z "${RESULT}" ]; then
	    sleep 1;
	    TRIES=$((${TRIES}-1))
	    if [ ${TRIES} -lt 1 ]; then
		break;
	    fi
	fi
    done
    echo "${RESULT}"
}

write_etc_hosts ()
{
    HOSTNAME=$(hostname)
    NEW_FILE=/tmp/hosts
    echo "127.0.0.1	localhost" > ${NEW_FILE}
    echo "::1		localhost ip6-localhost ip6-loopback" >> ${NEW_FILE}
    echo "fe00::0	ip6-localnet" >> ${NEW_FILE}
    echo "ff00::0	ip6-mcastprefix" >> ${NEW_FILE}
    echo "ff02::1	ip6-allnodes" >> ${NEW_FILE}
    echo "ff02::2	ip6-allrouters" >> ${NEW_FILE}
    echo "${LOCAL_IP_ADDRESS}	${HOSTNAME}" >> ${NEW_FILE}
    cat /tmp/replace_with_file | sed "s#FILE#${NEW_FILE}#" > /tmp/replace_with_file_to_use_here
    vi -s /tmp/replace_with_file_to_use_here /etc/hosts > /dev/null 2>&1
    rm /tmp/replace_with_file_to_use_here
    rm ${NEW_FILE}
}

wait_until_available() {
    local SERVER=${1}
    while true; do
	mylogger "Testing ${SERVER} ..."
	ping -c 1 ${SERVER}
	if [ "${?}" = "0" ]; then
	    mylogger "${SERVER} ok!"
	    break;
	else
	    sleep 1;
	fi
    done
}

ORIGINAL_HOSTNAME=$(hostname)
LOCAL_INTERFACE=eth0
LOCAL_IP_ADDRESS=$(try_up_to_n_times "ip addr show ${LOCAL_INTERFACE} | grep inet | awk '{ print \$2 }'| awk -F/ '{ print \$1 }'")

if [ "${DOMAIN_TO_SERVE}" != "" ]; then
    echo ${DOMAIN_TO_SERVE}>/tmp/domain.name
fi

mylogger "LOCAL_IP_ADDRESS=${LOCAL_IP_ADDRESS}"
