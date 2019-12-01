ARG VERSION=latest
FROM tr069_dhcp_client:${VERSION}

ARG VERSION=latest

LABEL maintainer=Christian.Katsch@devolo.de

# store container version
RUN echo "apache ${VERSION}" >> /etc/container-version

RUN dpkg --add-architecture i386

# Specify the user which should be used to execute all commands below
USER root

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get -y upgrade && apt-get install -y \
    apache2 \
    php

ENV APACHE_RUN_USER admin
ENV APACHE_RUN_GROUP admin
ENV APACHE_LOG_DIR /var/log/apache2
ENV APACHE_PID_FILE /var/run/apache2.pid
ENV APACHE_RUN_DIR /var/run/apache2
ENV APACHE_LOCK_DIR /var/lock/apache2
RUN mkdir p $APACHE_RUN_DIR $APACHE_LOCK_DIR; exit 0
RUN rm /var/www/html/index.html
RUN rm /etc/apache2/apache2.conf
RUN chown admin ${APACHE_RUN_DIR}
RUN chown admin ${APACHE_LOG_DIR}
RUN chown admin ${APACHE_LOCK_DIR}

COPY inserts/ /

WORKDIR /etc/apache2/mods-enabled
RUN ln -s ../mods-available/cgi.load
RUN ln -s ../mods-available/dav.load
RUN ln -s ../mods-available/dav_fs.load

WORKDIR /var/www/html

# Expose the html port
EXPOSE 80

ENTRYPOINT ["docker-entrypoint.sh"]
