# Test Image for Android Emulator and Appium Testing
#
# This image is designed for running Android emulators and Appium tests.
# It does NOT include .NET MAUI workloads since no MAUI building happens on this image.
# The primary purpose is to provide a quick emulator for the specified API level.
#
# Key Features:
# - Android Emulator for the specified API level (via ANDROID_SDK_API_LEVEL build arg)
# - Appium Server with UIAutomator2 driver pre-installed
# - Automatic service startup on container launch
# - Support for nested virtualization (requires --device /dev/kvm)

# Set .NET version build arg (supports 9.0, 10.0, etc.)
ARG DOTNET_VERSION=9.0

# Use .NET SDK base image
FROM mcr.microsoft.com/dotnet/sdk:${DOTNET_VERSION}-noble AS env-builder

# Install Android SDK Tool
RUN dotnet tool install -g AndroidSdk.Tool

# Start the main image
FROM mcr.microsoft.com/dotnet/runtime:${DOTNET_VERSION}-noble

# Set build arguments
ARG TARGETARCH

ARG JDK_MAJOR_VERSION=17
ARG ANDROID_SDK_API_LEVEL=35
ARG ANDROID_SDK_BUILD_TOOLS_VERSION=33.0.3
ARG ANDROID_SDK_CMDLINE_TOOLS_VERSION=13.0
ARG ANDROID_SDK_AVD_DEVICE_TYPE="Nexus 5X"
ARG ANDROID_SDK_AVD_SYSTEM_IMAGE_TYPE=google_apis
ARG APPIUM_VERSION=2.0.12
ARG APPIUM_UIAUTOMATOR2_DRIVER_VERSION=3.0.8
ARG ANDROID_SDK_AVD_HOST_ABI=x86_64

ENV JDK_MAJOR_VERSION=${JDK_MAJOR_VERSION}
ENV ANDROID_SDK_API_LEVEL=${ANDROID_SDK_API_LEVEL}
ENV ANDROID_SDK_BUILD_TOOLS_VERSION=${ANDROID_SDK_BUILD_TOOLS_VERSION}
ENV ANDROID_SDK_CMDLINE_TOOLS_VERSION=${ANDROID_SDK_CMDLINE_TOOLS_VERSION}
ENV ANDROID_SDK_AVD_DEVICE_TYPE=${ANDROID_SDK_AVD_DEVICE_TYPE}
ENV ANDROID_SDK_AVD_SYSTEM_IMAGE_TYPE=${ANDROID_SDK_AVD_SYSTEM_IMAGE_TYPE}
ENV APPIUM_VERSION=${APPIUM_VERSION}
ENV APPIUM_UIAUTOMATOR2_DRIVER_VERSION=${APPIUM_UIAUTOMATOR2_DRIVER_VERSION}
ENV ANDROID_SDK_AVD_HOST_ABI=${ANDROID_SDK_AVD_HOST_ABI}

ENV INIT_PWSH_SCRIPT="/config/init.ps1"
ENV INIT_BASH_SCRIPT="/config/init.sh"

# Not needed currently as linux android sdk doesn't support arm64 emulators
# Generate environment variables
#RUN if [ "$TARGETARCH" = "arm64" ]; then \
#        echo 'export ANDROID_SDK_AVD_HOST_ABI="arm64-v8a"' > /etc/environment ; \
#    else \
#        echo 'export ANDROID_SDK_AVD_HOST_ABI="x86_64"' > /etc/environment ; \
#    fi

# Set core environment variables
ENV NODE_VERSION=22.x \
    ANDROID_HOME=/home/mauiusr/android-sdk \
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
    xvfb \
    git \
    lsb-release \
    wget \
    apt-transport-https software-properties-common \
    unzip \
    cpu-checker \
    ffmpeg \
    tree \
    qemu-kvm qemu-utils bridge-utils libvirt-daemon-system libvirt-daemon qemu-system virt-manager virtinst libvirt-clients \
    socat supervisor \
    && apt autoremove -y \
    && apt clean all \
    && rm -rf /var/lib/apt/lists/*

# Create mauiusr to run things under
ARG USER_PASS=secret
RUN groupadd mauiusr \
         --gid 1401 \
  #&& groupadd kvm \
  #       --gid 994 \
  && useradd mauiusr \
         --uid 1400 \
         --gid 1401 \
         --create-home \
         --shell /bin/bash \
  && usermod -aG sudo mauiusr \
  && usermod -aG kvm mauiusr \
  && echo mauiusr:${USER_PASS} | chpasswd \
  && echo 'mauiusr ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers

# Copy .NET tools and environment variables
RUN mkdir -p /home/mauiusr/.dotnet/tools && \
    chown -R 1400:1401 /home/mauiusr/.dotnet
COPY --from=env-builder /root/.dotnet/tools/ /home/mauiusr/.dotnet/tools/

# Add .NET tools to PATH and fix permissions
RUN chmod -R +x /home/mauiusr/.dotnet/tools/* && \
    chown -R 1400:1401 /home/mauiusr/.dotnet
ENV PATH="/home/mauiusr/.dotnet/tools:${PATH}"

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

# Install Node.js and npm
RUN curl -sL https://deb.nodesource.com/setup_${NODE_VERSION} | bash -
RUN apt-get -qqy install nodejs
RUN npm install -g npm

# Install Appium
RUN npm install -g appium@${APPIUM_VERSION}
RUN chown -R 1400:1401 /usr/lib/node_modules/appium

# Fix permissions on the log directory
RUN chown -R 1400:1401 ${LOG_PATH}

# Switch to mauiusr
USER 1400:1401

# Set working directory
WORKDIR /home/mauiusr

# Copy the Supervisor configuration file for running the emulator and Appium
COPY scripts/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY scripts/emulator.sh /home/mauiusr/emulator.sh
COPY scripts/appium.sh /home/mauiusr/appium.sh
COPY scripts/androidportforward.sh /home/mauiusr/androidportforward.sh
COPY scripts/init.sh /home/mauiusr/init.sh

# Install appium UIautomator2 driver
RUN appium driver install uiautomator2@${APPIUM_UIAUTOMATOR2_DRIVER_VERSION}

# Install and configure Android SDK
RUN android sdk download --home="${ANDROID_HOME}"

RUN android sdk install \
    --package="platform-tools" \
    --package="build-tools;${ANDROID_SDK_BUILD_TOOLS_VERSION}" \
    --package="cmdline-tools;${ANDROID_SDK_CMDLINE_TOOLS_VERSION}" \
    --package="emulator" \
    --package="platforms;android-${ANDROID_SDK_API_LEVEL}" \
    --package="system-images;android-${ANDROID_SDK_API_LEVEL};${ANDROID_SDK_AVD_SYSTEM_IMAGE_TYPE};${ANDROID_SDK_AVD_HOST_ABI}"

RUN android sdk info --format=json > /home/mauiusr/sdk_info.json
RUN android sdk list --installed --format=json > /home/mauiusr/sdk_list.json

# Accept Android Licenses
RUN android sdk accept-licenses --force --home="${ANDROID_HOME}"

# Create Android Virtual Device
RUN android avd create \
    --name="Emulator_${ANDROID_SDK_API_LEVEL}" \
    --sdk="system-images;android-${ANDROID_SDK_API_LEVEL};${ANDROID_SDK_AVD_SYSTEM_IMAGE_TYPE};${ANDROID_SDK_AVD_HOST_ABI}" \
    --device="${ANDROID_SDK_AVD_DEVICE_TYPE}" \
    --force

# Expose ports for Appium, Android emulator, ADB, and GRPC
EXPOSE 4723 5554 5555 8554

# Default command
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]