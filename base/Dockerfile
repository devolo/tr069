FROM ubuntu:18.04

ARG VERSION=latest

LABEL maintainer=Christian.Katsch@devolo.de

# store container version
RUN echo "base ${VERSION}" > /etc/container-version

RUN dpkg --add-architecture i386

############## neccessary tools ################################################

# docker provides all ip adresses; use dig and ip to get the ip of a container
RUN apt-get update && apt-get -y upgrade && apt-get -y install \
    iproute2 \
    dnsutils \
    isc-dhcp-client \
    net-tools \
    nmap \
    vim \
    wget \
    sudo \
    tzdata \
    psmisc \
    ntpdate \
    rsyslog

############### debug tools ####################################################

RUN apt-get update && apt-get -y upgrade && apt-get -y install\
    ipvsadm \
    tcpdump \
    iputils-ping \
    less \
    strace

################################################################################

# Create a user and group used to launch processes
# The user ID 1000 is the default for the first "regular" user,
# so there is a high chance that this ID will be equal to the current user
# making it easier to use volumes (no permission issues)
RUN groupadd -r admin -g 1000 && useradd -u 1000 -r -g admin -G plugdev,sudo -m -d /opt/admin -s /sbin/nologin -c "Admin user" admin && \
    chmod 755 /opt/admin && \
    echo "admin ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/admin && \
    chmod 0440 /etc/sudoers.d/admin

ENV HOME /opt/admin
# Set the working directory to opt to install
WORKDIR /opt/admin

COPY inserts/bin/* /docker-entrypoint.d/
COPY inserts/dhclient/dhclient-enter-hooks /etc/dhcp/
COPY inserts/dhclient/replace_with_file /tmp/
COPY inserts/etc/rsyslog.conf /etc/rsyslog.conf
COPY inserts/etc/rsyslog.d/000_client.conf /etc/rsyslog.d/000_client.conf
RUN sed -i -E "s/^#* *timeout [0-9]*;/timeout ${DHCLIENT_TIMEOUT:-300};/g" /etc/dhcp/dhclient.conf
################################################################################
RUN ln -s /docker-entrypoint.d/docker-entrypoint.sh /entrypoint.sh # backwards compat
RUN ln -s /docker-entrypoint.d/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
ENTRYPOINT ["docker-entrypoint.sh"]
