ARG KIOSK_BASE_IMAGE=alpine:3.24
FROM ${KIOSK_BASE_IMAGE}

ARG ALPINE_TAG=v3.24
ARG HTTP_PROXY
ARG HTTPS_PROXY
ARG FTP_PROXY
ARG ALL_PROXY
ARG NO_PROXY
ARG http_proxy
ARG https_proxy
ARG ftp_proxy
ARG all_proxy
ARG no_proxy

RUN printf '%s\n' \
        "http://dl-cdn.alpinelinux.org/alpine/${ALPINE_TAG}/main" \
        "http://dl-cdn.alpinelinux.org/alpine/${ALPINE_TAG}/community" \
        > /etc/apk/repositories \
    && apk add --no-cache \
        abuild \
        alpine-conf \
        apk-tools \
        ca-certificates \
        curl \
        fakeroot \
        grub-efi \
        mtools \
        squashfs-tools \
        syslinux \
        util-linux \
        xorriso

WORKDIR /work
