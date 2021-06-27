#!/bin/bash

. /opt/lk-platform/bin/lk-bash-load.sh || exit

lk_include arch

lk_log_start
lk_log_tty_off

STATUS=0

export PACKAGER="Luke Arms <luke@arms.to>"
export GPGKEY=B7304A7EB769E24D

GPGKEYGRIP=056A5FE1D4AE65E25C0E8037DD3B221BD1C7F3B1
/usr/lib/gnupg/gpg-preset-passphrase --preset "$GPGKEYGRIP" <~/.gpg-"$GPGKEY"

lk_aur_sync || STATUS=$?

if [ -x /opt/quarry/lib/update.rb ]; then
    /opt/quarry/lib/update.rb || STATUS=$?
fi

(exit "$STATUS") || lk_die "sync failed, please check logs"
