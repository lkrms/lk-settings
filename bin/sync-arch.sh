#!/bin/bash

LK_TTY_NO_COLOUR=1 \
    . /opt/lk-platform/bin/lk-bash-load.sh || exit
lk_include arch

function update-notracking() {
    local TEMP_FILE LK_FILE_REPLACE_NO_CHANGE LK_VERBOSE=1 LK_FILE_NO_DIFF=1 \
        FILE=/opt/lk-settings/server/dnsmasq/dnsmasq.d/notracking.conf \
        URL=https://github.com/notracking/hosts-blocklists/raw/master/dnsmasq/dnsmasq.blacklist.txt \
        UNBLOCKED=/opt/lk-settings/server/squid/unblock.dstdomain
    lk_tty_print "Checking notracking blocklists"
    [ ! /etc/dnsmasq.d -ef /opt/lk-settings/server/dnsmasq/dnsmasq.d ] || {
        lk_tty_detail "$FILE"
        TEMP_FILE=$(lk_mktemp_file) &&
            lk_delete_on_exit "$TEMP_FILE" &&
            curl -fsSL "$URL" |
            awk -v "unblocked=$UNBLOCKED" -v "verbose=${LK_VERBOSE-0}" '
function print_err(str) {
  if (verbose) {
    print str > "/dev/stderr"
  }
}
BEGIN {
  while (getline l < unblocked) {
    if (l ~ /^[[:blank:]]*(#|$)/) {
      continue
    }
    d[++i] = l
    gsub(/\./, "\\.", l)
    sub(/^\\\./, "(.+\\.)?", l)
    r[i] = "/" l "/"
    print_err("Added regex " r[i] " for unblock entry " d[i])
  }
  close(unblocked)
  FS="/"
}
/^address=\// {
  for (i = 1; i <= length(r); i++) {
    if ($0 ~ r[i] || substr(d[i], length(d[i]) - length($2)) == "." $2) {
      print_err("Removing " $2 " (" d[i] " is unblocked)")
      next
    }
  }
}
{ print }' >"$TEMP_FILE" &&
            lk_file_replace -f "$TEMP_FILE" "$FILE" || return
    }
    [ ! /etc/squid/squid.conf -ef /opt/lk-settings/server/squid/squid.conf ] || {
        FILE=/opt/lk-settings/server/squid/notracking.dstdomain
        URL=https://github.com/notracking/hosts-blocklists/raw/master/dnscrypt-proxy/dnscrypt-proxy.blacklist.txt
        lk_tty_detail "$FILE"
        curl -fsSL "$URL" | sed -E 's/^[^#[:blank:]]/.&/' >"$TEMP_FILE" &&
            lk_file_replace -f "$TEMP_FILE" "$FILE" || return
    }
    ! lk_is_false LK_FILE_REPLACE_NO_CHANGE || {
        ! lk_systemctl_running dnsmasq || lk_systemctl_restart dnsmasq
        ! lk_systemctl_running squid || lk_systemctl_restart squid
    }
}

lk_lock

lk_log_start

STATUS=0

update-notracking || STATUS=$?

export PACKAGER="Luke Arms <luke@arms.to>"
export GPGKEY=B7304A7EB769E24D

GPGKEYGRIP=056A5FE1D4AE65E25C0E8037DD3B221BD1C7F3B1
/usr/lib/gnupg/gpg-preset-passphrase --preset "$GPGKEYGRIP" <~/.gpg-"$GPGKEY"

lk_aur_sync || STATUS=$?

lk_log_tty_off

if [ -x /opt/quarry/lib/update.rb ]; then
    /opt/quarry/lib/update.rb || STATUS=$?
fi

(exit "$STATUS") || lk_die "sync failed, please check logs"
