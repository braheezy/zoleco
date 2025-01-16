# Use the Microsoft container for better devcontainer integration
FROM mcr.microsoft.com/vscode/devcontainers/base:debian

# Install required tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    curl \
    git \
    wget \
    build-essential \
    libssl-dev \
    pkg-config \
 && rm -rf /var/lib/apt/lists/*

RUN curl -L https://github.com/marler8997/zigup/releases/download/v2025_01_02/zigup-aarch64-linux.tar.gz | tar xz -C /usr/bin

RUN zigup 0.14.0-dev.2577+271452d22

RUN wget -q https://builds.zigtools.org/zls-linux-aarch64-0.14.0-dev.345+f7888fc.tar.xz -O - | tar xJ -C /usr/bin
