ARG VERSION=latest
FROM tr069_dhcp_client:${VERSION}

ARG VERSION=latest

LABEL maintainer=Christian.Katsch@devolo.de

# store container version
RUN echo "xmpp ${VERSION}" >> /etc/container-version

RUN dpkg --add-architecture i386

RUN apt-get update && apt-get -y upgrade && apt-get -y install\
    prosody \
    lua-dbi-mysql \
    lua-sql-mysql \
    lua-sec

# Set the working directory to opt to install
WORKDIR /opt/admin

# Expose the XMPP ports
EXPOSE 5222
EXPOSE 5223
EXPOSE 5269
EXPOSE 5298/udp
EXPOSE 5298
EXPOSE 8010

COPY inserts/ /

ENTRYPOINT ["docker-entrypoint.sh"]
