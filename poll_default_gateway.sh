#!/bin/sh

DEFAULT_GATEWAY_TO_REMOVE=${1}

while true; do
    sudo ip route del default via "${DEFAULT_GATEWAY_TO_REMOVE}" 1>/dev/null 2>/dev/null
    sleep 1;
done
