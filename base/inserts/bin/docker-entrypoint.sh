#!/bin/sh

#set -x

mylogger() {
    DATE=$(date +%X)
    # print to stdout for docker log handling
    echo "${DATE} ${*}"
    # use syslog
    logger -- "${*}"
}

process_init_file() {
	local f="$1"; shift

	case "$f" in
		*docker-entrypoint.sh) mylogger "$0: ignoring $f to avoid recursion" ;;
		*.sh)                  mylogger "$0: sourcing and executing $f"; . "$f" ;;
		*)                     mylogger "$0: ignoring $f" ;;
	esac
	mylogger "------------------------------"
}

HOSTNAME=$(hostname)
RSYSLOG_ROLE="undefined"
case "${HOSTNAME}" in
    *rsyslog*)
	# rsyslog_server, configuration is already setup in rsyslog.conf
	RSYSLOG_ROLE="server"
    ;;
    *)
	# rsyslog_client, use default rsyslog_server
	RSYSLOG_ROLE="client"
    ;;
esac
sudo service rsyslog start

mylogger "Started rsyslog @${HOSTNAME} as ${RSYSLOG_ROLE} ..."

mylogger "Container Versions:\n $(cat /etc/container-version)"

FILES_TO_SOURCE=$(echo /docker-entrypoint.d/* | sort)

mylogger "Will source ${FILES_TO_SOURCE} ..."

for f in ${FILES_TO_SOURCE}; do
    process_init_file "$f"
done

mylogger "${0} finished!"
mylogger "------------------------------"
