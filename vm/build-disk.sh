#!/bin/sh
set -eu

repo=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
vm=/work/vm
rootfs=$vm/rootfs.tar
base=$vm/base.img
run=$vm/run.img

[ -f "$rootfs" ]
[ -f "$vm/home.tar" ]

rm -rf "${vm:?}/kernel" "${vm:?}/base.img" "${vm:?}/run.img" \
    "${vm:?}/disk.uuid" "${vm:?}/stage1.out"
mkdir -p "$vm/kernel"

kernel=$(tar -tf "$rootfs" | sed -n 's#^\./boot/\(vmlinuz-[^ ]*\)$#\1#p' | head -n 1)
[ -n "$kernel" ]
version=${kernel#vmlinuz-}
initrd="initramfs-$version.img"

tar -xf "$rootfs" -C "$vm/kernel" "./boot/$kernel" "./boot/$initrd"

qemu-img create -f raw "$base" 8G >/dev/null
LIBGUESTFS_BACKEND=direct \
LIBGUESTFS_BACKEND_SETTINGS=force_tcg=1 \
LIBGUESTFS_MEMSIZE=1024 \
guestfish -a "$base" < "$repo/vm/stage1.gf" > "$vm/stage1.out"

uuid=$(tail -n 1 "$vm/stage1.out")
[ -n "$uuid" ]
printf '%s\n' "$uuid" > "$vm/disk.uuid"

cp --reflink=auto "$base" "$run" 2>/dev/null || cp "$base" "$run"

ls -lh "$base" "$run" "$vm/kernel/boot/$kernel" "$vm/kernel/boot/$initrd"
printf 'disk UUID: %s\n' "$uuid"