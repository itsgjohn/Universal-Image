# Seed the persistent /var (@var) from the copy shipped in the image.
# Existing files are never overwritten, so state survives updates, and
# directories added by a newer image appear automatically.

if [ -d /usr/share/factory/var ]; then
    msg "Seeding /var from image defaults..."
    cp -an /usr/share/factory/var/. /var/ || msg_warn "Seeding /var reported errors"
fi

if [ ! -s /var/lib/dbus/machine-id ]; then
    msg "Generating machine-id..."
    dbus-uuidgen --ensure=/var/lib/dbus/machine-id
fi