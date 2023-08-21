#!/bin/bash

set -euo pipefail

function php() {
    command php8.1 -dapc.enable_cli=1 "$@"
}

IFS=
php ~/public_html/occ update:check |
    grep -Eo '^Nextcloud [0-9]+(\.[0-9]+)+ is available\.' ||
    if [[ ${PIPESTATUS[*]} == 01 ]]; then
        # Exit cleanly if check succeeds but there are no updates to Nextcloud
        exit 0
    else
        echo "Unable to check for updates." >&2
        exit 1
    fi

# Remove unofficial files installed by lk-platform
rm -fv ~/public_html/.lk-settings-*

php ~/public_html/updater/updater.phar --no-interaction
