
#!/bin/sh
set -eu

echo "==> Updating XBPS"

# Update XBPS first, then refresh and upgrade packages.
xbps-install -Syu xbps
xbps-install -Syu

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
    podman \
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

echo "==> Configuring runit services"

service_dir=/etc/runit/runsvdir/default
mkdir -p "$service_dir"

for service in dbus elogind polkitd NetworkManager; do
    if [ -d "/etc/sv/$service" ]; then
        ln -sfn "/etc/sv/$service" "$service_dir/$service"
    else
        echo "WARNING: runit service not found: $service" >&2
    fi
done

echo "==> Reconfiguring installed packages"
xbps-reconfigure -fa

echo "==> Cleaning package cache"
xbps-remove -yO
rm -rf /var/cache/xbps/*

echo "==> Void image customization complete"
