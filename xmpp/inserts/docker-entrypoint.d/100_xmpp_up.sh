#!/bin/sh

chown -R prosody:prosody /var/lib/prosody
/etc/init.d/prosody restart
mylogger "${HOSTNAME} up"
