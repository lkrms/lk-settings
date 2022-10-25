#!/bin/bash

. "$LK_BASE/share/packages/macos/desktop.sh" || exit

HOMEBREW_TAPS+=(
    homebrew/cask-drivers
)

HOMEBREW_CASKS+=(
    messenger
    microsoft-office
    microsoft-teams
    nextcloud
    skype
    sonos
    spotify
)

MAS_APPS+=(
    1502839586 # Hand Mirror
    441258766  # Magnet
    1055273043 # PDF Expert
    585829637  # Todoist
    1303222628 # Paprika
)
