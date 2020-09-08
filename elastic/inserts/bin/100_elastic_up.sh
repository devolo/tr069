#!/bin/sh

/etc/init.d/elasticsearch start
/etc/init.d/kibana start

mylogger "check for elasticsearch ..."
try_up_to_n_times "curl -XGET 'localhost:9200'"
mylogger "elasticsearch running ..."

python3 /opt/admin/mqttToElasticSearch.py --index=tr069-delos-munin --broker-name=mqttbroker.public --broker-port=1883 --elastic-name=localhost --elastic-port=9200 --channel="#" &
python3 /opt/admin/elasticsearch-HQ/application.py &

mylogger "elastic up!"
