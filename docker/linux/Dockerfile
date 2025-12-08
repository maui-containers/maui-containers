# Set build arguments that need to be available before FROM
ARG DOTNET_VERSION=9.0

# Use .NET SDK base image with dynamic version
FROM mcr.microsoft.com/dotnet/sdk:${DOTNET_VERSION}-noble

ARG TARGETARCH

# Set build arguments
ARG JDK_MAJOR_VERSION=17
ARG ANDROID_SDK_API_LEVEL=35
ARG ANDROID_SDK_BUILD_TOOLS_VERSION=33.0.3
ARG ANDROID_SDK_CMDLINE_TOOLS_VERSION=13.0
ARG DOTNET_WORKLOADS_VERSION=9.0.203
ARG GITHUB_ACTIONS_RUNNER_VERSION=2.323.0

ENV JDK_MAJOR_VERSION=${JDK_MAJOR_VERSION}
ENV ANDROID_SDK_API_LEVEL=${ANDROID_SDK_API_LEVEL}
ENV ANDROID_SDK_BUILD_TOOLS_VERSION=${ANDROID_SDK_BUILD_TOOLS_VERSION}
ENV ANDROID_SDK_CMDLINE_TOOLS_VERSION=${ANDROID_SDK_CMDLINE_TOOLS_VERSION}
ENV DOTNET_VERSION=${DOTNET_VERSION}
ENV DOTNET_WORKLOADS_VERSION=${DOTNET_WORKLOADS_VERSION}
ENV GITHUB_ACTIONS_RUNNER_VERSION=${GITHUB_ACTIONS_RUNNER_VERSION}

ENV INIT_PWSH_SCRIPT="/config/init.ps1"
ENV INIT_BASH_SCRIPT="/config/init.sh"

# GitHub Actions Runner environment variables
ENV GITHUB_ORG=""
ENV GITHUB_REPO=""
ENV GITHUB_TOKEN=""
ENV RUNNER_NAME_PREFIX="maui-runner"
ENV RANDOM_RUNNER_SUFFIX=""
ENV RUNNER_GROUP=""
ENV RUNNER_WORKDIR=""
ENV LABELS=""
ENV DISABLE_AUTO_UPDATE=""
ENV NO_DEFAULT_LABELS=""
ENV EPHEMERAL=""

# Gitea Actions Runner environment variables
ENV GITEA_INSTANCE_URL=""
ENV GITEA_RUNNER_TOKEN=""
ENV GITEA_RUNNER_NAME=""
ENV GITEA_RUNNER_NAME_PREFIX="gitea-runner"
ENV GITEA_RUNNER_LABELS="maui,linux,amd64"

# Set core environment variables
ENV ANDROID_HOME=/home/mauiusr/android-sdk \
    ANDROID_SDK_ROOT=/home/mauiusr/android-sdk \
    DEBIAN_FRONTEND=noninteractive \
    LOG_PATH=/logs \
    JAVA_HOME="/usr/lib/jvm/msopenjdk-${JDK_MAJOR_VERSION}-${TARGETARCH}"

# Create log directory
RUN mkdir ${LOG_PATH}

# Install base packages
RUN apt-get update && apt-get install -y \
    sudo \
    curl \
    ca-certificates \
    gnupg \
    udev \
    tzdata \
    git \
    lsb-release \
    wget \
    apt-transport-https software-properties-common \
    unzip \
    tree \
    socat supervisor \
    jq build-essential libssl-dev libffi-dev python3 python3-venv python3-dev python3-pip \
    libkrb5-3 zlib1g \
    && apt autoremove -y \
    && apt clean all \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js and npm
RUN curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - \
    && apt-get install -y nodejs \
    && apt autoremove -y \
    && apt clean all \
    && rm -rf /var/lib/apt/lists/*

# Create mauiusr to run things under
ARG USER_PASS=secret
RUN groupadd mauiusr \
         --gid 1401 \
  && useradd mauiusr \
         --uid 1400 \
         --gid 1401 \
         --create-home \
         --shell /bin/bash \
  && usermod -aG sudo mauiusr \
  && echo mauiusr:${USER_PASS} | chpasswd \
  && echo 'mauiusr ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers

# Install Microsoft Packages: MS OpenJDK and Powershell
RUN ubuntu_release=$(lsb_release -rs) \
    && wget "https://packages.microsoft.com/config/ubuntu/${ubuntu_release}/packages-microsoft-prod.deb" -O packages-microsoft-prod.deb \
    && dpkg -i packages-microsoft-prod.deb \
    && rm packages-microsoft-prod.deb \
    && apt-get update \
    && apt-get install -y msopenjdk-${JDK_MAJOR_VERSION} powershell \
    && apt autoremove -y \
    && apt clean all \
    && rm -rf /var/lib/apt/lists/*

# Install the Workloads
RUN dotnet workload install maui-android wasm-tools --version ${DOTNET_WORKLOADS_VERSION}

# Fix permissions on the log directory
RUN chown -R 1400:1401 ${LOG_PATH}

# Switch to mauiusr
USER 1400:1401

# Install Android SDK Tool & AppleDev Tool
RUN dotnet tool install -g AndroidSdk.Tool
RUN dotnet tool install -g AppleDev.Tools

ENV PATH="/home/mauiusr/.dotnet/tools:${PATH}"

# Set working directory
WORKDIR /home/mauiusr

# Copy the init script and runner script with correct ownership and permissions
COPY --chown=1400:1401 --chmod=755 scripts/init.sh /home/mauiusr/init.sh
COPY --chown=1400:1401 --chmod=755 scripts/runner.sh /home/mauiusr/runner.sh
COPY --chown=1400:1401 --chmod=755 scripts/entrypoint.sh /home/mauiusr/entrypoint.sh

# Install and configure Android SDK
RUN android sdk download --home="${ANDROID_HOME}"

RUN android sdk install \
    --package="platform-tools" \
    --package="build-tools;${ANDROID_SDK_BUILD_TOOLS_VERSION}" \
    --package="cmdline-tools;${ANDROID_SDK_CMDLINE_TOOLS_VERSION}" \
    --package="platforms;android-${ANDROID_SDK_API_LEVEL}"

RUN android sdk info --format=json > /home/mauiusr/sdk_info.json
RUN android sdk list --installed --format=json > /home/mauiusr/sdk_list.json

# Accept Android Licenses
RUN android sdk accept-licenses --force --home="${ANDROID_HOME}"

# Copy software manifest generation scripts
USER root
COPY scripts/generate-software-manifest.json.sh /tmp/generate-software-manifest.json.sh
COPY scripts/generate-software-manifest-spdx.sh /tmp/generate-software-manifest-spdx.sh
COPY scripts/generate-software-manifest-cyclonedx.sh /tmp/generate-software-manifest-cyclonedx.sh
RUN chmod +x /tmp/generate-software-manifest.json.sh \
    && chmod +x /tmp/generate-software-manifest-spdx.sh \
    && chmod +x /tmp/generate-software-manifest-cyclonedx.sh

# Generate software manifests (JSON, SPDX, CycloneDX)
USER 1400:1401
RUN mkdir -p /usr/local/share || true
RUN /tmp/generate-software-manifest.json.sh /usr/local/share/installed-software.json || echo "JSON manifest generation failed"
RUN /tmp/generate-software-manifest-spdx.sh /usr/local/share/installed-software.json /usr/local/share/installed-software.spdx.json || echo "SPDX manifest generation failed"
RUN /tmp/generate-software-manifest-cyclonedx.sh /usr/local/share/installed-software.json /usr/local/share/installed-software.cdx.json || echo "CycloneDX manifest generation failed"

# Install GitHub Actions Runner
RUN mkdir actions-runner
WORKDIR /home/mauiusr/actions-runner
RUN curl -o actions-runner-linux.tar.gz -L https://github.com/actions/runner/releases/download/v${GITHUB_ACTIONS_RUNNER_VERSION}/actions-runner-linux-x64-${GITHUB_ACTIONS_RUNNER_VERSION}.tar.gz
RUN tar xzf ./actions-runner-linux.tar.gz
RUN rm -rf ./actions-runner-linux.tar.gz

# Install Gitea Actions Runner
WORKDIR /home/mauiusr
RUN mkdir gitea-runner
WORKDIR /home/mauiusr/gitea-runner
RUN LATEST_VERSION=$(curl -fsSL https://gitea.com/api/v1/repos/gitea/act_runner/releases | jq -r '.[0].tag_name') && \
    VERSION_NO_PREFIX=${LATEST_VERSION#v} && \
    DOWNLOAD_URL="https://gitea.com/gitea/act_runner/releases/download/${LATEST_VERSION}/act_runner-${VERSION_NO_PREFIX}-linux-amd64" && \
    echo "Downloading act_runner version: ${LATEST_VERSION} from ${DOWNLOAD_URL}" && \
    curl -fsSL "${DOWNLOAD_URL}" -o /home/mauiusr/gitea-runner/act_runner && \
    chmod +x /home/mauiusr/gitea-runner/act_runner

# Return to home directory
WORKDIR /home/mauiusr

# Use ENTRYPOINT to start runners in background, CMD is user-overridable
ENTRYPOINT ["/home/mauiusr/entrypoint.sh"]
CMD ["tail", "-f", "/dev/null"]
