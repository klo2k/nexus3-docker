# Download, extract Nexus to /tmp/sonatype/nexus
FROM debian:buster-slim as downloader

ARG NEXUS_VERSION=3.32.0-03
ARG NEXUS_DOWNLOAD_URL=https://download.sonatype.com/nexus/3/nexus-${NEXUS_VERSION}-unix.tar.gz

RUN apt update && apt install -y wget

RUN wget "${NEXUS_DOWNLOAD_URL}" -O "/tmp/nexus.tar.gz"
RUN mkdir /tmp/sonatype && \
    tar -zxf /tmp/nexus.tar.gz -C /tmp/sonatype && \
    mv /tmp/sonatype/nexus-${NEXUS_VERSION} /tmp/sonatype/nexus


# Runtime image
# Logic adapted from official Dockerfile
# https://github.com/sonatype/docker-nexus3/blob/master/Dockerfile
FROM debian:buster-slim

# Image metadata
# git commit
LABEL org.opencontainers.image.revision="-"
LABEL org.opencontainers.image.source="https://github.com/klo2k/nexus3-docker"

# Install Java 8 and wget
ARG DEBIAN_FRONTEND=noninteractive

# Fix debian slim java installion problem
RUN mkdir -p /usr/share/man/man1

# Java 8 is only available from debian stretch
RUN echo "deb http://http.debian.net/debian stretch main" | \
      tee --append /etc/apt/sources.list.d/stretch.list

RUN apt update && \
    apt install -y --no-install-recommends openjdk-8-jre-headless && \
    apt clean

# Setup: Rename App, Data and Work directory per official image
# App directory (/opt/sonatype/nexus)
COPY --from=downloader /tmp/sonatype /opt/sonatype
RUN \
    # Data directory (/nexus-data)
    mv /opt/sonatype/sonatype-work/nexus3 /nexus-data && \
    # Work directory (/opt/sonatype/sonatype-work/nexus3)
    ln -s /nexus-data /opt/sonatype/sonatype-work/nexus3

# Setup: Start-up script (from official image)
COPY files/opt/sonatype/start-nexus-repository-manager.sh /opt/sonatype/start-nexus-repository-manager.sh
RUN chmod 755 /opt/sonatype/start-nexus-repository-manager.sh

# Fix-up: Startup command line: Remove hard-coded memory parameters in /opt/sonatype/nexus/bin/nexus.vmoptions (per official Docker image)
RUN sed -i -e '/^-Xms\|^-Xmx\|^-XX:MaxDirectMemorySize/d' /opt/sonatype/nexus/bin/nexus.vmoptions

# Enable NEXUS_CONTEXT env-variable via nexus-default.properties
RUN sed -i -e 's/^nexus-context-path=\//nexus-context-path=\/\${NEXUS_CONTEXT}/g' /opt/sonatype/nexus/etc/nexus-default.properties

# Fix-up: Startup error with OrientDB on ARM - replace in-place 5.4.0 with 5.5.0 lib (reference is hard-coded in config files)
# http://bhamail.github.io/pinexus/nexussetup.html
RUN apt update && apt install -y wget
RUN wget https://repo1.maven.org/maven2/net/java/dev/jna/jna/5.5.0/jna-5.5.0.jar -O /opt/sonatype/nexus/system/net/java/dev/jna/jna/5.4.0/jna-5.4.0.jar
RUN wget https://repo1.maven.org/maven2/net/java/dev/jna/jna-platform/5.5.0/jna-platform-5.5.0.jar -O /opt/sonatype/nexus/system/net/java/dev/jna/jna-platform/5.4.0/jna-platform-5.4.0.jar
RUN chmod 644 \
      /opt/sonatype/nexus/system/net/java/dev/jna/jna/5.4.0/jna-5.4.0.jar \
      /opt/sonatype/nexus/system/net/java/dev/jna/jna-platform/5.4.0/jna-platform-5.4.0.jar

# Data directory "/nexus-data"
VOLUME /nexus-data

EXPOSE 8081

ENV INSTALL4J_ADD_VM_PARAMS="-Xms1200m -Xmx1200m -XX:MaxDirectMemorySize=2g -Djava.util.prefs.userRoot=/nexus-data/javaprefs"
ENV NEXUS_CONTEXT=''

CMD ["sh", "-c", "/opt/sonatype/start-nexus-repository-manager.sh"]
