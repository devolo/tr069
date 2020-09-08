ARG VERSION=latest
FROM tr069_dhcp_client:${VERSION}

ARG VERSION=latest

LABEL maintainer=Christian.Katsch@devolo.de

# Specify the user which should be used to execute all commands below
USER root

# store container version
RUN echo "elastic ${VERSION}" >> /etc/container-version

RUN dpkg --add-architecture i386

# following loosely coupled to https://smart-factory.net/mqtt-elasticsearch-setup/
RUN apt-get update && apt-get -y upgrade && apt-get install -y --fix-missing \
	apt-transport-https \
	gnupg \
	curl \
	python3 \
	python3-pip \
	git \
	npm \
	openjdk-8-jdk

RUN wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add -
RUN sudo sh -c 'echo "deb https://artifacts.elastic.co/packages/7.x/apt stable main" > /etc/apt/sources.list.d/elastic-7.x.list'

RUN apt-get update && apt-get -y upgrade && apt-get install -y --fix-missing \
	elasticsearch \
	kibana

RUN pip3 install --upgrade pip;
RUN git clone https://github.com/ElasticHQ/elasticsearch-HQ.git; cd elasticsearch-HQ; pip3 install -r requirements.txt

# Expose the selasticsearch port
EXPOSE 9200
# Expose the kibana port
EXPOSE 5601
# Expose the ElasticHQ port
EXPOSE 5000

COPY inserts/bin/* /docker-entrypoint.d/
COPY inserts/etc/kibana/kibana.yml /etc/kibana/kibana.yml

RUN pip install elasticsearch; pip install paho-mqtt
COPY inserts/mqttToElasticSearch.py /opt/admin/mqttToElasticSearch.py

ENTRYPOINT ["docker-entrypoint.sh"]
