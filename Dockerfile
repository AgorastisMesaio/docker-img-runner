# Dockerfile for GitHub self-hosted Runner
#
# This Dockerfile sets up a standard GitHub self-hosted Runner container that you can use
# inside your docker compose projects or standalone
#
# Use the official Ubuntu base image
#
# If you want to run it manually, remember to do it from repo's root:
#
#  cd <repo_root>
#  docker buildx build -f ./build/dk-runner/Dockerfile --build-arg RUNNER_VERSION='2.320.0' -t Whatever/<name> .
#
FROM ubuntu

# Argument to specify the GitHub runner version
ARG RUNNER_VERSION
ENV DEBIAN_FRONTEND=noninteractive

# Metadata for the image
LABEL Author="Agorastis Mesaio"
LABEL BaseImage="ubuntu"
LABEL RunnerVersion=${RUNNER_VERSION}

# Update the package list and upgrade all packages
RUN apt-get -qq update -y && apt-get -qq upgrade -y

# Given that it is a minimal install of Ubuntu, this image only includes the C,
# C.UTF-8, and POSIX locales by default. For most uses requiring a UTF-8 locale,
# C.UTF-8 is likely sufficient (-e LANG=C.UTF-8 or ENV LANG C.UTF-8).

# Install required packages and dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    sudo \
    ca-certificates \
    && update-ca-certificates

# Install Node.js 20.x
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
apt-get install -y nodejs

# Install other packages and dependencies
RUN apt-get -qq install -y --no-install-recommends \
    wget \
    unzip \
    vim \
    git \
    dnsutils \
    jq \
    ipcalc \
    build-essential \
    libssl-dev \
    libffi-dev \
    python3 \
    python3-venv \
    python3-dev \
    python3-pip \
    python3-yaml \
    python3-colorama \
    supervisor

############################################################################################
# Install Docker
############################################################################################

# Create a 'docker' user and assign to the sudo group
RUN useradd -m -G sudo docker

# Allow the 'docker' user to execute sudo commands without a password
RUN echo 'docker ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

############################################################################################
# Install using the repository
# https://docs.docker.com/engine/install/ubuntu/#install-using-the-repository
############################################################################################
#
# Add Docker's official GPG key:
# RUN apt-get update
# RUN apt-get install ca-certificates curl
RUN install -m 0755 -d /etc/apt/keyrings
RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
RUN chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
RUN  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
RUN apt-get update

# Install Docker Engine
RUN apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

############################################################################################
# OLD METHOD
############################################################################################
# Install Docker manually
#
#RUN apt-get -qq install -y ca-certificates \
#    iptables \
#    && rm -rf /var/lib/apt/lists/* \
#    && update-alternatives --set iptables /usr/sbin/iptables-legacy

#ENV DOCKER_CHANNEL=stable \
#    DOCKER_VERSION=26.1.4 \
#    DOCKER_COMPOSE_VERSION=v2.27.0 \
#    BUILDX_VERSION=v0.14.0

# Docker and buildx installation
# RUN set -eux; \
# 	arch="$(uname -m)"; \
# 	case "$arch" in \
# 		x86_64) dockerArch='x86_64' ; buildx_arch='linux-amd64' ;; \
# 		armhf) dockerArch='armel' ; buildx_arch='linux-arm-v6' ;; \
# 		armv7) dockerArch='armhf' ; buildx_arch='linux-arm-v7' ;; \
# 		aarch64) dockerArch='aarch64' ; buildx_arch='linux-arm64' ;; \
# 		*) echo >&2 "error: unsupported architecture ($arch)"; exit 1 ;;\
# 	esac; \
# 	\
# 	if ! wget -q -O docker.tgz "https://download.docker.com/linux/static/${DOCKER_CHANNEL}/${dockerArch}/docker-${DOCKER_VERSION}.tgz"; then \
# 		echo >&2 "error: failed to download 'docker-${DOCKER_VERSION}' from '${DOCKER_CHANNEL}' for '${dockerArch}'"; \
# 		exit 1; \
# 	fi; \
#     tar --extract --file docker.tgz --strip-components 1 --directory /usr/local/bin/; \
# 	rm docker.tgz; \
# 	if ! wget -q -O docker-buildx "https://github.com/docker/buildx/releases/download/${BUILDX_VERSION}/buildx-${BUILDX_VERSION}.${buildx_arch}"; then \
# 		echo >&2 "error: failed to download 'buildx-${BUILDX_VERSION}.${buildx_arch}'"; \
# 		exit 1; \
# 	fi; \
#     mkdir -p /usr/local/lib/docker/cli-plugins; \
#     chmod +x docker-buildx; \
#     mv docker-buildx /usr/local/lib/docker/cli-plugins/docker-buildx; \
#     dockerd --version; \
#     docker --version; \
#     docker buildx version

# Install Docker Compose
# RUN curl -s -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose \
# && chmod +x /usr/local/bin/docker-compose && docker-compose version

# Create a symlink to the Docker Compose binary for 'docker compose' command
# RUN ln -s /usr/local/bin/docker-compose /usr/local/lib/docker/cli-plugins/docker-compose

############################################################################################
# GitHub Runner
############################################################################################
# Save the GitHub runner version in an environment file
RUN echo "${RUNNER_VERSION}" > /runner_version.env

# Download and extract GitHub actions runner binaries
RUN cd /home/docker && mkdir actions-runner-linux-x64 && cd actions-runner-linux-x64 \
    && curl -s -O -L https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz \
    && tar xzf ./actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz \
    && rm -f ./actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz

# RUN cd /home/docker && mkdir actions-runner-linux-arm && cd actions-runner-linux-arm \
#     && curl -s -O -L https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-arm-${RUNNER_VERSION}.tar.gz \
#     && tar xzf ./actions-runner-linux-arm-${RUNNER_VERSION}.tar.gz \
#     && rm -f ./actions-runner-linux-arm-${RUNNER_VERSION}.tar.gz

# RUN cd /home/docker && mkdir actions-runner-linux-arm64 && cd actions-runner-linux-arm64 \
#     && curl -s -O -L https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-arm64-${RUNNER_VERSION}.tar.gz \
#     && tar xzf ./actions-runner-linux-arm64-${RUNNER_VERSION}.tar.gz \
#     && rm -f ./actions-runner-linux-arm64-${RUNNER_VERSION}.tar.gz

# Copy necessary scripts to the image
COPY ./build/dk-runner/scripts/start-docker.sh /usr/local/bin/start-docker.sh
COPY ./build/dk-runner/scripts/entrypoint.sh /usr/local/bin/entrypoint.sh
COPY ./build/dk-runner/scripts/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY ./build/dk-runner/scripts/logger.sh /opt/bash-utils/logger.sh
COPY ./build/dk-runner/scripts/daemon.json /etc/docker/daemon.json

# Make the scripts executable
RUN chmod +x /usr/local/bin/start-docker.sh /usr/local/bin/entrypoint.sh

# Modify the Header.tsx using sed and the value of GIT_COMMIT (default to 'unknown')
ARG GIT_COMMIT=unknown
RUN echo "GIT_COMMIT=$GIT_COMMIT" > /.env

# Copy healthcheck
COPY ./build/dk-runner/scripts/healthcheck.sh /healthcheck.sh
RUN chmod +x /healthcheck.sh

# My custom health check
# I'm calling /healthcheck.sh so my container will report 'healthy' instead of running
# --interval=30s: Docker will run the health check every 'interval'
# --timeout=10s: Wait 'timeout' for the health check to succeed.
# --start-period=3s: Wait time before first check. Gives the container some time to start up.
# --retries=3: Retry check 'retries' times before considering the container as unhealthy.
HEALTHCHECK --interval=30s --timeout=10s --start-period=3s --retries=3 \
  CMD /healthcheck.sh || exit $?

# Setup the volume for Docker
VOLUME /var/lib/docker

# Switch to 'docker' user
USER docker

# Define the entrypoint script
ENTRYPOINT ["entrypoint.sh"]
CMD ["bash"]
