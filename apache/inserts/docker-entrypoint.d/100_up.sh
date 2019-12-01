#!/bin/sh

/etc/init.d/apache2 start

chown -R www-data /var/www

mylogger "${HOSTNAME} up"
