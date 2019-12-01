ARG VERSION=latest
FROM tr069_dhcp_client:${VERSION}

ARG VERSION=latest

LABEL maintainer=Christian.Katsch@devolo.de

# store container version
RUN echo "stun ${VERSION}" >> /etc/container-version

RUN dpkg --add-architecture i386

RUN apt-get update && apt-get -y upgrade && apt-get install -y \
    stun-server

# Set the working directory to opt to install
WORKDIR /opt/admin

# Expose the stun ports
EXPOSE 3478/udp
EXPOSE 3479/udp

COPY inserts/bin/* /docker-entrypoint.d/

ENTRYPOINT ["docker-entrypoint.sh"]
