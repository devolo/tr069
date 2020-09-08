ARG VERSION=latest
FROM tr069_dhcp_client:${VERSION}

ARG VERSION=latest

LABEL maintainer=Christian.Katsch@devolo.de

# store container version
RUN echo "mqttbroker ${VERSION}" >> /etc/container-version

RUN dpkg --add-architecture i386

RUN apt-get update && apt-get -y upgrade && apt-get install -y \
	mosquitto \
	mosquitto-clients


# Set the working directory to opt to install
WORKDIR /opt/admin

# Expose the mqtt ports
EXPOSE 1883
EXPOSE 8883

COPY inserts/bin/* /docker-entrypoint.d/
COPY inserts/etc/mosquitto/* /etc/mosquitto/

ENTRYPOINT ["docker-entrypoint.sh"]
