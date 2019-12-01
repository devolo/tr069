ARG VERSION=latest
FROM tr069_dhcp_client:${VERSION}

ARG VERSION=latest

LABEL maintainer=Christian.Katsch@devolo.de

RUN dpkg --add-architecture i386

# store container version
RUN echo "rsyslog ${VERSION}" >> /etc/container-version

RUN rm -f /etc/rsyslog.d/000_client.conf
COPY inserts/bin/* /docker-entrypoint.d/

ENTRYPOINT ["docker-entrypoint.sh"]
