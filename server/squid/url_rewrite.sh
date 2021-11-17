#!/bin/sh

LOG_DIR=/var/log/squid
[ -w "$LOG_DIR" ] || LOG_DIR=/tmp

exec stdbuf -i0 -oL -eL \
    awk -f /opt/lk-settings/server/squid/url_rewrite.awk \
    2>>"$LOG_DIR/url_rewrite.log"
