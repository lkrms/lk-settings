#!/bin/bash

[[ $- != *i* ]] && return

alias ls='ls --color=auto'
PS1='[\u@\h \W]\$ '

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

function plc-sync-uploads() {
    local ARGS=()
    while [[ "${1-}" == -* ]]; do
        ARGS[${#ARGS[*]}]=$1
        shift
    done
    local DIR=${1:-~/Code/plc/plc-wp-4mation/wp-content/uploads/}
    [ -d "$DIR" ] || lk_warn "directory not found: $DIR" || return
    lk_run rsync -vrlpt \
        --delete \
        --exclude=/gravity_forms/ \
        --exclude=/cache/ \
        --exclude="/*backup*/" \
        --delete-excluded \
        ${ARGS+"${ARGS[@]}"} \
        pymblelc@plc-wp-prod1:public_html/wp-content/uploads/ \
        "${DIR%/}"
}

function _do-rename-media() {
    lk_confirm "Proceed?" Y || lk_warn "cancelled by user" || return
    for FILE in "${MV[@]}"; do
        eval "mv -vn $FILE"
    done
}

function rename-tv-episodes() {
    local FILE SHOW SEASON NAME EXT RE LAST= EP PRINTED NEW_FILE MV=() \
    SEASON_RE='/([^/]+)/(([0-9]+\>)[^/]+|[^/]+(\<[0-9]+))/([^/]+)\.([^.]+)$'
    while read -rd '' FILE; do
        if [[ $FILE =~ $SEASON_RE ]]; then
            SHOW=${BASH_REMATCH[1]}
            SEASON=${BASH_REMATCH[3]}${BASH_REMATCH[4]}
            NAME=${BASH_REMATCH[5]}
            EXT=${BASH_REMATCH[6]}
        elif [[ $FILE =~ /([^/]+)/([^/]+)\.([^.]+)$ ]]; then
            SHOW=${BASH_REMATCH[1]}
            SEASON=
            NAME=${BASH_REMATCH[2]}
            EXT=${BASH_REMATCH[3]}
        else
            lk_console_warning "Skipping (invalid path):" "$FILE"
            continue
        fi
        [ "$LAST" = "$SHOW/$SEASON" ] || {
            ! lk_verbose || lk_tty_print "Checking" "${FILE%/*}"
            RE=$(lk_ere_escape "$SHOW")${SEASON:+"_S0*$SEASON"}"_E([0-9]{2,})"
            LAST=$SHOW/$SEASON
            EP=0
            PRINTED=
        }
        [ "$EXT" != mp4 ] || EXT=m4v
        if [[ $NAME =~ ^$RE$ ]]; then
            EP=${BASH_REMATCH[1]} || true
            NEW_FILE=${FILE%/*}/$NAME.$EXT
        else
            while ((++EP)); do
                NEW_FILE=${FILE%/*}/$(printf \
                    '%s_S%d_E%02d' "$SHOW" "$SEASON" "$EP").$EXT
                [ -e "$NEW_FILE" ] || break
            done
        fi
        [ "$FILE" != "$NEW_FILE" ] || {
            ! lk_verbose ||
                lk_tty_detail "Skipping (already renamed):" "${FILE##*/}"
            continue
        }
        # e.g. if an episode has the wrong extension but a file with the correct
        # extension already exists
        [ ! -e "$NEW_FILE" ] ||
            lk_warn "target already exists: $NEW_FILE" || return
        lk_verbose || [ -n "$PRINTED" ] || {
            lk_tty_print "In" "${FILE%/*}"
            PRINTED=1
        }
        lk_tty_detail "${FILE##*/} -> $LK_BOLD${NEW_FILE##*/}$LK_RESET"
        MV[${#MV[@]}]=$(printf '%q %q' "$FILE" "$NEW_FILE")
    done < <(find "${1:-.}" -type f -regextype posix-egrep \
        -regex '.*/[^/.][^/]*\.(m4v|mkv|mp4)' -print0 |
        xargs -0 realpath -z | sort -zV)
    _do-rename-media
}

function rename-movies() {
    local FILE NAME EXT NEW_FILE RE='(.*[^ ])-[^ ]+'
    while read -rd '' FILE; do
        NAME=${FILE##*/}
        EXT=${NAME##*.}
        NAME=${NAME%.*}
        [ "$EXT" != mp4 ] || EXT=m4v
        [[ ! $NAME =~ ^$RE$ ]] ||
            NAME=${BASH_REMATCH[1]}
        NEW_FILE=${FILE%/*}/$NAME.$EXT
        [ "$FILE" != "$NEW_FILE" ] || {
            ! lk_verbose ||
                lk_tty_detail "Skipping (already renamed):" "${FILE##*/}"
            continue
        }
        [ ! -e "$NEW_FILE" ] ||
            lk_warn "target already exists: $NEW_FILE" || return
        lk_tty_detail "${FILE##*/} -> $LK_BOLD${NEW_FILE##*/}$LK_RESET"
        MV[${#MV[@]}]=$(printf '%q %q' "$FILE" "$NEW_FILE")
    done < <(find "${1:-.}" -type f -regextype posix-egrep \
        -regex '.*/[^/.][^/]*\.(m4v|mkv|mp4)' -print0 |
        xargs -0 realpath -z | sort -zV)
    _do-rename-media
}

function iperf3-server() {
    lk_unbuffer iperf3 --server |
        tee -a ~/Temp/iperf3.server."$(lk_hostname)".log
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
