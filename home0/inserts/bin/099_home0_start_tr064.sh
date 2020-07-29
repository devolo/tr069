#!/bin/sh

# make mockserver run on IPv4
sed -i 's/listen(port/listen(port, "0.0.0.0"/g' /usr/local/lib/node_modules/mockserver/bin/mockserver.js

# start TR-064 moc server
python3 /opt/mockserver_handler.py --log=/opt/mock.log

# replace home with local IP address to announce where TR-064 will be reachable
sed -i "s/127.0.0.1/${LOCAL_IP_ADDRESS}/g" /opt/ssdp_mock.py

# Accept connections to the TR-064 mock server
iptables -I INPUT 1 -p tcp --dport 49000 -j ACCEPT

# start to declare TR-064
python3 /opt/ssdp_handler.py --log=/opt/ssdp.log

mylogger "TR-064 set up!"
