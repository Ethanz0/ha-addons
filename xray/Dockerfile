# Base image pinned by tag and digest (Alpine 3.24, docker-base release 2026.11.0).
FROM ghcr.io/home-assistant/base:3.24-2026.11.0@sha256:58422480a299b16b6ea376c2167463206d430619ed02b40cd687c8bd6875519e

ARG BUILD_ARCH=aarch64
ARG BUILD_VERSION
# Xray release and the SHA2-256 of its Xray-linux-arm64-v8a.zip (from the release's .dgst file).
ARG XRAY_VERSION=26.10.31
ARG XRAY_SHA256_AARCH64=1811c8f1da0c3b6dc707ebaf1c8390e987ba39859a8f0a7aadd8526157f2ec8d

RUN set -eux; \
    test "${BUILD_ARCH}" = "aarch64"; \
    curl -fsSL -o /tmp/xray.zip \
      "https://github.com/XTLS/Xray-core/releases/download/v${XRAY_VERSION}/Xray-linux-arm64-v8a.zip"; \
    echo "${XRAY_SHA256_AARCH64}  /tmp/xray.zip" | sha256sum -c -; \
    mkdir -p /usr/local/share/xray; \
    unzip -o /tmp/xray.zip xray geoip.dat -d /tmp/xray; \
    install -m 0755 /tmp/xray/xray /usr/local/bin/xray; \
    install -m 0644 /tmp/xray/geoip.dat /usr/local/share/xray/geoip.dat; \
    rm -rf /tmp/xray /tmp/xray.zip; \
    xray version

ENV XRAY_LOCATION_ASSET=/usr/local/share/xray

COPY rootfs /

LABEL \
    io.hass.version="${BUILD_VERSION}" \
    io.hass.arch="${BUILD_ARCH}" \
    io.hass.type="app"
