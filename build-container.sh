#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
IMAGE=${KIOSK_BUILDER_IMAGE:-xfce-kiosk-builder:alpine3.24}
BASE_IMAGE=${KIOSK_BASE_IMAGE:-docker.artifactory.dhl.com/library/alpine:3.24}
ALPINE_TAG=${ALPINE_TAG:-v3.24}
APORTS_BRANCH=${APORTS_BRANCH:-3.24-stable}
APORTS_URL=${APORTS_URL:-https://gitlab.alpinelinux.org/alpine/aports/-/archive/$APORTS_BRANCH/aports-$APORTS_BRANCH.tar.gz}
ALPINE_REPO_BASE=${ALPINE_REPO_BASE:-https://dl-cdn.alpinelinux.org/alpine}
ENGINE=${CONTAINER_ENGINE:-}
CA_BUNDLE=${HOST_CA_BUNDLE:-}

if [ -z "$CA_BUNDLE" ]; then
	for candidate in /etc/ssl/cert.pem /etc/ssl/certs/ca-certificates.crt /etc/pki/tls/certs/ca-bundle.crt; do
		if [ -r "$candidate" ]; then
			CA_BUNDLE=$(readlink -f "$candidate")
			break
		fi
	done
fi

if [ -z "$ENGINE" ]; then
	if command -v podman >/dev/null 2>&1; then
		ENGINE=podman
	elif command -v docker >/dev/null 2>&1; then
		ENGINE=docker
	else
		echo "Install Podman or Docker, or set CONTAINER_ENGINE." >&2
		exit 1
	fi
fi

if ! command -v "$ENGINE" >/dev/null 2>&1; then
	echo "Container engine not found: $ENGINE" >&2
	exit 1
fi

if ! command -v flock >/dev/null 2>&1; then
	echo "flock is required to prevent concurrent builds." >&2
	exit 1
fi

exec 9>"$ROOT/.build.lock"
if ! flock -n 9; then
	echo "Another build is already using $ROOT; wait for it to finish." >&2
	exit 1
fi

cd "$ROOT"
if [ "$ENGINE" = podman ]; then
	"$ENGINE" build --network host --http-proxy \
		--build-arg "KIOSK_BASE_IMAGE=$BASE_IMAGE" \
		--build-arg "ALPINE_TAG=$ALPINE_TAG" \
		--file Containerfile \
		--tag "$IMAGE" \
		"$ROOT"
	RUN_NETWORK=host
else
	"$ENGINE" build \
		--build-arg HTTP_PROXY \
		--build-arg HTTPS_PROXY \
		--build-arg FTP_PROXY \
		--build-arg ALL_PROXY \
		--build-arg NO_PROXY \
		--build-arg http_proxy \
		--build-arg https_proxy \
		--build-arg ftp_proxy \
		--build-arg all_proxy \
		--build-arg no_proxy \
		--build-arg "KIOSK_BASE_IMAGE=$BASE_IMAGE" \
		--build-arg "ALPINE_TAG=$ALPINE_TAG" \
		--file Containerfile \
		--tag "$IMAGE" \
		"$ROOT"
	RUN_NETWORK=bridge
fi

set --
if [ -n "$CA_BUNDLE" ]; then
	set -- --volume "$CA_BUNDLE:/run/host-ca-bundle.pem:ro"
fi

"$ENGINE" run --rm --network "$RUN_NETWORK" \
	--env HTTP_PROXY \
	--env HTTPS_PROXY \
	--env FTP_PROXY \
	--env ALL_PROXY \
	--env NO_PROXY \
	--env http_proxy \
	--env https_proxy \
	--env ftp_proxy \
	--env all_proxy \
	--env no_proxy \
	--env ALPINE_TAG="$ALPINE_TAG" \
	--env APORTS_BRANCH="$APORTS_BRANCH" \
	--env APORTS_URL="$APORTS_URL" \
	--env ALPINE_REPO_BASE="$ALPINE_REPO_BASE" \
	--env CLEAN_LIVE_BUILD="${CLEAN_LIVE_BUILD:-0}" \
	--env KIOSK_BUILD_LOCK_HELD=1 \
	"$@" \
	--volume "$ROOT:/work" \
	--workdir /work \
	"$IMAGE" ./build-container-entrypoint.sh
