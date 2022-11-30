# Download, extract Nexus to /tmp/sonatype/nexus
FROM eclipse-temurin:8-jre-jammy as downloader

ARG NEXUS_VERSION=3.43.0-01
ARG NEXUS_DOWNLOAD_URL=https://download.sonatype.com/nexus/3/nexus-${NEXUS_VERSION}-unix.tar.gz

# Download Nexus and other stuff we need later
# Use wget to improve performance (#11)
# Install wget
RUN apt update && apt install -y wget
# Download + extract Nexus to "/tmp/sonatype/nexus" for use later
RUN wget --quiet --output-document=/tmp/nexus.tar.gz "${NEXUS_DOWNLOAD_URL}" && \
    mkdir /tmp/sonatype && \
    tar -zxf /tmp/nexus.tar.gz -C /tmp/sonatype && \
    mv /tmp/sonatype/nexus-${NEXUS_VERSION} /tmp/sonatype/nexus && \
    rm /tmp/nexus.tar.gz




# Runtime image
# Logic adapted from official Dockerfile
# https://github.com/sonatype/docker-nexus3/blob/master/Dockerfile
FROM eclipse-temurin:8-jre-jammy

# Image metadata
# git commit
LABEL org.opencontainers.image.revision="-"
LABEL org.opencontainers.image.source="https://github.com/klo2k/nexus3-docker"

# Setup: Rename App, Data and Work directory per official image
# App directory (/opt/sonatype/nexus)
COPY --from=downloader /tmp/sonatype /opt/sonatype
RUN \
    # Data directory (/nexus-data)
    mv /opt/sonatype/sonatype-work/nexus3 /nexus-data && \
    # Work directory (/opt/sonatype/sonatype-work/nexus3)
    ln -s /nexus-data /opt/sonatype/sonatype-work/nexus3

# Fix-up: Startup command line: Remove hard-coded memory parameters in /opt/sonatype/nexus/bin/nexus.vmoptions (per official Docker image)
RUN sed -i '/^-Xms/d;/^-Xmx/d;/^-XX:MaxDirectMemorySize/d' /opt/sonatype/nexus/bin/nexus.vmoptions

# Enable NEXUS_CONTEXT env-variable via nexus-default.properties
RUN sed -i -e 's/^nexus-context-path=\//nexus-context-path=\/\${NEXUS_CONTEXT}/g' /opt/sonatype/nexus/etc/nexus-default.properties

# Create Nexus user + group, based on official image:
#   nexus:x:200:200:Nexus Repository Manager user:/opt/sonatype/nexus:/bin/false
#   nexus:x:200:nexus
RUN groupadd --gid 200 nexus && \
    useradd \
      --system \
      --shell /bin/false \
      --comment 'Nexus Repository Manager user' \
      --home-dir /opt/sonatype/nexus \
      --no-create-home \
      --no-user-group \
      --uid 200 \
      --gid 200 \
      nexus

# Data directory "/nexus-data" owned by "nexus" user
RUN chown -R nexus:nexus /nexus-data

# Data volume
VOLUME /nexus-data

EXPOSE 8081

USER nexus

# Default environment variables, adapted from upstream Dockerfile
ENV NEXUS_HOME=/opt/sonatype/nexus \
    NEXUS_DATA=/nexus-data \
    NEXUS_CONTEXT='' \
    SONATYPE_WORK=/opt/sonatype/sonatype-work \
    # Low `-Xms`, `-Xmx` default for Raspberry Pi
    INSTALL4J_ADD_VM_PARAMS="-Xms1200m -Xmx1200m -XX:MaxDirectMemorySize=2g -Djava.util.prefs.userRoot=/nexus-data/javaprefs"

CMD ["/opt/sonatype/nexus/bin/nexus", "run"]
