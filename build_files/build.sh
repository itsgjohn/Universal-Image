#!/usr/bin/env bash
set -Eeuo pipefail

echo "==> Updating XBPS"

# XBPS must be updated in its own transaction.
xbps-install -Suy xbps
xbps-install -uy

echo "==> Installing base system, kernel and graphics"

xbps-install -y \
    base-system \
    linux \
    linux-headers \
    linux-firmware \
    linux-firmware-network \
    linux-firmware-amd \
    linux-firmware-intel \
    mesa \
    mesa-dri \
    vulkan-loader \
    mesa-vulkan-radeon \
    mesa-vulkan-intel

echo "==> Installing boot and filesystem tools"

xbps-install -y \
    grub \
    grub-x86_64-efi \
    efibootmgr \
    btrfs-progs \
    dracut

echo "==> Installing container tools"

xbps-install -y \
    distrobox \
    crun \
    slirp4netns \
    fuse-overlayfs \
    shadow

echo "==> Installing session and networking components"

xbps-install -y \
    dbus \
    elogind \
    polkit \
    seatd \
    NetworkManager

echo "==> Enabling runit services"

service_dir=/etc/runit/runsvdir/default
mkdir -p "$service_dir"

for service in dbus elogind polkitd NetworkManager; do
    if [[ -d "/etc/sv/$service" ]]; then
        ln -sfn "/etc/sv/$service" "$service_dir/$service"
    else
        echo "ERROR: Missing runit service: $service" >&2
        exit 1
    fi
done

echo "==> Reconfiguring installed packages"

xbps-reconfigure -fa

echo "==> Cleaning package cache"

xbps-remove -yO
rm -rf /var/cache/xbps/*

echo "==> Void image customization complete"
