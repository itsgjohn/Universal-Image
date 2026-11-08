#!/bin/sh
# /etc is mounted read-only, but NetworkManager needs to write resolv.conf.
# Put a writable file from the /run tmpfs on top of the image's copy.

[ -n "$IS_CONTAINER" ] && return 0

mkdir -p /run/NetworkManager
touch /run/NetworkManager/resolv.conf

if [ ! -L /etc/resolv.conf ]; then
    if ! mount -o bind /run/NetworkManager/resolv.conf /etc/resolv.conf; then
        msg_warn "Could not make /etc/resolv.conf writable"
    fi
fi
