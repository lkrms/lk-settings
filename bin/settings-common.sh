#!/bin/bash

# shellcheck disable=SC2128

set -euo pipefail
lk_die() { echo "$BASH_SOURCE: $1" >&2 && exit 1; }
[ -d "${LK_BASE:-}" ] || lk_die "LK_BASE not set"
. "$LK_BASE/lib/bash/common.sh"

shopt -s nullglob

function cleanup() {
    local LINK
    for LINK in ~/.gitconfig ~/.gitignore; do
        [ ! -L "$LINK" ] || [ -e "$LINK" ] ||
            rm -fv "$LINK"
    done
}

function symlink() {
    while [ $# -ge 2 ]; do
        if [ -e "$1" ]; then
            lk_symlink "${@:1:2}" || return
        else
            lk_console_warning "Not found:" "$1"
        fi
        shift 2
    done
}

function symlink_private_common() {
    local FILE
    symlink \
        "$1/.bashrc" ~/.bashrc \
        "$1/acme.sh/" ~/.acme.sh \
        "$1/aws/" ~/.aws \
        "$1/linode-cli/linode-cli" ~/.config/linode-cli \
        "$1/s3cmd/.s3cfg" ~/.s3cfg \
        "$1/ssh/" ~/.ssh
    for FILE in "$1"/.*-settings; do
        lk_symlink "$FILE" ~/"${FILE##*/}" || return
    done
}

# symlink_if_not_running [TARGET LINK]... APP_NAME RUNNING_TEST
function symlink_if_not_running() {
    local CURRENT PASSED=
    while [ $# -ge 4 ]; do
        if [ -e "$1" ]; then
            if [ ! -L "$2" ] || ! CURRENT=$(readlink "$2") ||
                [ "$CURRENT" != "$1" ]; then
                [ -n "$PASSED" ] || ! eval "${*: -1}" &>/dev/null || lk_warn \
                    "cannot apply settings: ${*: -2:1} is running" || return 0
                PASSED=1
                lk_symlink "${@:1:2}" || return
            fi
        else
            lk_console_warning "Not found:" "$1"
        fi
        shift 2
    done
}

LK_VERBOSE=1
