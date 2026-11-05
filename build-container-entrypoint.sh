#!/bin/sh
set -eu

if [ -r /run/host-ca-bundle.pem ] && [ -r /etc/ssl/cert.pem ]; then
	cat /etc/ssl/cert.pem /run/host-ca-bundle.pem > /tmp/combined-ca-bundle.pem
	cp /tmp/combined-ca-bundle.pem /etc/ssl/cert.pem
	export SSL_CERT_FILE=/tmp/combined-ca-bundle.pem
	export CURL_CA_BUNDLE=/tmp/combined-ca-bundle.pem
	export GIT_SSL_CAINFO=/tmp/combined-ca-bundle.pem
fi

exec ./build.sh
