#!/bin/bash

. /opt/lk-platform/bin/lk-bash-load.sh || exit
lk_require arch

_DIR=/opt/lk-settings/server

(
    declare LK_SUDO=1 LK_VERBOSE=${LK_VERBOSE-1}
    lk_file_replace -f "$_DIR/NetworkManager/dispatcher.d/90-doo-check" \
        /etc/NetworkManager/dispatcher.d/90-doo-check
    lk_file_replace -f "$_DIR/NetworkManager/conf.d/lk-server.conf" \
        /etc/NetworkManager/conf.d/lk-server.conf
    lk_file_replace -f "$_DIR/dnsmasq/logrotate.d/dnsmasq" \
        /etc/logrotate.d/dnsmasq
    lk_file_replace -f "$_DIR/sqm/ppp0.iface.conf" \
        /etc/sqm/ppp0.iface.conf
)

function update-notracking() {
    local TEMP TEMP2 LK_FILE_REPLACE_NO_CHANGE LK_VERBOSE=1 LK_FILE_NO_DIFF=1 \
        FILE=$_DIR/dnsmasq/dnsmasq.d/notracking.conf \
        URL=https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts \
        UNBLOCKED=$_DIR/squid/unblock.dstdomain
    lk_tty_print "Checking notracking blocklists"
    [[ ! /etc/dnsmasq.d -ef $_DIR/dnsmasq/dnsmasq.d ]] || {
        lk_tty_detail "$FILE"
        lk_mktemp_with TEMP &&
            lk_mktemp_with TEMP2 &&
            curl -fsSL "$URL" |
            awk '$1 == "0.0.0.0" && $2 != "0.0.0.0" { print "address=/" $2 "/" }' |
                sort -u |
                tee "$TEMP2" |
                sed -E "$(
                    cat <<"EOF"
# Copy to hold space
h
# Reduce to domain
s/^[^/]*\/([^/]+)\/.*/\1/
# Delete unblocked
EOF
                    # Convert unblocked domain list to something like:
                    #
                    #     /^(tags\.|^)(news\.|^)(com\.|^)au$/d
                    #     /^(.+\.)?(amazon-adsystem\.|^)com$/d
                    #     /^(tbs8v877\.|^)(r\.|^)(us-east-1\.|^)(awstrack\.|^)me$/d
                    sed -E "$(
                        cat <<"EOF"
# Delete comments and empty lines
/^(#|[ \t]*$)/d
# Replace each domain part '<part>.' with '(<part>\.|^)'
s/([^.]+)\./(\1\\.|^)/g
# Replace leading '.' with '(.+\.)?'
s/^\./(.+\\.)?/
# Enclose each line between '/^' and '$/d'
s/.*/\/^&$\/d/
EOF
                    )" "$UNBLOCKED"
                    cat <<"EOF"
# Restore from hold space
g
EOF
                )" >"$TEMP" &&
            lk_file_replace -f "$TEMP" "$FILE" || return
        lk_tty_diff "$TEMP2" "$TEMP"
    }
    [[ ! /etc/squid/squid.conf -ef $_DIR/squid/squid.conf ]] || {
        FILE=$_DIR/squid/notracking.dstdomain
        lk_tty_detail "$FILE"
        curl -fsSL "$URL" |
            awk '$1 == "0.0.0.0" && $2 != "0.0.0.0" { print $2 }' |
            sort -u >"$TEMP" &&
            lk_file_replace -f "$TEMP" "$FILE" || return
    }
    ! lk_false LK_FILE_REPLACE_NO_CHANGE || {
        ! lk_systemctl_running dnsmasq || lk_systemctl_restart dnsmasq
        ! lk_systemctl_running squid || lk_systemctl_restart squid
    }
}

lk_lock

lk_log_start

STATUS=0

sudo chmod -c a-x \
    /etc/ppp/ip-down.d/00-dns.sh \
    /etc/ppp/ip-up.d/00-dns.sh || STATUS=$?

time update-notracking || STATUS=$?

export PACKAGER="Luke Arms <luke@arms.to>"
export GPGKEY=B7304A7EB769E24D

GPGKEYGRIP=056A5FE1D4AE65E25C0E8037DD3B221BD1C7F3B1
/usr/lib/gnupg/gpg-preset-passphrase --preset "$GPGKEYGRIP" <~/.gpg-"$GPGKEY"

lk_aur_sync || STATUS=$?

lk_log_tty_off

paccache -c /srv/repo/aur -rv || STATUS=$?

(exit "$STATUS") || lk_die "sync failed, please check logs"
