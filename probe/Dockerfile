ARG VERSION=latest
FROM tr069_dhcp_client:${VERSION}

ARG VERSION=latest

LABEL maintainer=Christian.Katsch@devolo.de

# Specify the user which should be used to execute all commands below
USER root

# store container version
RUN echo "probe ${VERSION}" >> /etc/container-version

RUN dpkg --add-architecture i386

############## tools ################################################

RUN apt-get update && apt-get -y upgrade && apt-get install -y --fix-missing \
    chromium-browser \
    emacs

# Set the working directory to opt to install the content
WORKDIR /opt

COPY inserts/bin/* /docker-entrypoint.d/

USER admin

ENTRYPOINT ["docker-entrypoint.sh"]
