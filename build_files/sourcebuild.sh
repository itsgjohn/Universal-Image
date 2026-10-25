#!/bin/sh
set -eu

NOCTALIA_TAG=v5.2.0

echo "==> Updating XBPS"
xbps-install -Syu xbps
xbps-install -Syu

echo "==> Installing build dependencies"
xbps-install -y \
    base-devel git meson ninja pkg-config \
    wayland-devel wayland-protocols libepoxy-devel \
    MesaLib-devel libglvnd-devel cairo-devel \
    pango-devel fontconfig-devel freetype-devel \
    harfbuzz-devel libxkbcommon-devel \
    pipewire-devel wireplumber-devel \
    libsecret-devel libsodium-devel libcurl-devel \
    pam-devel libwebp-devel libjxl-devel libsndfile-devel \
    basu-devel sdbus-c++-devel libmd4c-devel \
    tomlplusplus-devel libical-devel json-c++ stb \
    polkit-devel librsvg-devel libqalculate-devel \
    libxml2-devel jemalloc-devel

echo "==> Downloading Noctalia ${NOCTALIA_TAG}"
mkdir -p /build /out
cd /build

git clone --depth 1 \
    --branch "$NOCTALIA_TAG" \
    https://github.com/noctalia-dev/noctalia.git

cd noctalia

echo "==> Building Noctalia"
meson setup build \
    --prefix=/usr \
    --buildtype=release \
    -Dtests=disabled

ninja -C build

echo "==> Staging Noctalia for the final image"
DESTDIR=/out meson install -C build

echo "==> Builder stage complete"