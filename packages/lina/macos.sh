#!/bin/bash

. "$LK_BASE/share/packages/macos/dev.sh" || exit

HOMEBREW_TAPS+=(
    homebrew/cask-drivers
)

HOMEBREW_FORMULAE+=(
    lkrms/misc/gp-saml-gui
)

HOMEBREW_CASKS+=(
    acorn
    clockify
    dash
    messenger
    microsoft-office
    microsoft-teams
    nextcloud
    skype
    sonos
    spotify
    sublime-merge
    sublime-text
)

HOMEBREW_KEEP_CASKS+=(
    keyboardcleantool
    lingon-x
    rescuetime
)

MAS_APPS+=(
    417375580  # BetterSnapTool
    420212497  # Byword
    404705039  # Graphic
    1502839586 # Hand Mirror
    1055273043 # PDF Expert
    585829637  # Todoist
)

LOGIN_ITEMS+=(
    /Applications/Nextcloud.app
    /Applications/Todoist.app
)
