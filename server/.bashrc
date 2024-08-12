#!/bin/bash

[[ $- == *i* ]] || shopt -s expand_aliases

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

function squid-analyse-store-log() {
    (($#)) || set -- /var/log/squid/store.log*
    lk_cat_log "$@" | awk '
NR == 1 {
    last_ts = $1
}
function get_diff(_diff) {
    _diff = sprintf("+ %-9.2f ", $1 - last_ts)
    last_ts = $1
    return _diff
}
$2 == "SWAPOUT" {
    _key = $5
    _uri = $13
    _size = $11
    sub(".*/", "", _size)
    # Cache key not seen before?
    if (!key_uri[_key]) {
        key_uri[_key] = _uri
        uri_key[_uri, uri_keys[_uri]++] = _key
    }
    count_in[_uri]++
    last[_uri] = "IN"
    size[_uri] = _size
    ts[_uri] = $1
    print get_diff() sprintf("%11d", _size) " bytes IN: " _uri >"/dev/stderr"
}
$2 == "RELEASE" && $3 != -1 {
    _key = $5
    _uri = key_uri[_key]
    if (_uri && last[_uri] == "IN") {
        count_out[_uri]++
        last[_uri] = "OUT"
        seconds_in = int($1 - ts[_uri])
        ttl[_uri] += seconds_in
        print get_diff() sprintf("%11d", size[_uri]) " bytes OUT after " seconds_in " sec: " _uri >"/dev/stderr"
    }
}
END {
    OFS = "\t"
    for (_uri in count_in) {
        for (i = 0; i < uri_keys[_uri]; i++) {
            keys = (i ? keys "," : "") uri_key[_uri, i]
        }
        print size[_uri], ttl[_uri] + (last[_uri] == "IN" ? int($1 - ts[_uri]) : 0), count_in[_uri], int(count_out[_uri]), last[_uri], keys, _uri
    }
}'
}

function pacman-sign() { (
    shopt -s nullglob
    lk_tty_print "Checking package signatures"
    for FILE in /srv/repo/{aur,lk,quarry}/*.pkg.tar.zst; do
        [ ! -e "$FILE.sig" ] || continue
        lk_tty_detail "Signing" "$FILE"
        DIR=${FILE%/*}
        REPO=$DIR/${DIR##*/}.db.tar.xz
        gpg --batch --passphrase-file ~/.gpg-"$GPGKEY" \
            --detach-sign "$FILE" &&
            #touch -r "$FILE" "$FILE.sig" &&
            repo-add -s "$REPO" "$FILE" || break
    done
); }

function pacman-clean() {
    local OPERATION
    lk_tty_print "Cleaning up old packages"
    for OPERATION in --dryrun --remove; do
        lk_tty_run_detail sudo paccache -v \
            --cachedir={/var/cache/pacman/pkg/,/srv/repo/{aur,lk,quarry}/} --keep 2 "$OPERATION"
        [[ $OPERATION == --remove ]] || lk_tty_yn "Proceed?" || return
    done
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
        lk_tty_run rsync ${ARG:+"$ARG"} -vrlpt --delete "${@:3}" \
            --password-file="$HOME/.rsync-hub" \
            "doo@hub::root${1%/}/" "${DEST%/}/"
        [ -z "$ARG" ] || lk_tty_yn "Dry run OK?" Y || break
    done
}

function plc-sync-uploads() {
    local ARGS=()
    while [[ ${1-} == -* ]]; do
        ARGS[${#ARGS[*]}]=$1
        shift
    done
    local DIR=${1:-~/Code/plc/plc-wp-4mation/wp-content/uploads/}
    [ -d "$DIR" ] || lk_warn "directory not found: $DIR" || return
    lk_tty_run rsync -vrlpt \
        --delete \
        --exclude=/gravity_forms/ \
        --exclude=/cache/ \
        --exclude="/*backup*/" \
        --delete-excluded \
        ${ARGS+"${ARGS[@]}"} \
        pymblelc@plc-wp-prod1:public_html/wp-content/uploads/ \
        "${DIR%/}"
}

function mkvmerge-mkv-ac3-aac() {
    local IFS=$'\n' IN AC3 AAC OUT MOVE=()
    set -- $(lk_args "$@" | sed -E '/^\./d; s/\.[^.]+$//' | sort -u)
    unset IFS
    while (($#)); do
        IN=$1.mkv
        AC3=$1.ac3
        AAC=$1.aac
        OUT=$1.new.mkv
        lk_files_exist "$IN" "$AC3" "$AAC" ||
            lk_warn "missing file(s): $1" || { shift && continue; }
        [[ ! -e $OUT ]] ||
            lk_warn "already merged: $1" || { MOVE[${#MOVE[@]}]=$1 && shift && continue; }
        lk_tty_run mkvmerge --output "$OUT" \
            --no-audio "$IN" \
            --language 0:en --track-name "0:Surround 5.1" "$AC3" \
            --language 0:en --track-name "0:Stereo" --default-track-flag 0:0 "$AAC" ||
            lk_pass rm -f "$OUT" || return
        MOVE[${#MOVE[@]}]=$1
        shift
    done
    set -- ${MOVE+"${MOVE[@]}"}
    while (($#)); do
        OUT=$1
        [[ $OUT == */* ]] || OUT=./$1
        OUT=${OUT%/*}/.${OUT##*/}
        mv -vn "$1.mkv" "$OUT.mkv" &&
            mv -vn "$1.ac3" "$OUT.ac3" &&
            mv -vn "$1.aac" "$OUT.aac" &&
            mv -vn "$1.new.mkv" "$1.mkv" || return
        shift
    done
}

function _do-rename-media() {
    [[ -n ${MV+1} ]] || return 0
    lk_tty_yn "Proceed?" Y || lk_warn "cancelled by user" || return 0
    local FILE
    for FILE in "${MV[@]}"; do
        eval "mv -vn $FILE"
    done
}

function rename-tv-episodes() {
    local EXT_RE FILE SHOW SEASON NAME EXT RE LAST= EP PRINTED NEW_FILE MV=() \
    SEASON_RE='/([^/]+)/(([0-9]+\>)[^/]+|[^/]+(\<[0-9]+))/([^/]+)\.([^.]+)$'
    for EXT_RE in "m4v|mkv|mp4" ac3 aac; do
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
                lk_tty_warning "Skipping (invalid path):" "$FILE"
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
                EP=${BASH_REMATCH[1]#0} || true
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
        done < <(find "${@:-.}" -type f -regextype posix-egrep \
            -regex ".*/[^/.][^/]*\.($EXT_RE)" -print0 |
            xargs -0r realpath -z | sort -zV)
    done
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
    done < <(find "${@:-.}" -type f -regextype posix-egrep \
        -regex '.*/[^/.][^/]*\.(m4v|mkv|mp4)' -print0 |
        xargs -0r realpath -z | sort -zV)
    _do-rename-media
}

function fix-media() { (
    shopt -s globstar
    find "/data/media" \
        \( -type d ! -perm 0755 -exec chmod -c 00755 '{}' + \) -o \
        \( -type f ! -perm 0644 -exec chmod -c 00644 '{}' + \)
    rename-tv-episodes /data/media/**/"TV Shows" &&
        rename-movies /data/media/**/{Documentaries,Movies}
); }

function iperf3-server() {
    lk_unbuffer iperf3 --server |
        tee -a ~/Temp/iperf3.server."$(lk_hostname)".log
}

function system-update() { (
    shopt -s nullglob
    LAST_FAILED=0
    for DIR in /opt/lk-*/.git ""; do
        ! ((LAST_FAILED)) || lk_tty_yn "Check failed. Continue?" Y || return
        [ -n "$DIR" ] || break
        LAST_FAILED=1
        DIR=${DIR%/.git}
        _DIR=~/Code/"${DIR##*/}"
        [ ! "$DIR" -ef "$_DIR" ] || { LAST_FAILED=0 && continue; }
        lk_tty_print "Checking for updates:" "$DIR"
        cd "$DIR" && BRANCH=$(lk_git_branch_current) ||
            lk_warn "detached HEAD: $DIR" || continue
        [ ! -d "$_DIR" ] || { {
            git remote | grep -Fx local >/dev/null ||
                lk_tty_run_detail git remote add -f local "file://$_DIR"
        } && {
            lk_git_branch_upstream | grep -Fx local/"$BRANCH" >/dev/null ||
                lk_tty_run_detail git branch --set-upstream-to=local/"$BRANCH"
        }; } || continue
        REMOTE=$(lk_git_branch_upstream_remote) ||
            lk_warn "no upstream remote: $DIR" || continue
        lk_git_update_repo_to -f "$REMOTE" "$BRANCH" || continue
        LAST_FAILED=0
    done
    lk-provision-arch.sh &&
        lk_tty_print &&
        lk_tty_run /opt/lk-settings/bin/sync-arch.sh
); }

function iptables-persist() {
    lk_iptables_save | sed \
        -E '/( --path |f2b)/d' >/opt/lk-settings/server/iptables/iptables.rules
    lk_iptables_save -6 | sed \
        -E '/( --path |f2b)/d' >/opt/lk-settings/server/iptables/ip6tables.rules
}

function iptables-reload() {
    sudo systemctl reload iptables.service ip6tables.service &&
        sudo systemctl restart fail2ban.service
}

function wake-nas2() {
    wol -i 10.10.255.255 -p 9 -v e8:fc:af:e5:96:8c
}

function _prepare_cloudimg() {
    export LK_UBUNTU_MIRROR=http://ubuntu.mirror/ \
        LK_UBUNTU_CLOUDIMG_HOST=cloud-images.ubuntu.mirror
}

function rebuild-cpanel() {
    _prepare_cloudimg
    lk_tty_run lk-cloud-image-boot.sh \
        -i ubuntu-20.04-minimal \
        -c 2 -m 4096 -s 40G \
        -n bridge=br0 -M 52:54:00:f2:c0:63 -I 10.10.122.87/16 \
        -H \
        "$@" \
        cpanel-test && sleep 2 && sudo virsh start cpanel-test
}

function _rebuild-ub() {
    _prepare_cloudimg
    lk_tty_run lk-cloud-image-boot.sh \
        -i "$1" \
        -c 2 -m 2048 -s 20G \
        -n bridge=br0 -M "$2" -I "$3" \
        -H \
        "${@:5}" \
        "$4"
}

function git-cleanable-size() {
    git clean -nxd |
        sed -En 's/^Would remove //p' |
        xargs -r du -sc |
        tail -n1 |
        awk -v d="${PWD##*/}" \
            '{ printf("%s: %.3f GiB\n", d, $1/(1024*1024)) }'
}

function rebuild-ub22() { _rebuild-ub ubuntu-22.04 52:54:00:1b:ea:89 10.10.122.22/16 ub22 "$@"; }
function rebuild-ub20() { _rebuild-ub ubuntu-20.04 52:54:00:76:c6:3e 10.10.122.20/16 ub20 "$@"; }
function rebuild-ub18() { _rebuild-ub ubuntu-18.04 52:54:00:5e:ca:ba 10.10.122.18/16 ub18 "$@"; }

alias disable-proxy='unset http{,s}_proxy'
alias gpg-cache-check='gpg-connect-agent "keyinfo --list" /bye'
alias gpg-cache-passphrase='gpg-preset-passphrase --preset "$GPGKEYGRIP" <~/.gpg-"$GPGKEY"'
alias gpg-list-keygrips='gpg --list-secret-keys --with-keygrip'
alias gpg-preset-passphrase='/usr/lib/gnupg/gpg-preset-passphrase'
alias lighttpd-follow-log='sudo tail -f /var/log/lighttpd/access.log'
alias squid-active-requests='squidclient mgr:active_requests'
alias squid-follow-access-log='sudo tail -f /var/log/squid/access.log'
alias squid-follow-store-log='sudo tail -f /var/log/squid/store.log'
alias squid-list-reports='squidclient mgr:menu'
alias aur-rebuild-php='lk_aur_rebuild php74 php74-imagick php74-memcache php74-memcached php74-xdebug php80 php80-imagick php80-memcached php80-xdebug php81 php81-imagick php81-xdebug php82 php82-imagick php82-xdebug php-humbug-box-bin php-ibm_db2 php-memprof php-pcov php-sqlsrv'

export PACKAGER="Luke Arms <luke@arms.to>"
export GPGKEY=B7304A7EB769E24D
GPGKEYGRIP=056A5FE1D4AE65E25C0E8037DD3B221BD1C7F3B1
gpg-cache-passphrase
export CCACHE_DIR=~/.cache/ccache

eval export http{,s}_proxy=http://localhost:3127
#export BYOBU_NO_TITLE=1
