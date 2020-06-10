# Sonatype Nexus 3 on ARM

Run Sonatype Sonatype Nexus Repository Manager (NXRM) on ARM hardware (e.g. Raspberry Pi) - both 32-bit (armv7l) and 64-bit (aarch64).

Nexus doesn't provide an official image to run on Raspberry Pi.

So I'm creating one and sharing it with everyone :-) .

(For x86, use the official image - [sonatype/nexus3](https://hub.docker.com/r/sonatype/nexus3/))




# Running
```
docker run -d -p 8081:8081 --name nexus klo2k/nexus3
```




# Building with "docker buildx" locally
ARM 32-bit (armv7l):
```
docker buildx build --pull \
  --platform "linux/arm/v7" \
  --tag "klo2k/nexus3" \
  --output=type=docker \
  .
```

ARM 64-bit (aarch64):
```
docker buildx build --pull \
  --platform "linux/arm64" \
  --tag "klo2k/nexus3" \
  --output=type=docker \
  .
```




# Credits
- *Nexus Team*: For the awesome repo, and their [Dockerfile](https://github.com/sonatype/docker-nexus3/blob/master/Dockerfile)
- *Dan Rollo (bhamail)*: For the [jna-platform jar hack](https://bhamail.github.io/pinexus/nexussetup.html)
