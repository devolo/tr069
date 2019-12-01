#!/bin/sh

chown -R mysql:mysql /var/lib/mysql
sudo sed -i "s/bind-address/#bind-address/g" /etc/mysql/mysql.conf.d/mysqld.cnf
/etc/init.d/mysql start
mysql -u root -p"password" < /tmp/access.db
mylogger "Granting privileges done, result:$?"

mylogger "${HOSTNAME} up"
