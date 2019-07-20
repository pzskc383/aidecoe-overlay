#!/bin/sh

if [ -f /usr/local/bin/with-qubes-proxy ]; then
    export http_proxy=127.0.0.1:8082
    export https_proxy=127.0.0.1:8082
fi

exec "$@"
