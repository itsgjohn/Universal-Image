#!/bin/sh
set -eu

repo=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
vm=/work/vm
image=${1:-localhost/test:latest}

mkdir -p "$vm"
rm -rf "${vm:?}/bundle" "${vm:?}/oci" "${vm:?}/skel" "${vm:?}/home" \
    "${vm:?}/rootfs.tar" "${vm:?}/home.tar"

buildah rm vm-rootfs >/dev/null 2>&1 || true
buildah rmi vm-rootfs-image >/dev/null 2>&1 || true

buildah from --name vm-rootfs "$image" >/dev/null
buildah copy vm-rootfs "$repo/vm/agetty-tty1.conf" /etc/sv/agetty-tty1/conf
buildah copy vm-rootfs "$repo/vm/agetty-serial.conf" /etc/sv/agetty-serial/conf

buildah run vm-rootfs -- sh -c '
set -eu
useradd -M -G wheel,audio,video,input -s /usr/bin/void-session void
printf "%s\n" "void:void" | chpasswd
printf "%s\n" "root:void" | chpasswd
ln -sfn /etc/sv/agetty-ttyS0 /etc/runit/runsvdir/default/agetty-ttyS0
'

buildah commit vm-rootfs vm-rootfs-image >/dev/null
buildah push vm-rootfs-image "oci:$vm/oci:test" >/dev/null
umoci unpack --image "$vm/oci:test" "$vm/bundle"

tar --numeric-owner --xattrs --acls -C "$vm/bundle/rootfs" \
    -cf "$vm/rootfs.tar" .

mkdir -p "$vm/skel"
tar -xf "$vm/rootfs.tar" -C "$vm/skel" ./etc/skel
tar -C "$vm/skel/etc/skel" --owner=1000 --group=1000 \
    -cf "$vm/home.tar" .

buildah rm vm-rootfs >/dev/null
buildah rmi vm-rootfs-image >/dev/null
rm -rf "$vm/bundle" "$vm/oci" "$vm/skel"

ls -lh "$vm/rootfs.tar" "$vm/home.tar"