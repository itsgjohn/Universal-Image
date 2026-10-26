#!/bin/sh
set -eu

trap 'rc=$?; [ "$rc" -eq 0 ] || echo "info.sh failed (exit $rc)" >&2' EXIT

TIMEZONE="${TIMEZONE:-UTC}"

# require <test args...>: abort the build if the test fails
require() {
    "$@" || { echo "ERROR: check failed: $*" >&2; exit 1; }
}

echo "==> Applying system files"
cp -a /ctx/system_files/. /
chmod 0755 /usr/bin/acct
chmod 0400 /etc/doas.conf

echo "==> Runit: keep the root read-only"
fs=/etc/runit/core-services/03-filesystems.sh

sed -i \
    -e '/msg "Mounting rootfs read-write..."/d' \
    -e '\|LIBMOUNT_FORCE_MOUNT2=always mount -o remount,rw /|d' \
    "$fs"

if grep -q 'remount,rw' "$fs"; then
    echo "ERROR: ${fs} still remounts / read-write" >&2
    exit 1
fi

# runsvchdir rewrites /etc/runit/runsvdir/current, which is read-only now.
ln -sfnT default /etc/runit/runsvdir/current
sed -i 's|^runsvchdir "\${runlevel}"|# runsvchdir disabled: /etc is read-only, "current" is fixed to "default"|' /etc/runit/2

if grep -q '^runsvchdir' /etc/runit/2; then
    echo "ERROR: /etc/runit/2 still calls runsvchdir" >&2
    exit 1
fi

echo "==> Moving writable state into /var (persistent @var)"
mkdir -p /etc/NetworkManager /var/lib/dbus
install -dm700 /var/lib/NetworkManager/system-connections /var/roothome
install -dm755 /var/usrlocal /var/opt /var/srv

# Never ship a machine-id: every machine generates its own on first boot.
rm -f /etc/machine-id /var/lib/dbus/machine-id
ln -sfn /var/lib/dbus/machine-id /etc/machine-id
ln -sfn /run/NetworkManager/resolv.conf /etc/resolv.conf
rm -rf /etc/NetworkManager/system-connections
ln -sfnT /var/lib/NetworkManager/system-connections /etc/NetworkManager/system-connections
ln -sfn "/usr/share/zoneinfo/${TIMEZONE}" /etc/localtime

# Directories that live on the read-only root by default
cp -a /root/. /var/roothome/ 2>/dev/null || true
rm -rf /root /usr/local /opt /srv
ln -sfn var/roothome /root
ln -sfn ../var/usrlocal /usr/local
ln -sfn var/opt /opt
ln -sfn var/srv /srv

echo "==> Moving the xbps database into /usr"
rm -rf /usr/share/xbps-db
mv /var/db/xbps /usr/share/xbps-db
ln -sfn /usr/share/xbps-db /var/db/xbps
rm -rf /var/cache/xbps/*

echo "==> Locking root (accounts are created at deploy time)"
passwd -l root
echo "==> Runit: moving supervise state into /var"

# runsv creates supervise/{lock,control,ok,status} inside the service dir.
# /etc is read-only, so every service gets a supervise symlink pointing into
# /var; runsv handles a symlinked supervise/ itself (mkdir fails, it readlink()s
# the name and mkdir()s the target instead).
for d in /etc/sv/*; do
    [ -d "$d" ] || continue
    n=${d##*/}
    install -dm700 "/var/sv/$n" "/var/sv/$n/log"
    ln -sfnT "/var/sv/$n/supervise" "$d/supervise"
    if [ -d "$d/log" ]; then
        ln -sfnT "/var/sv/$n/log/supervise" "$d/log/supervise"
    fi
done


echo "==> Snapshotting /var as the seed for @var"
rm -rf /usr/share/factory/var
mkdir -p /usr/share/factory

# Drop build-time and machine-specific state before seeding.
rm -rf /var/cache/* /var/tmp/* /var/log/* /var/lib/seedrng

cp -a /var /usr/share/factory/var

# The image's own /var is shadowed by the @var subvolume at every boot, so it
# is pure weight inside the image.
rm -rf /var/* || true

ldconfig

echo "==> Sanity checks"
require test -L /etc/machine-id
require test -L /etc/resolv.conf
require test -L /etc/localtime
require test -e /etc/localtime
require test -s /etc/hostname
require test -s /etc/fstab
require test -d /usr/share/factory/var
require test -L /usr/share/factory/var/db/xbps
require test -x /usr/bin/acct
require test -x /usr/bin/doas

# Every service must have a writable supervise target, or it dies at boot.
for d in /etc/sv/*; do
    require test -L "$d/supervise"
    if [ -d "$d/log" ]; then
        require test -L "$d/log/supervise"
    fi
done

# 98-sbin-merge.sh tries `mv /usr/sbin /usr/sbin.old` at boot if /usr/sbin is a
# directory of symlinks; on a read-only root that fails every boot.
if [ -d /usr/sbin ] && [ ! -L /usr/sbin ]; then
    echo "NOTE: /usr/sbin is a real directory - check 98-sbin-merge.sh behaviour" >&2
fi

echo "==> Immutable setup complete"