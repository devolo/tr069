#!/bin/sh

## to be able to execute fw updates, genieacs must be pointed to the gateway which is reachable by the DUT; add ".public" by convention
GW_NAME_TO_USE="${GW_NAME}.public"
sed -i "s/LOCAL_GATEWAY/${GW_NAME_TO_USE}/g" /opt/genieacs/dist/config/config.json
mylogger "Set LOCAL_GATEWAY to \"${GW_NAME_TO_USE}\"..."
mongod &
sleep 10
(cd /opt/genieacs/dist/; node tools/configure-ui)
/usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
