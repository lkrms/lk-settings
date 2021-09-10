#!/bin/bash

set -euo pipefail
lk_die() { echo "$BASH_SOURCE: $1" >&2 && exit 1; }
[ -d "${LK_BASE-}" ] || lk_die "LK_BASE not set"
. "$LK_BASE/lib/bash/common.sh"
lk_include misc

shopt -s nullglob

function is_basic() {
    [ -n "${_BASIC-}" ]
}

function cleanup() {
    local LINK
    for LINK in ~/.gitconfig ~/.gitignore "$@"; do
        [ ! -L "$LINK" ] || [ -e "$LINK" ] ||
            lk_run_detail rm -f "$LINK" || break
    done
}

function symlink() {
    local DEV_ONLY=
    [ "${1-}" != -d ] || { DEV_ONLY=1 && shift; }
    while [ $# -ge 2 ]; do
        if [ -n "$DEV_ONLY" ] && is_basic; then
            [ ! -L "$2" ] || [ ! "$1" -ef "$2" ] ||
                lk_run_detail rm -f "$2" || break
        elif [ -e "$1" ]; then
            lk_symlink "${@:1:2}" || return
        else
            is_basic || lk_console_warning "Not found:" "$1"
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
        "$1/lftp/.lftprc" ~/.lftprc \
        "$1/lftp/share/" ~/.local/share/lftp \
        "$1/linode-cli/linode-cli" ~/.config/linode-cli \
        "$1/lk-platform/token/" ~/.config/lk-platform/token \
        "$1/robo3t/.3T/" ~/.3T \
        "$1/s3cmd/.s3cfg" ~/.s3cfg \
        "$1/ssh/" ~/.ssh
    [ -L ~/.unison ] ||
        symlink "$1/unison/" ~/.unison
    for FILE in "$1"/.*-settings; do
        lk_symlink "$FILE" ~/"${FILE##*/}" || return
    done
}

# symlink_if_not_running [TARGET LINK]... APP_NAME RUNNING_TEST
function symlink_if_not_running() {
    local EVAL=${*: -1} CURRENT PASSED=
    EVAL=${EVAL//pgrep /pgrep -u $USER}
    ! lk_verbose || lk_console_message "Checking ${*: -2:1}"
    while [ $# -ge 4 ]; do
        if [ -e "$1" ]; then
            if [ ! -L "$2" ] || ! CURRENT=$(readlink "$2") ||
                [ "$CURRENT" != "$1" ]; then
                [ -n "$PASSED" ] || ! eval "$EVAL" &>/dev/null || lk_warn \
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

function vscode_sync_extensions() {
    local VSCODE_EXTENSIONS INSTALL REMOVE EXT
    lk_command_exists code || return 0
    lk_console_message "Checking VS Code extensions"
    . "$1" || exit
    ! lk_in_array bmewburn.vscode-intelephense-client VSCODE_EXTENSIONS ||
        lk_vscode_extension_disable vscode.php-language-features ||
        lk_warn "error disabling: vscode.php-language-features" || true
    INSTALL=($(comm -13 \
        <(code --list-extensions | sort -u) \
        <(lk_echo_array VSCODE_EXTENSIONS | sort -u)))
    [ ${#INSTALL[@]} -eq 0 ] ||
        ! { lk_echo_array INSTALL |
            lk_console_detail_list "Installing:" extension extensions &&
            lk_confirm "Proceed?" Y; } ||
        for EXT in "${INSTALL[@]}"; do
            code --install-extension "$EXT"
        done
    REMOVE=($(comm -23 \
        <(code --list-extensions | sort -u) \
        <(lk_echo_array VSCODE_EXTENSIONS | sort -u)))
    [ ${#REMOVE[@]} -eq 0 ] || {
        [ ${#INSTALL[@]} -eq 0 ] || lk_console_blank
        lk_echo_array REMOVE |
            lk_console_detail_list "Orphaned:" extension extensions
        ! lk_confirm "Remove the above?" N ||
            for EXT in "${REMOVE[@]}"; do
                code --uninstall-extension "$EXT" || true
            done
    }
}

LK_VERBOSE=1
