#!/bin/bash

LK_TTY_NO_COLOUR=1 \
    . /opt/lk-platform/bin/lk-bash-load.sh || exit
lk_require linux

eval "$(lk_get_regex IPV6_REGEX)"

LAN_IFACE=$1
WAN_IFACE=$2

lk_log_start

trap 'kill 0' EXIT

lk_mktemp_dir_with DIR
FIFO=$DIR/fifo
mkfifo "$FIFO"
exec 8<>"$FIFO"

(ip address show dev "$LAN_IFACE" &&
    ip monitor address dev "$LAN_IFACE") >&8 &
MONITOR_PID=$!

WAN_IP=$(awk -v "ipv6_regex=$IPV6_REGEX" '
! /(^Deleted | tentative( |$))/ &&
    / inet6 .+ scope global( .*)? noprefixroute( |$)/ {
    if (match($0, ipv6_regex)) {
        print substr($0, RSTART, RLENGTH)
        exit
    }
}' <&8)

kill "$MONITOR_PID" || true

GATEWAY=$(nmcli -g IP6.GATEWAY connection show "$WAN_IFACE") &&
    [ -n "$GATEWAY" ] || lk_die "no IP6.GATEWAY on $WAN_IFACE"

ROUTE=(default via "${GATEWAY//\\:/:}"
    dev "$WAN_IFACE" protocol static metric 100 src "$WAN_IP")
lk_require_output -q ip -6 route show "${ROUTE[@]}" || {
    lk_tty_run ip -6 route replace "${ROUTE[@]}" &&
        lk_tty_run ip -6 route flush cache
}
