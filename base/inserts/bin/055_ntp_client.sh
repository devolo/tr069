#!/bin/sh

rm /etc/localtime
ln -s /usr/share/zoneinfo/Europe/Berlin /etc/localtime
ntpdate de.pool.ntp.org
