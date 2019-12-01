#!/bin/sh

DBHOST=acsdb

wait_until_available ${DBHOST}

chown -R mysql:mysql /var/lib/mysql
/etc/init.d/mysql start

# wait for mysql ready on ${DBHOST}
RESULT="1"
while [ "${RESULT}" != "0" ]; do
    sleep 1;
    mysql -h ${DBHOST} -u root -p"password" -e "SHOW DATABASES;"
    RESULT=$?
    mylogger "CHECKING DBs DONE, result:${RESULT}..."
done

DB_INITIALIZED=$(mysql -h ${DBHOST} -u root -p"password" -e "USE ACS; SHOW TABLES;")

if [ "${DB_INITIALIZED}" = "" ]; then
    mylogger "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    mylogger "!Will init default ACS databases ... you lost your scripts!"
    mylogger "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    RESULT="1"
    while [ "${RESULT}" != "0" ]; do
	sleep 1;
	mysql -h ${DBHOST} -u root -p"password" < /tmp/openACS.db
	RESULT=$?
	mylogger "INIT ACS DB DONE, result:${RESULT}..."
    done
else
    mylogger "Using existing databases ..."
fi

mylogger "Starting application server..."
/opt/jboss/bin/run.sh -b 0.0.0.0
