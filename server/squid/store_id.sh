#!/bin/sh

LOG_DIR=/var/log/squid
[ -w "$LOG_DIR" ] || LOG_DIR=/tmp

exec stdbuf -i0 -oL -eL \
    awk -f /opt/lk-settings/server/squid/store_id.awk \
    2>>"$LOG_DIR/store_id.log"
