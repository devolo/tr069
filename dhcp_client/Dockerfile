ARG VERSION=latest
FROM tr069_base:${VERSION}

ARG VERSION=latest

LABEL maintainer=Christian.Katsch@devolo.de

# store container version
RUN echo "dhcp_client ${VERSION}" >> /etc/container-version

RUN dpkg --add-architecture i386

COPY inserts/bin/* /docker-entrypoint.d/

ENTRYPOINT ["docker-entrypoint.sh"]