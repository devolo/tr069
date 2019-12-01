#!/bin/bash

ls -la /etc/dhcp

cat /etc/dhcp/dhcpd.conf

MAX_LEASE_TIME="$((${DEFAULT_LEASE_TIME}*12))"

if [ "${MAX_LEASE_TIME}" -gt 2592000 ]; then
    mylogger "Max lease time too big for this setup (${MAX_LEASE_TIME}s)!"
    DEFAULT_LEASE_TIME=216000
    MAX_LEASE_TIME=2592000
    mylogger "Max lease time: ${MAX_LEASE_TIME}s"
    mylogger "Lease time: ${DEFAULT_LEASE_TIME}s"
fi

mylogger "Use DHCP option 125 workaround for buggy clients: ${USE_OPTION_125_WORKAROUND}"

if [ "${USE_OPTION_125_WORKAROUND}" = "NO" -o "${USE_OPTION_125_WORKAROUND}" = "no" -o "${USE_OPTION_125_WORKAROUND}" = "" ]; then
    USE_OPTION_125_WORKAROUND=""
else
    mylogger "Adding option 125 to option 55 of the clients request as workaround ..."
    USE_OPTION_125_WORKAROUND="option dhcp-parameter-request-list = concat(option dhcp-parameter-request-list,7d);"
fi

sed -i "s/OPTION_125_WORKAROUND/${USE_OPTION_125_WORKAROUND}/g" /etc/dhcp/dhcpd.conf

sed -i "s/THIS_BYTE/${IP_ADDRES_BYTE_TO_SERVE}/g" /etc/dhcp/dhcpd.conf
sed -i "s/THIS_DOMAIN/${DOMAIN_TO_SERVE}/g" /etc/dhcp/dhcpd.conf
sed -i "s/THIS_OWN/${OWN_IP_ADDRES_BYTE}/g" /etc/dhcp/dhcpd.conf
sed -i "s/THIS_LEASE_TIME/${DEFAULT_LEASE_TIME}/g" /etc/dhcp/dhcpd.conf
sed -i "s/THIS_MAX_LEASE_TIME/${MAX_LEASE_TIME}/g" /etc/dhcp/dhcpd.conf

sed -i "s/THIS_DOMAIN/${DOMAIN_TO_SERVE}/g" /etc/bind/db.192
HOSTNAME=$(hostname)
sed -i "s/THIS_HOSTNAME/${HOSTNAME}/g" /etc/bind/db.192

cp /etc/bind/db.THIS_DOMAIN /etc/bind/db.${DOMAIN_TO_SERVE}
sed -i "s/THIS_BYTE/${IP_ADDRES_BYTE_TO_SERVE}/g" /etc/bind/db.${DOMAIN_TO_SERVE}
sed -i "s/THIS_OWN/${OWN_IP_ADDRES_BYTE}/g" /etc/bind/db.${DOMAIN_TO_SERVE}
sed -i "s/THIS_DOMAIN/${DOMAIN_TO_SERVE}/g" /etc/bind/db.${DOMAIN_TO_SERVE}
sed -i "s/THIS_HOSTNAME/${HOSTNAME}/g" /etc/bind/db.${DOMAIN_TO_SERVE}

sed -i "s/THIS_BYTE/${IP_ADDRES_BYTE_TO_SERVE}/g" /etc/bind/named.conf
sed -i "s/THIS_OWN/${OWN_IP_ADDRES_BYTE}/g" /etc/bind/named.conf

sed -i "s/THIS_DOMAIN/${DOMAIN_TO_SERVE}/g" /etc/bind/named.conf.local
sed -i "s/THIS_BYTE/${IP_ADDRES_BYTE_TO_SERVE}/g" /etc/bind/named.conf.local

sed -i "s/THIS_BYTE/${IP_ADDRES_BYTE_TO_SERVE}/g" /etc/bind/named.conf.options
NAMESERVER_FROM_DHCP=$(cat /etc/resolv.conf | grep "#nameserver" | awk '{ print $2 }' | head -1)
if [ -z ${NAMESERVER_FROM_DHCP} ]; then
    # Verisign DNS is as good as 8.8.8.8
    NAMESERVER_FROM_DHCP="64.6.64.6"
fi
sed -i "s/FORWARING_NAMESERVER/${NAMESERVER_FROM_DHCP}/g" /etc/bind/named.conf.options

cat /etc/dhcp/dhcpd.conf

ROOT_PASSWORD=${ROOT_PASSWORD:-password}

BIND_DATA_DIR=${DATA_DIR}/bind
DHCP_DATA_DIR=${DATA_DIR}/dhcp

create_bind_data_dir() {
  mkdir -p ${BIND_DATA_DIR}

  # populate default bind configuration if it does not exist
  if [ ! -d ${BIND_DATA_DIR}/etc ]; then
    mv /etc/bind ${BIND_DATA_DIR}/etc
  fi
  rm -rf /etc/bind
  ln -sf ${BIND_DATA_DIR}/etc /etc/bind
  chmod -R 0775 ${BIND_DATA_DIR}
  chown -R ${BIND_USER}:${BIND_USER} ${BIND_DATA_DIR}

  if [ ! -d ${BIND_DATA_DIR}/lib ]; then
    mkdir -p ${BIND_DATA_DIR}/lib
    chown ${BIND_USER}:${BIND_USER} ${BIND_DATA_DIR}/lib
  fi
  rm -rf /var/lib/bind
  ln -sf ${BIND_DATA_DIR}/lib /var/lib/bind
}

create_dhcp_data_dir() {
  mkdir -p ${DHCP_DATA_DIR}

  # populate default dhcp configuration if it does not exist
  if [ ! -d ${DHCP_DATA_DIR}/etc ]; then
    mv /etc/dhcp ${DHCP_DATA_DIR}/etc
  fi
  rm -rf /etc/dhcp
  ln -sf ${DHCP_DATA_DIR}/etc /etc/dhcp
  chmod -R 0775 ${DHCP_DATA_DIR}
  chown -R ${DHCP_USER}:${DHCP_USER} ${DHCP_DATA_DIR}

  if [ ! -d ${DHCP_DATA_DIR}/lib ]; then
    mkdir -p ${DHCP_DATA_DIR}/lib
    chown ${DHCP_USER}:${DHCP_USER} ${DHCP_DATA_DIR}/lib
  fi
  rm -rf /var/lib/dhcp
  ln -sf ${DHCP_DATA_DIR}/lib /var/lib/dhcp
}

set_root_passwd() {
  echo "root:$ROOT_PASSWORD" | chpasswd
}

create_bind_pid_dir() {
  mkdir -m 0775 -p /var/run/named
  chown root:${BIND_USER} /var/run/named
}

create_dhcp_pid_dir() {
  mkdir -m 0775 -p /var/run/dhcp-server
  chown root:${DHCP_USER} /var/run/dhcp-server
}

create_bind_cache_dir() {
  mkdir -m 0775 -p /var/cache/bind
  chown root:${BIND_USER} /var/cache/bind
}

# bind9
create_bind_pid_dir
create_bind_data_dir
create_bind_cache_dir
#isc-dhcp-server
create_dhcp_pid_dir
create_dhcp_data_dir

mkdir /var/log/bind
chown ${BIND_USER}:${BIND_USER} /var/log/bind

mylogger "Starting dhcp..."
mkdir -p /var/lib/dhcp
touch /var/lib/dhcp/dhcpd.leases
sudo $(which dhcpd) -user ${DHCP_USER} -group ${DHCP_USER} -f -4 -pf /var/run/dhcp-server/dhcpd.pid -cf /etc/dhcp/dhcpd.conf ${DHCP_INTERFACES} &

mylogger "Starting named..."
sudo $(which named) -u ${BIND_USER} -g ${EXTRA_ARGS} &
