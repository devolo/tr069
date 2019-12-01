ARG VERSION=latest
FROM tr069_gateway:${VERSION}

ARG VERSION=latest

LABEL maintainer=Christian.Katsch@devolo.de

# Specify the user which should be used to execute all commands below
USER root

# store container version
RUN echo "telco0 ${VERSION}" >> /etc/container-version

RUN apt-get update && apt-get -y upgrade && apt-get -y install \
    conntrack

# Set the working directory to opt to install the content
WORKDIR /opt

COPY inserts/bin/* /docker-entrypoint.d/

ENTRYPOINT ["docker-entrypoint.sh"]
