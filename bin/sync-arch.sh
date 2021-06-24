#!/bin/bash

. /opt/lk-platform/bin/lk-bash-load.sh || exit

lk_include arch

lk_log_start
lk_log_tty_off

STATUS=0

lk_aur_sync || STATUS=$?

if [ -x /opt/quarry/lib/update.rb ]; then
    /opt/quarry/lib/update.rb || STATUS=$?
fi

(exit "$STATUS") || lk_die "sync failed, please check logs"
