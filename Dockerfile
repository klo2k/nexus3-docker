# Download, extract Nexus to /tmp/sonatype/nexus
FROM debian:buster-slim as downloader

ARG NEXUS_VERSION=3.33.1-01
ARG NEXUS_DOWNLOAD_URL=https://download.sonatype.com/nexus/3/nexus-${NEXUS_VERSION}-unix.tar.gz

# Download Nexus and other stuff we need later
# Use wget to improve performance (#11)
# Install wget
RUN apt update && apt install -y wget
# Download jars required for OrientDB startup error hack
RUN wget --quiet --directory-prefix=/tmp/ \
        https://repo1.maven.org/maven2/net/java/dev/jna/jna/5.5.0/jna-5.5.0.jar \
        https://repo1.maven.org/maven2/net/java/dev/jna/jna-platform/5.5.0/jna-platform-5.5.0.jar
# Download + extract Nexus to "/tmp/sonatype/nexus" for use later
RUN wget --quiet --output-document=/tmp/nexus.tar.gz "${NEXUS_DOWNLOAD_URL}" && \
    mkdir /tmp/sonatype && \
    tar -zxf /tmp/nexus.tar.gz -C /tmp/sonatype && \
    mv /tmp/sonatype/nexus-${NEXUS_VERSION} /tmp/sonatype/nexus && \
    rm /tmp/nexus.tar.gz




# Runtime image
# Logic adapted from official Dockerfile
# https://github.com/sonatype/docker-nexus3/blob/master/Dockerfile
FROM debian:buster-slim

# Image metadata
# git commit
LABEL org.opencontainers.image.revision="-"
LABEL org.opencontainers.image.source="https://github.com/klo2k/nexus3-docker"

# Install Java 8
ARG DEBIAN_FRONTEND=noninteractive
RUN apt update && \
    # Add AdoptOpenJDK repo
    apt install --yes apt-transport-https ca-certificates gnupg software-properties-common wget && \
    wget --quiet --output-document=- https://adoptopenjdk.jfrog.io/adoptopenjdk/api/gpg/key/public | apt-key add - && \
    add-apt-repository --yes https://adoptopenjdk.jfrog.io/adoptopenjdk/deb/ && \
    # Work-around adoptopenjdk-8-hotspot-jre installation error
    mkdir --parent /usr/share/man/man1/ && \
    # Install JRE 8 along with missing dependency
    apt update && apt install --yes adoptopenjdk-8-hotspot-jre libatomic1 && \
    # Clean-up
    apt purge --yes apt-transport-https gnupg software-properties-common wget && \
    apt autoremove --yes && apt clean

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
COPY --from=downloader /tmp/jna-5.5.0.jar /opt/sonatype/nexus/system/net/java/dev/jna/jna/5.4.0/jna-5.4.0.jar
COPY --from=downloader /tmp/jna-platform-5.5.0.jar /opt/sonatype/nexus/system/net/java/dev/jna/jna-platform/5.4.0/jna-platform-5.4.0.jar
RUN chmod 644 \
      /opt/sonatype/nexus/system/net/java/dev/jna/jna/5.4.0/jna-5.4.0.jar \
      /opt/sonatype/nexus/system/net/java/dev/jna/jna-platform/5.4.0/jna-platform-5.4.0.jar

# Create Nexus user + group, based on official image:
#   nexus:x:200:200:Nexus Repository Manager user:/opt/sonatype/nexus:/bin/false
#   nexus:x:200:nexus
RUN groupadd --gid 200 nexus && \
    useradd \
      --shell /bin/false \
      --comment 'Nexus Repository Manager user' \
      --home-dir /opt/sonatype/nexus \
      --no-create-home \
      --no-user-group \
      --uid 200 \
      --gid 200 \
      nexus

# Data directory "/nexus-data" owns "nexus" user
RUN chown -R nexus:nexus /nexus-data

VOLUME /nexus-data

EXPOSE 8081

USER nexus

ENV INSTALL4J_ADD_VM_PARAMS="-Xms1200m -Xmx1200m -XX:MaxDirectMemorySize=2g -Djava.util.prefs.userRoot=/nexus-data/javaprefs"
ENV NEXUS_CONTEXT=''

CMD ["sh", "-c", "/opt/sonatype/start-nexus-repository-manager.sh"]
