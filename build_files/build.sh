#!/bin/sh
set -eu

# Void Linux image build script


echo "==> Verifying environment"
if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: this script must run as root" >&2
    exit 1
fi

# Install only the packages that are not already present. The base image
# already contains a few of them, and xbps-install treats those as an error.
install_packages() {
    for pkg in "$@"; do
        if xbps-query --property=pkgver "$pkg" >/dev/null 2>&1; then
            echo "  $pkg: already installed"
        else
            xbps-install -y "$pkg"
        fi
    done
}

# Apply the image's own files first: the fstab, runit hooks and dracut
# configuration must exist before packages are configured.
echo "==> Applying system files"
cp -a /ctx/system_files/. /

# Noctalia is distributed in the Universal Void repository. Add it before
# refreshing so the package is available to xbps-install below.
echo "==> Enabling the Universal Void repository"
mkdir -p /etc/xbps.d
cat > /etc/xbps.d/10-universalrepository.conf <<'EOF'
repository=https://universalrepo.pages.dev/void
EOF

# Do not unpack documentation and manual pages into the image in the first
# place. This keeps the image small and also applies to future upgrades.
mkdir -p /etc/xbps.d
cat > /etc/xbps.d/90-no-docs.conf <<'EOF'
noextract=/usr/share/man/*
noextract=/usr/share/doc/*
noextract=/usr/share/info/*
EOF

# Data-center network firmware is very large and is not needed to boot a
# desktop or laptop. Skipping it keeps the unpacked image under the 2 GB cap.
cat > /etc/xbps.d/90-no-bulk-firmware.conf <<'EOF'
noextract=/usr/lib/firmware/mellanox/*
noextract=/usr/lib/firmware/mrvl/prestera/*
EOF

echo "==> Importing the Universal Void repository key"
# The Universal repository is signed with its own RSA key. The first sync
# asks whether to trust it; pipe "y" so the build works without a terminal.
printf 'y\n' | xbps-install -S -y

echo "==> Updating XBPS"

# Update XBPS first, then refresh and upgrade packages.
xbps-install -Syu xbps
xbps-install -Syu

echo "==> Installing base system, kernel, graphics and initramfs generator"

install_packages \
    base-system \
    dash \
    dracut \
    linux \
    linux-firmware \
    linux-firmware-network \
    linux-firmware-amd \
    linux-firmware-intel \
    mesa \
    mesa-dri \
    tzdata \
    vulkan-loader

echo "==> Installing boot and filesystem tools"

install_packages \
    grub \
    grub-x86_64-efi \
    efibootmgr \
    btrfs-progs \
    gptfdisk

echo "==> Installing applications"

install_packages \
    dejavu-fonts-ttf \
    elinks \
    fastfetch \
    fish-shell \
    foot \
    fzf \
    gvfs \
    gvfs-mtp \
    gvfs-afc \
    mangowc \
    noctalia \
    ripgrep \
    tmux \
    yazi \
    zoxide

echo "==> Installing container tools"

install_packages \
    podman \
    crun \
    slirp4netns \
    fuse-overlayfs \
    shadow \
    opendoas

echo "==> Hardware Control"

install_packages \
    pipewire \
    libspa-bluetooth \
    alsa-pipewire \
    wireplumber \
    wireplumber-elogind \
    bluez \
    brightnessctl \
    dbus \
    elogind \
    pciutils \
    polkit \
    NetworkManager \
    usbmuxd \
    usbutils \
    udisks2 \
    dosfstools \
    exfatprogs \
    ntfs-3g \
    fuse3

echo "==> Configuring runit services"

service_dir=/etc/runit/runsvdir/default
mkdir -p "$service_dir"

for service in udevd dbus elogind polkitd NetworkManager usbmuxd; do
    if [ -d "/etc/sv/$service" ]; then
        ln -sfnT "/etc/sv/$service" "$service_dir/$service"
    else
        echo "ERROR: required runit service not found: $service" >&2
        exit 1
    fi
done

echo "==> Reconfiguring installed packages"
xbps-reconfigure -fa

# ESP mountpoint used by the deploy script and by /etc/fstab at boot.
mkdir -p /boot/efi

echo "==> Checking boot files"
if ! ls /boot/vmlinuz-* >/dev/null 2>&1; then
    echo "ERROR: no kernel found in /boot" >&2
    exit 1
fi

if ! ls /boot/initramfs-* >/dev/null 2>&1; then
    echo "ERROR: no initramfs found in /boot - reconfigure the kernel package" >&2
    exit 1
fi

# The root filesystem is Btrfs. If the initramfs cannot mount it, the image
# will not boot, so verify the storage drivers made it in during the build.
initramfs=$(find /boot -maxdepth 1 -name 'initramfs-*.img' -print -quit)
if ! command -v lsinitrd >/dev/null 2>&1; then
    echo "ERROR: lsinitrd not found - cannot verify the initramfs" >&2
    exit 1
fi
for module in btrfs.ko ahci.ko; do
    if ! lsinitrd "$initramfs" | grep -q "$module"; then
        echo "ERROR: initramfs is missing $module" >&2
        exit 1
    fi
done

echo "==> Cleaning package cache"
xbps-remove -yO
rm -rf /var/cache/xbps/*

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

# The image is UEFI-only; the BIOS GRUB modules are pure weight.
rm -rf /usr/lib/grub/i386-pc

echo "==> Removing optional bulk that is not needed to boot"
# Podman uses netavark by default; the legacy CNI plugin binaries are large.
rm -rf /usr/libexec/cni
rm -f /usr/bin/podman-remote

# Language sources, extra icon themes, GTK caches and hardware databases are
# not needed for boot and are recreated by packages if they are ever needed.
rm -rf /usr/share/i18n
rm -rf /usr/share/icons/Adwaita
rm -rf /usr/share/gtk-3.0 /usr/share/gtk-4.0
rm -rf /usr/share/misc
rm -rf /usr/share/libwacom /usr/share/hwdata /usr/share/licenses

# Generated caches, bundled installers and introspection data are recreated
# on demand and are not needed to boot.
rm -rf /usr/lib/python3.14/__pycache__
rm -rf /usr/lib/python3.14/ensurepip /usr/lib/python3.14/pydoc_data
rm -f /usr/lib/python3.14/site-packages/imobiledevice.a
rm -rf /usr/lib/girepository-1.0
rm -rf /usr/share/mime
rm -rf /usr/lib/gconv

# Git only needs Perl for its optional email helpers. The image does not need
# Perl to boot or to run any installed app, so drop it and its modules.
rm -rf /usr/lib/perl5 /usr/share/perl5
rm -f /usr/bin/perl /usr/bin/perl5.42.3 /usr/bin/cpan /usr/bin/perldoc /usr/bin/prove

echo "==> Void image customization complete"
