#!/bin/sh

HOSTNAME=$(hostname)

if [ -z "${KEEP_SERVICE_RUNNING}" ]; then
    mylogger "Let \"${HOSTNAME}\" go down..."
else
    mylogger "Catching \"${HOSTNAME}\"..."
    /bin/bash
fi
