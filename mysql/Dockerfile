ARG VERSION=latest
FROM tr069_dhcp_client:${VERSION}

ARG VERSION=latest

LABEL maintainer=Christian.Katsch@devolo.de

# store container version
RUN echo "acsdb ${VERSION}" >> /etc/container-version

RUN dpkg --add-architecture i386

RUN apt-get update && apt-get -y upgrade && apt-get install -y \
    mysql-server

# Set the working directory to opt to install
WORKDIR /opt/admin

# Expose the stun ports
EXPOSE 3306

COPY inserts/bin/* /docker-entrypoint.d/
COPY inserts/*.db /tmp/

ENTRYPOINT ["docker-entrypoint.sh"]
