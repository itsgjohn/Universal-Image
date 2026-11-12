run
mkfs-btrfs /dev/sda label:voidroot
mount /dev/sda /
mkdir /deploy
btrfs-subvolume-create /deploy/20261112
btrfs-subvolume-create /@var
btrfs-subvolume-create /@home
tar-in /work/vm/rootfs.tar /deploy/20261112 xattrs:true acls:true
mkdir /mnt
mkdir /mnt/home
mount-options subvol=@home /dev/sda /mnt/home
mkdir /mnt/home/void
tar-in /work/vm/home.tar /mnt/home/void xattrs:true acls:true
chown 1000 1000 /mnt/home/void
sync
vfs-uuid /dev/sda