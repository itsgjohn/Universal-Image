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

# dracut must be installed BEFORE the kernel: Void registers initramfs
# generators as XBPS alternatives, so the kernel install hook needs the
# generator present at install time.
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

# gvfs + gvfs-afc (iPhone) + gvfs-mtp (Android): automount requirement.
# There is no gvfs-fuse package in Void - the FUSE backend ships in main gvfs.
xbps-install -y \
    elinks \
    foot \
    fastfetch \
    fish-shell \
    fzf \
    ripgrep \
    tmux \
    zoxide \
    yazi \
    gvfs \
    gvfs-mtp \
    gvfs-afc \

echo "==> Installing container tools"

xbps-install -y \
    podman \
    crun \
    slirp4netns \
    fuse-overlayfs \
    shadow

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
