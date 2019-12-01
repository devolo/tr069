ARG VERSION=latest
FROM tr069_gateway:${VERSION}

ARG VERSION=latest

LABEL maintainer=Christian.Katsch@devolo.de

# Specify the user which should be used to execute all commands below
USER root

# store container version
RUN echo "upstream ${VERSION}" >> /etc/container-version

RUN dpkg --add-architecture i386

COPY inserts/bin/* /docker-entrypoint.d/
RUN sed -i -E "s/^#* *timeout [0-9]*;/timeout ${DHCLIENT_TIMEOUT:-60};/g" /etc/dhcp/dhclient.conf

ENTRYPOINT ["docker-entrypoint.sh"]
