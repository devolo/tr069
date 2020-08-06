ARG VERSION=latest
FROM tr069_gateway:${VERSION}

ARG VERSION=latest

# store container version
RUN echo "home0 ${VERSION}" >> /etc/container-version

LABEL maintainer=Christian.Katsch@devolo.de

# Specify the user which should be used to execute all commands below
USER root

RUN dpkg --add-architecture i386

RUN apt-get update && apt-get install -y miniupnpd miniupnpc tftpd-hpa
COPY inserts/etc/miniupnpd.conf /etc/miniupnpd/miniupnpd.conf
COPY inserts/etc/default/miniupnpd /etc/default/miniupnpd
COPY inserts/etc/iptables_init.sh /etc/miniupnpd/iptables_init.sh
COPY inserts/tftpd-hpa /etc/default
RUN mkdir /tftpboot && chmod 1777 /tftpboot

EXPOSE 6000

# Expose the TFTP port
EXPOSE 69/udp

# Set the working directory to opt to install the content
WORKDIR /opt

############# TR-064 ###############
RUN apt-get update && apt-get -y upgrade &&  apt-get -y install \
	python3 \
	python3-pip \
	npm; \
	pip3 install --upgrade pip; \
	python3 -m pip install gcovr psutil requests; \
	npm install -g mockserver
COPY inserts/tr064/mockserver/* /opt/
COPY inserts/tr064/ssdp-mocks/* /opt/
############# TR-064 ###############

COPY inserts/bin/* /docker-entrypoint.d/

ENTRYPOINT ["docker-entrypoint.sh"]
