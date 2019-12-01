ARG VERSION=latest
FROM tr069_base:${VERSION}

ARG VERSION=latest

LABEL maintainer=Christian.Katsch@devolo.de

# Specify the user which should be used to execute all commands below
USER root

# store container version
RUN echo "gateway ${VERSION}" >> /etc/container-version

ENV BIND_USER=root \
    DHCP_USER=root \
    DHCP_INTERFACES=" " \
    DATA_DIR=/data

RUN dpkg --add-architecture i386

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get -y upgrade && apt-get -y install\
    iptables \
    net-tools \
    ca-certificates \
    unzip \
    apt-transport-https \
    apt-utils \
    bind9 \
    bind9utils \
    isc-dhcp-server \
    man \
    dnsutils 

COPY inserts/bin/* /docker-entrypoint.d/
COPY inserts/dhcpd.conf /etc/dhcp
COPY inserts/named.conf* /etc/bind/
COPY inserts/db.* /etc/bind/
COPY inserts/rndc.key /etc/bind
COPY inserts/Krndc-key.* /etc/bind/

EXPOSE 53/udp 53/tcp 67/udp 68/udp

ENTRYPOINT ["docker-entrypoint.sh"]
