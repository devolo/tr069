ARG VERSION=latest
FROM tr069_dhcp_client:${VERSION}

ARG VERSION=latest

LABEL maintainer=Christian.Katsch@devolo.de

# store container version
RUN echo "nginx ${VERSION}" >> /etc/container-version

RUN dpkg --add-architecture i386

# Specify the user which should be used to execute all commands below
USER root

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get -y upgrade && apt-get install -y \
    build-essential libssl-dev unzip libpcre3-dev zlib1g-dev curl

# Build nginx with auth-digest module
RUN wget https://github.com/samizdatco/nginx-http-auth-digest/archive/master.zip && unzip master.zip
RUN wget http://nginx.org/download/nginx-1.16.0.tar.gz && tar zxvf nginx-1.16.0.tar.gz && cd nginx-* && \
    ./configure --with-debug --prefix=/etc/nginx --sbin-path=/usr/sbin/nginx --modules-path=/usr/lib/nginx/modules \
    --conf-path=/etc/nginx/nginx.conf --error-log-path=/var/log/nginx/error.log --pid-path=/var/run/nginx.pid \
    --lock-path=/var/run/nginx.lock --with-http_ssl_module --add-module=../nginx-http-auth-digest-master && \
    make -j3 install

COPY inserts/ /

WORKDIR /etc/nginx/sites-enabled
RUN ln -s ../sites-available/telco0

WORKDIR /var/www/

# Expose the HTTP port (web)
EXPOSE 80
# Expose the HTTPS port (web)
EXPOSE 443

# Expose the HTTP port (acs)
EXPOSE 9000
# Expose the HTTPS port (acs)
EXPOSE 9001
# Expose the HTTP port (openacs basic auth)
EXPOSE 9010
# Expose the HTTP port (openacs digest auth)
EXPOSE 9011

# Expose the HTTP port (genieacs basic auth)
EXPOSE 10000
# Expose the HTTP port (genieacs digest auth)
EXPOSE 10001

ENTRYPOINT ["docker-entrypoint.sh"]
