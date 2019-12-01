# Loosely copied from https://github.com/DrumSergio/GenieACS-Docker
ARG VERSION=latest
FROM tr069_dhcp_client:${VERSION}

ARG VERSION=latest

# store container version
RUN echo "genieacs ${VERSION}" >> /etc/container-version

RUN apt-get update && apt-get install -y git mongodb apt-transport-https apt-utils supervisor curl
RUN mkdir -p /var/log/supervisor

# install node as recommended for GenieACS
RUN curl -sL https://deb.nodesource.com/setup_8.x | bash -
RUN apt-get update && apt-get install -y nodejs gcc g++ make

# install genieacs 1.2 from github
WORKDIR /opt
ARG GENIEACS_VERSION=c6db1edc5ffd71fcd48dcf5306c83d7b54ac9e12
RUN git clone https://github.com/genieacs/genieacs.git && \
    git -C genieacs checkout $GENIEACS_VERSION
RUN git config --global user.email "test@example.com" && git config --global user.name "test"
# cherry-pick bugfix Fix download RPC regression (DELOS5-2252)
RUN git -C genieacs cherry-pick 2b9033db1944dcada5c1be639ee38afc26e3ef70
RUN git -C genieacs cherry-pick 4aa525754fd64a693d415fe7922b9569461499fc
RUN cd genieacs && npm install && npm run build

# link the config to /opt/genieacs/config
COPY inserts/config.json /opt/genieacs/dist/config/config.json

# cwmp, nbi and UI interface
EXPOSE 7547 7557 7070

# GenieACS services are run through supervisord
COPY inserts/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

COPY inserts/docker-entrypoint.d/* /docker-entrypoint.d/
ENTRYPOINT ["docker-entrypoint.sh"]
