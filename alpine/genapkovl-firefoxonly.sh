#!/bin/sh -e

HOSTNAME="$1"
if [ -z "$HOSTNAME" ]; then
	echo "usage: $0 hostname" >&2
	exit 1
fi

cleanup() {
	rm -rf "$tmp"
}

makefile() {
	owner="$1"
	permissions="$2"
	filename="$3"
	cat > "$filename"
	chown "$owner" "$filename"
	chmod "$permissions" "$filename"
}

rc_add() {
	mkdir -p "$tmp/etc/runlevels/$2"
	ln -sf "/etc/init.d/$1" "$tmp/etc/runlevels/$2/$1"
}

tmp=$(mktemp -d)
trap cleanup EXIT
mkdir -p "$tmp/etc"
makefile root:root 0644 "$tmp/etc/hostname" <<EOF
$HOSTNAME
EOF

mkdir -p "$tmp/etc/apk"
makefile root:root 0644 "$tmp/etc/apk/world" <<EOF
alpine-base
EOF
for package in $FIREFOX_ONLY_APKS; do
	printf '%s\n' "$package" >> "$tmp/etc/apk/world"
done

cp -a "$PROJECT_ROOT/alpine/firefox-only/rootfs/etc/." "$tmp/etc/"
mkdir -p "$tmp/usr"
if [ -d "$PROJECT_ROOT/alpine/firefox-only/rootfs/usr" ]; then
	cp -a "$PROJECT_ROOT/alpine/firefox-only/rootfs/usr/." "$tmp/usr/"
fi
chmod 755 "$tmp/etc/init.d/kiosk-user" "$tmp/etc/xdg/openbox/autostart"

rc_add devfs sysinit
rc_add dmesg sysinit
rc_add udev sysinit
rc_add udev-trigger sysinit
rc_add udev-settle sysinit
rc_add modloop sysinit
rc_add hwclock boot
rc_add modules boot
rc_add sysctl boot
rc_add hostname boot
rc_add bootmisc boot
rc_add syslog boot
rc_add kiosk-user boot
rc_add udev-postmount default
rc_add mount-ro shutdown
rc_add killprocs shutdown
rc_add savecache shutdown

rc_add dbus default
rc_add elogind default
rc_add networkmanager default
rc_add lightdm default

tar -c -C "$tmp" etc usr | gzip -9n > "$HOSTNAME.apkovl.tar.gz"
