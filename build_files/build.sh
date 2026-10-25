#!/bin/sh
set -eu

# Void Linux image build script


echo "==> Verifying environment"
if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: this script must run as root" >&2
    exit 1
fi

echo "==> Updating XBPS"

# Update XBPS first, then refresh and upgrade packages.
xbps-install -Syu xbps
xbps-install -Syu

echo "==> Installing base system, kernel, graphics and initramfs generator"

xbps-install -y \
    base-system \
    dracut \
    linux \
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
    btrfs-progs

echo "==> Installing applications"

xbps-install -y \
    bash \
    elinks \
    fastfetch \
    fish-shell \
    foot \
    fzf \
    gvfs \
    gvfs-mtp \
    gvfs-afc \
    mangowc \
    ripgrep \
    tmux \
    yazi \
    zoxide 

echo "==> Installing container tools"

xbps-install -y \
    podman \
    crun \
    slirp4netns \
    fuse-overlayfs \
    shadow

echo "==> Installing Noctalia runtime libraries"

xbps-install -y \
    sdbus-c++ \
    libqalculate \
    libical \
    tomlplusplus \
    libmd4c \
    jemalloc

echo "==> Hardware Control"

xbps-install -y \
    pipewire \
    libspa-bluetooth \
    alsa-pipewire \
    wireplumber \
    wireplumber-elogind \
    bluez \
    brightnessctl \
    dbus \
    elogind \
    polkit \
    NetworkManager


echo "==> Configuring runit services"

service_dir=/etc/runit/runsvdir/default
mkdir -p "$service_dir"

for service in dbus elogind polkitd NetworkManager; do
    if [ -d "/etc/sv/$service" ]; then
        ln -sfnT "/etc/sv/$service" "$service_dir/$service"
    else
        echo "ERROR: required runit service not found: $service" >&2
        exit 1
    fi
done

echo "==> Reconfiguring installed packages"
xbps-reconfigure -fa

echo "==> Checking initramfs"
if [ -d /boot ] && ! ls /boot/initramfs-* >/dev/null 2>&1; then
    echo "WARNING: no initramfs found in /boot - reconfigure the kernel package" >&2
fi

echo "==> Cleaning package cache"
xbps-remove -yO
rm -rf /var/cache/xbps/*

echo "==> Stopping documentation from being (re)installed on upgrade"

mkdir -p /etc/xbps.d
cat > /etc/xbps.d/90-no-docs.conf <<'EOF'
noextract=/usr/share/man/*
noextract=/usr/share/doc/*
noextract=/usr/share/info/*
EOF

echo "==> Removing documentation and unnecessary locales"

rm -rf /usr/share/man/*
rm -rf /usr/share/info/*
rm -rf /usr/share/doc/*

# Keep every English locale (en, en_US, en_GB, en@latin, ...); remove the rest.
if [ -d /usr/share/locale ]; then
    find /usr/share/locale -mindepth 1 -maxdepth 1 \
        ! -name 'en*' \
        -exec rm -rf {} +
fi

echo "==> Void image customization complete"
