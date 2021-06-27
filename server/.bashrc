#!/bin/bash

if [ -f /opt/lk-platform/lib/bash/rc.sh ]; then
    . /opt/lk-platform/lib/bash/rc.sh
fi

function lighttpd-check-config() {
    sudo lighttpd -f /etc/lighttpd/lighttpd.conf -p
}

function lighttpd-reload() {
    lighttpd-check-config &&
        sudo systemctl reload lighttpd.service ||
        systemctl status lighttpd.service
}

function squid-report() {
    squidclient "mgr:$1"
}

function pacman-sign() { (
    shopt -s nullglob
    lk_console_message "Checking package signatures"
    for FILE in /srv/repo/{aur,lk,quarry}/*.pkg.tar.zst; do
        [ ! -e "$FILE.sig" ] || continue
        lk_console_detail "Signing" "$FILE"
        DIR=${FILE%/*}
        REPO=$DIR/${DIR##*/}.db.tar.xz
        gpg --batch --passphrase-file ~/.gpg-"$GPGKEY" \
            --detach-sign "$FILE" &&
            #touch -r "$FILE" "$FILE.sig" &&
            repo-add -s "$REPO" "$FILE" || break
    done
); }

function pacman-clean() {
    lk_console_message "Cleaning up old packages"
    lk_run_detail sudo paccache -v \
        --cachedir=/var/cache/pacman/pkg/ --keep 1 --remove &&
        lk_run_detail sudo paccache -v \
            --cachedir=/srv/repo/{aur,lk,quarry}/ --keep 2 --remove
}

function pacman-build-all() {
    lk_aur_sync &&
        /opt/lk-pkgbuilds/build.sh --all &&
        /opt/quarry/lib/update.rb &&
        pacman-sign &&
        pacman-clean
}

function hub-rsync() {
    local DEST=${2:-${1-}} ARG
    [ $# -ge 1 ] || lk_usage "\
Usage: $FUNCNAME /path/on/hub [/path/on/doo [RSYNC_ARG...]]

Use rsync to copy files from hub to doo after completing a dry run." || return
    for ARG in -n ""; do
        lk_run rsync ${ARG:+"$ARG"} -vrlpt --delete "${@:3}" \
            --password-file="$HOME/.rsync-hub" \
            "doo@hub::root${1%/}/" "${DEST%/}/"
        [ -z "$ARG" ] || lk_confirm "Dry run OK?" Y || break
    done
}

alias gpg-cache-check='gpg-connect-agent "keyinfo --list" /bye'
alias gpg-cache-passphrase='gpg-preset-passphrase --preset "$GPGKEYGRIP" <~/.gpg-"$GPGKEY"'
alias gpg-list-keygrips='gpg --list-secret-keys --with-keygrip'
alias gpg-preset-passphrase='/usr/lib/gnupg/gpg-preset-passphrase'
alias lighttpd-follow-log='sudo tail -f /var/log/lighttpd/access.log'
alias squid-active-requests='squidclient mgr:active_requests'
alias squid-follow-access-log='sudo tail -f /var/log/squid/access.log'
alias squid-follow-store-log='sudo tail -f /var/log/squid/store.log'
alias squid-list-reports='squidclient mgr:menu'

export PACKAGER="Luke Arms <luke@arms.to>"
export GPGKEY=B7304A7EB769E24D
GPGKEYGRIP=056A5FE1D4AE65E25C0E8037DD3B221BD1C7F3B1
gpg-cache-passphrase
export CHROOT=~/chroot
