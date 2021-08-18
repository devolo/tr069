ARG VERSION=latest
FROM tr069_dhcp_client:${VERSION} as intermediate

ARG VERSION=latest

FROM ubuntu:12.04

LABEL maintainer=Christian.Katsch@devolo.de

# Specify the user which should be used to execute all commands below
USER root

# store container version
RUN echo "openacs ${VERSION}" >> /etc/container-version
RUN sed -i 's/archive.ubuntu.com/old-releases.ubuntu.com/g' /etc/apt/sources.list && \
    sed -i 's/security.ubuntu.com/old-releases.ubuntu.com/g' /etc/apt/sources.list
RUN apt-get update && apt-get -y upgrade && apt-get -y install \
    mysql-server \
    default-jdk \
    ant \
    libmysql-java \
    unzip \
    tar \
    dnsutils \
    patch

############## neccessary tools ################################################

# docker provides all ip adresses; use dig and ip to get the ip of a container
RUN apt-get update && apt-get -y upgrade && apt-get -y install\
    dnsutils \
    isc-dhcp-client \
    net-tools \
    nmap \
    vim \
    wget \
    sudo \
    tzdata \
    psmisc \
    ntpdate

############### debug tools ####################################################

RUN apt-get update && apt-get -y upgrade && apt-get -y install\
    ipvsadm \
    tcpdump \
    iputils-ping \
    less \
    strace

# the container will build openacs from this ...
WORKDIR /tmp

COPY inserts/jboss-4.2.3.GA-jdk6.zip .

RUN unzip jboss-4.2.3.GA-jdk6.zip > /dev/null && \
    mkdir -p /opt/jboss && \
    mv jboss-4.2.3.GA/* /opt/jboss && \
    rm -rf jboss-4.2.3.GA-jdk6.zip jboss-4.2.3.GA && \
    ln -sf /usr/share/java/mysql-connector-java.jar /opt/jboss/server/default/lib/

# Set the JBOSS_HOME env variable
ENV JBOSS_HOME /opt/jboss

COPY inserts/openacs-svn.tgz .
RUN tar -xvzf openacs-svn.tgz && rm openacs-svn.tgz
WORKDIR /tmp/openacs-svn
COPY inserts/000_remove_NoMoreRequests_set_timeout.patch .
RUN patch -p 0 < /tmp/openacs-svn/000_remove_NoMoreRequests_set_timeout.patch
RUN ant -f b.xml clean make deploy
COPY inserts/openacs-ds.xml /opt/jboss/server/default/deploy/

RUN mkdir /docker-entrypoint.d
COPY --from=intermediate /docker-entrypoint.d/* /docker-entrypoint.d/
COPY --from=intermediate /etc/dhcp/dhclient-enter-hooks /etc/dhcp/
COPY --from=intermediate /tmp/replace_with_file /tmp/

RUN ln -s /docker-entrypoint.d/docker-entrypoint.sh /entrypoint.sh; ln -s /docker-entrypoint.d/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

# Expose the jboss port
EXPOSE 8080

# use start script
COPY inserts/bin/* /docker-entrypoint.d/
COPY inserts/openACS.db /tmp

###
#connector stuff
###
#python
RUN apt-get update && apt-get -y upgrade && apt-get install -y --fix-missing \
    software-properties-common \
    python3 \
    python3-dev \
    python3-dbg \
    python2.7 \
    python-pip \
    python-xmpp

RUN apt-get update && apt-get -y upgrade && apt-get install -y \
    curl

COPY inserts/opt/* /
###

ENTRYPOINT ["docker-entrypoint.sh"]
