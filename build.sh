#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
cd "$ROOT"

ALPINE_TAG=${ALPINE_TAG:-v3.24}
APORTS_BRANCH=${APORTS_BRANCH:-3.24-stable}
APORTS_URL=${APORTS_URL:-https://gitlab.alpinelinux.org/alpine/aports/-/archive/$APORTS_BRANCH/aports-$APORTS_BRANCH.tar.gz}
ALPINE_REPO_BASE=${ALPINE_REPO_BASE:-https://dl-cdn.alpinelinux.org/alpine}
APORTS_DIR="$ROOT/.alpine-aports"
WORKDIR="$ROOT/.alpine-work"

if [ "$(id -u)" -ne 0 ]; then
	echo "Run this script as root (or use ./build-container.sh)." >&2
	exit 1
fi

if [ "${KIOSK_BUILD_LOCK_HELD:-0}" != 1 ]; then
	if ! command -v flock >/dev/null 2>&1; then
		echo "flock is required to prevent concurrent builds." >&2
		exit 1
	fi
	exec 9>"$ROOT/.build.lock"
	if ! flock -n 9; then
		echo "Another build is already using $ROOT; wait for it to finish." >&2
		exit 1
	fi
fi

for tool in abuild-keygen curl; do
	if ! command -v "$tool" >/dev/null 2>&1; then
		echo "Required Alpine build tool not found: $tool" >&2
		exit 1
	fi
done

if [ "${CLEAN_LIVE_BUILD:-0}" = 1 ]; then
	rm -rf -- "$WORKDIR"
fi

# mkimage can leave the package-root directory behind if apk initialization
# fails. Its own cache logic would otherwise mistake that partial tree for a
# complete root and skip initialization on the next run.
APKROOT="$WORKDIR/apkroot-x86_64"
if [ -d "$APKROOT" ] && [ ! -f "$APKROOT/lib/apk/db/installed" ]; then
	echo "Discarding incomplete Alpine package-root cache." >&2
	rm -rf -- "$WORKDIR"
fi

if [ -e "$APORTS_DIR" ] && [ ! -f "$APORTS_DIR/scripts/mkimage.sh" ]; then
	echo "Refusing to replace unrecognized path: $APORTS_DIR" >&2
	exit 1
fi

APORTS_STAGE=$(mktemp -d "$ROOT/.alpine-aports.XXXXXX")
trap 'rm -rf -- "$APORTS_STAGE"' EXIT HUP INT TERM
mkdir "$APORTS_STAGE/src"
curl --fail --location --retry 3 "$APORTS_URL" -o "$APORTS_STAGE/aports.tar.gz"
tar -xzf "$APORTS_STAGE/aports.tar.gz" --strip-components=1 -C "$APORTS_STAGE/src"
if [ ! -f "$APORTS_STAGE/src/scripts/mkimage.sh" ]; then
	echo "The aports archive did not contain scripts/mkimage.sh." >&2
	exit 1
fi
if [ -e "$APORTS_DIR" ]; then
	rm -rf -- "$APORTS_DIR"
fi
mv "$APORTS_STAGE/src" "$APORTS_DIR"
rm -rf -- "$APORTS_STAGE"
trap - EXIT HUP INT TERM
if ! command -v "$APORTS_DIR/scripts/mkimage.sh" >/dev/null 2>&1; then
	chmod 755 "$APORTS_DIR/scripts/mkimage.sh"
fi

# APK 3.x removed --no-chown; the mkimage version on the v3.24-stable branch
# still passes it while initializing its package root.
if grep -q -- '--no-chown' "$APORTS_DIR/scripts/mkimage.sh"; then
	sed -i 's/ --no-chown//g' "$APORTS_DIR/scripts/mkimage.sh"
fi

# The upstream kernel section defaults to the full firmware meta-package. Let
# profiles select it; this virtual-machine image deliberately uses none.
BASE_PROFILE="$APORTS_DIR/scripts/mkimg.base.sh"
if grep -qF '_pkgs="linux-$_f linux-firmware wireless-regdb ' "$BASE_PROFILE"; then
	sed -i 's/_pkgs="linux-$_f linux-firmware wireless-regdb /_pkgs="linux-$_f ${kernel_firmware-linux-firmware} wireless-regdb /' "$BASE_PROFILE"
else
	echo "Cannot apply the firmware-size override to mkimg.base.sh." >&2
	exit 1
fi

install -m 755 "$ROOT/alpine/mkimg.xfcekiosk.sh" "$APORTS_DIR/scripts/mkimg.xfcekiosk.sh"
install -m 755 "$ROOT/alpine/genapkovl-xfcekiosk.sh" "$APORTS_DIR/scripts/genapkovl-xfcekiosk.sh"

# Include the overlay and package manifest in mkimage's cache key so edits to
# those inputs cannot accidentally reuse a stale apkovl from an earlier build.
CONFIG_HASH=$(
	find "$ROOT/alpine" -type f -print \
		| LC_ALL=C sort \
		| while IFS= read -r file; do sha256sum "$file"; done \
		| sha256sum \
		| awk '{print $1}'
)
printf '\n# generated-input-sha256=%s\n' "$CONFIG_HASH" \
	>> "$APORTS_DIR/scripts/genapkovl-xfcekiosk.sh"

KIOSK_APKS=$(awk 'NF && $1 !~ /^#/ { printf "%s ", $1 }' "$ROOT/alpine/packages.list")
export PROJECT_ROOT="$ROOT"
export ALPINE_TAG APORTS_BRANCH ALPINE_REPO_BASE KIOSK_APKS

if [ ! -d /root/.abuild ] || ! find /root/.abuild -maxdepth 1 -type f -name '*.rsa' | grep -q .; then
	abuild-keygen -a -n
fi
for public_key in /root/.abuild/*.rsa.pub; do
	if [ -f "$public_key" ]; then
		install -m 644 "$public_key" /etc/apk/keys/
	fi
done

mkdir -p "$WORKDIR"
"$APORTS_DIR/scripts/mkimage.sh" \
	--tag "$ALPINE_TAG" \
	--repository "$ALPINE_REPO_BASE/$ALPINE_TAG/main" \
	--repository "$ALPINE_REPO_BASE/$ALPINE_TAG/community" \
	--arch x86_64 \
	--profile xfcekiosk \
	--hostkeys \
	--outdir "$ROOT" \
	--workdir "$WORKDIR"
