FROM ubuntu:20.04
ARG VERSION=2.1.0

RUN apt-get update \
    && apt-get -y upgrade \
    && apt-get -y install apt-utils \
    && apt-get -y install \
        maven \
        wget \
        git \
        python \
        openjdk-8-jdk-headless \
        patch \
	    unzip \
    && cd /tmp \
    && wget http://mirror.linux-ia64.org/apache/atlas/${VERSION}/apache-atlas-${VERSION}-sources.tar.gz \
    && mkdir -p /opt/gremlin \
    && mkdir -p /tmp/atlas-src \
    && tar --strip 1 -xzvf apache-atlas-${VERSION}-sources.tar.gz -C /tmp/atlas-src \
    && rm apache-atlas-${VERSION}-sources.tar.gz \
    && cd /tmp/atlas-src \
    && export MAVEN_OPTS="-Xms2g -Xmx2g" \
    && export JAVA_HOME="/usr/lib/jvm/java-8-openjdk-amd64" \
    && mvn clean -Dmaven.repo.local=/tmp/.mvn-repo -Dhttps.protocols=TLSv1.2 -DskipTests package -Pdist, embedded-cassandra-solr \
    && tar -xzvf /tmp/atlas-src/distro/target/apache-atlas-${VERSION}-server.tar.gz -C /opt \
    && rm -Rf /tmp/atlas-src \
    && rm -Rf /tmp/.mvn-repo \
    && apt-get -y --purge remove \
        maven \
        git \
    && apt-get -y remove openjdk-11-jre-headless \
    && apt-get -y autoremove \
    && apt-get -y clean

RUN ln -s apache-atlas-${VERSION}/ apache-atlas
COPY resource/atlas_start.py.patch /opt/apache-atlas/bin/
COPY resource/atlas_config.py.patch /opt/apache-atlas/bin/
RUN cd /opt/apache-atlas/bin \
    && patch -b -f < atlas_start.py.patch \
    && patch -b -f < atlas_config.py.patch

COPY resource/atlas-env.sh /opt/apache-atlas/conf/atlas-env.sh
COPY resource/hbase/hbase-site.xml.template /opt/apache-atlas/conf/hbase/hbase-site.xml.template
COPY resource/gremlin /opt/gremlin/
# COPY conf/keycloak.json /opt/apache-atlas/conf/keycloak.json


RUN cd /opt/apache-atlas \
    && ./bin/atlas_start.py -setup || true

RUN cd /opt/apache-atlas \
    && ./bin/atlas_start.py & \
    touch /opt/apache-atlas-${VERSION}/logs/application.log \
    && tail -f /opt/apache-atlas-${VERSION}/logs/application.log | sed '/AtlasAuthenticationFilter.init(filterConfig=null)/ q' \
    && sleep 10 \
    && /opt/apache-atlas/bin/atlas_stop.py
