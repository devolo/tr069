#!/bin/sh

INTERFACE_TO_SNIFF=${1}
NETWORK=${2}

while true; do
	WINDOW_AVAILABLE=$(xdotool search --name "${INTERFACE_TO_SNIFF}" | wc -l)
	if [ "${WINDOW_AVAILABLE}" -gt 0 ]; then
	    xdotool search --name "${INTERFACE_TO_SNIFF}" set_window --name "Capturing from TR-069 simulation network: ${NETWORK}"
	else
	    sleep 1;
	fi
done
