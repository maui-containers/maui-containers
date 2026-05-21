# Set build arguments that need to be available before FROM
ARG DOTNET_VERSION=10.0
ARG DOTNET_SDK_IMAGE_TAG=10.0-resolute

# Use .NET SDK base image with dynamic version
FROM mcr.microsoft.com/dotnet/sdk:${DOTNET_SDK_IMAGE_TAG}

ARG TARGETARCH

# Set build arguments
ARG DOTNET_VERSION=10.0
ARG DOTNET_SDK_IMAGE_TAG=10.0-resolute
ARG JDK_MAJOR_VERSION=21
ARG ANDROID_SDK_API_LEVEL=35
ARG ANDROID_SDK_BUILD_TOOLS_VERSION=33.0.3
ARG ANDROID_SDK_CMDLINE_TOOLS_VERSION=13.0
ARG DOTNET_WORKLOADS_VERSION=10.0.300.3

ENV JDK_MAJOR_VERSION=${JDK_MAJOR_VERSION}
ENV ANDROID_SDK_API_LEVEL=${ANDROID_SDK_API_LEVEL}
ENV ANDROID_SDK_BUILD_TOOLS_VERSION=${ANDROID_SDK_BUILD_TOOLS_VERSION}
ENV ANDROID_SDK_CMDLINE_TOOLS_VERSION=${ANDROID_SDK_CMDLINE_TOOLS_VERSION}
ENV DOTNET_VERSION=${DOTNET_VERSION}
ENV DOTNET_WORKLOADS_VERSION=${DOTNET_WORKLOADS_VERSION}

# OCI Image labels for registry metadata and discoverability
LABEL org.opencontainers.image.title="MAUI Linux Development Container" \
      org.opencontainers.image.description=".NET MAUI development environment for Linux with Android SDK" \
      org.opencontainers.image.vendor="MAUI Containers" \
      org.opencontainers.image.source="https://github.com/maui-containers/maui-containers" \
      org.opencontainers.image.documentation="https://github.com/maui-containers/maui-containers/blob/main/README.md" \
      org.opencontainers.image.url="https://github.com/maui-containers/maui-containers" \
      org.opencontainers.image.licenses="MIT" \
      dev.maui-containers.dotnet-version="${DOTNET_VERSION}" \
      dev.maui-containers.workload-set-version="${DOTNET_WORKLOADS_VERSION}" \
      dev.maui-containers.android-api-level="${ANDROID_SDK_API_LEVEL}" \
      dev.maui-containers.android-build-tools="${ANDROID_SDK_BUILD_TOOLS_VERSION}" \
      dev.maui-containers.android-cmdline-tools="${ANDROID_SDK_CMDLINE_TOOLS_VERSION}" \
      dev.maui-containers.jdk-version="${JDK_MAJOR_VERSION}"

ENV INIT_PWSH_SCRIPT="/config/init.ps1"
ENV INIT_BASH_SCRIPT="/config/init.sh"

# Set core environment variables
ENV ANDROID_HOME=/home/mauiusr/android-sdk \
    ANDROID_SDK_ROOT=/home/mauiusr/android-sdk \
    DEBIAN_FRONTEND=noninteractive \
    LOG_PATH=/logs \
    JAVA_HOME="/usr/lib/jvm/maui-openjdk-${JDK_MAJOR_VERSION}"

# .NET CLI environment — make the SDK tree user-writable so CI (running as
# mauiusr) can install/update workloads and global tools without sudo. The SDK
# itself stays at the default location from the base image; we just chown it
# to mauiusr below. Pin NUGET_PACKAGES under $HOME so a root-owned cache can
# never get layered in from a future base image.
ENV DOTNET_ROOT=/usr/share/dotnet \
    DOTNET_INSTALL_DIR=/usr/share/dotnet \
    DOTNET_MULTILEVEL_LOOKUP=0 \
    DOTNET_CLI_TELEMETRY_OPTOUT=1 \
    DOTNET_NOLOGO=1 \
    DOTNET_SKIP_FIRST_TIME_EXPERIENCE=1 \
    NUGET_PACKAGES=/home/mauiusr/.nuget/packages

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

# Install Java and PowerShell. Resolute images can publish before every
# Microsoft apt package is available, so use distro OpenJDK and the official
# PowerShell tarball as fallbacks.
RUN ubuntu_release=$(lsb_release -rs) \
    && wget "https://packages.microsoft.com/config/ubuntu/${ubuntu_release}/packages-microsoft-prod.deb" -O packages-microsoft-prod.deb \
    && dpkg -i packages-microsoft-prod.deb \
    && rm packages-microsoft-prod.deb \
    && apt-get update \
    && if apt-cache show "msopenjdk-${JDK_MAJOR_VERSION}" >/dev/null 2>&1; then \
        jdk_package="msopenjdk-${JDK_MAJOR_VERSION}"; \
    else \
        jdk_package="openjdk-${JDK_MAJOR_VERSION}-jdk"; \
    fi \
    && apt-get install -y "$jdk_package" \
    && javac_path="$(readlink -f "$(command -v javac)")" \
    && actual_java_home="$(dirname "$(dirname "$javac_path")")" \
    && ln -sfn "$actual_java_home" "$JAVA_HOME" \
    && if apt-cache show powershell >/dev/null 2>&1; then \
        apt-get install -y powershell; \
    else \
        pwsh_arch="$TARGETARCH"; \
        if [ "$pwsh_arch" = "amd64" ]; then pwsh_arch="x64"; fi; \
        pwsh_version="$(curl -fsSL https://api.github.com/repos/PowerShell/PowerShell/releases/latest | sed -n 's/.*"tag_name": "v\([^"]*\)".*/\1/p' | head -1)"; \
        test -n "$pwsh_version"; \
        mkdir -p /opt/microsoft/powershell/7; \
        curl -fsSL "https://github.com/PowerShell/PowerShell/releases/download/v${pwsh_version}/powershell-${pwsh_version}-linux-${pwsh_arch}.tar.gz" | tar zxf - -C /opt/microsoft/powershell/7; \
        chmod +x /opt/microsoft/powershell/7/pwsh; \
        ln -sf /opt/microsoft/powershell/7/pwsh /usr/bin/pwsh; \
    fi \
    && apt autoremove -y \
    && apt clean all \
    && rm -rf /var/lib/apt/lists/*

# Install the Workloads as mauiusr so the non-root user can later update them
# without sudo. This requires the SDK tree to be user-writable.
RUN chown -R 1400:1401 /usr/share/dotnet \
    && mkdir -p /home/mauiusr/.nuget/packages \
    && chown -R 1400:1401 /home/mauiusr/.nuget

# Fix permissions on the log directory
RUN chown -R 1400:1401 ${LOG_PATH}

# Switch to mauiusr
USER 1400:1401

# Install MAUI workloads (runs as mauiusr into the now-user-owned SDK tree)
RUN dotnet workload install maui-android wasm-tools --version ${DOTNET_WORKLOADS_VERSION}

# Install Android SDK Tool & AppleDev Tool
RUN dotnet tool install -g AndroidSdk.Tool
RUN dotnet tool install -g AppleDev.Tools

ENV PATH="/home/mauiusr/.dotnet/tools:${PATH}"

# Set working directory
WORKDIR /home/mauiusr

# Copy the init and entrypoint scripts with correct ownership and permissions
COPY --chown=1400:1401 --chmod=755 scripts/init.sh /home/mauiusr/init.sh
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

# Return to home directory
WORKDIR /home/mauiusr

# Use ENTRYPOINT to run initialization hooks, CMD is user-overridable
ENTRYPOINT ["/home/mauiusr/entrypoint.sh"]
CMD ["tail", "-f", "/dev/null"]
