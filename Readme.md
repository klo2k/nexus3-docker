# Sonatype Nexus 3 on ARM

Run Sonatype Sonatype Nexus Repository Manager (NXRM) on ARM hardware (e.g. Raspberry Pi) - both 32-bit (armv7l) and 64-bit (aarch64).

Nexus doesn't provide an official image to run on Raspberry Pi.

So I'm creating one and sharing it with everyone :-) .

(For x64, use the official image - [sonatype/nexus3](https://hub.docker.com/r/sonatype/nexus3/))




# Running
```
docker run -d -p 8081:8081 --name nexus klo2k/nexus3
```




# Building with "docker buildx" locally
Initialise [buildx](https://docs.docker.com/buildx/working-with-buildx/), if you're on a x64 machine:
```
# Enable experimental mode
export DOCKER_CLI_EXPERIMENTAL=enabled

# Enable ARM support
docker run --rm --privileged docker/binfmt:a7996909642ee92942dcd6cff44b9b95f08dad64

# Create 'mybuilder' if not exist, set as default builder
docker buildx inspect mybuilder||docker buildx create --name mybuilder
docker buildx use mybuilder

# Start builder
docker buildx inspect --bootstrap
```

Build ARM 32-bit (armv7l):
```
docker buildx build --pull \
  --platform "linux/arm/v7" \
  --tag "klo2k/nexus3" \
  --output=type=docker \
  .
```

Build ARM 64-bit (aarch64):
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
- *Henry Wang (HenryQW)*: For [Docker buildx Github Action](https://www.henry.wang/2019/12/05/arm-dockerhub.html)
