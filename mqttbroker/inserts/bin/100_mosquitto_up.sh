#!/bin/sh

mosquitto &

mylogger "Use \'mosquitto_sub -d -t \"#\" -p 1883\' to subscribed to every topic ..."

mylogger "${HOSTNAME} up"
