#!/bin/sh

# make mockserver run on IPv4
sed -i 's/listen(port/listen(port, "0.0.0.0"/g' /usr/local/lib/node_modules/mockserver/bin/mockserver.js

# Accept connections to the TR-064 mock server
iptables -I INPUT 1 -p tcp --dport 5438  -j ACCEPT
iptables -I INPUT 1 -p tcp --dport 37215 -j ACCEPT
iptables -I INPUT 1 -p tcp --dport 49000 -j ACCEPT
iptables -I INPUT 1 -p tcp --dport 49001 -j ACCEPT

# start TR-064 moc server
cd /opt
sudo ./create_mocks.sh --IP="${LOCAL_IP_ADDRESS}"

mylogger "TR-064 set up!"
