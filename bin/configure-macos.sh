#!/bin/bash

lk_die() { echo "${BS:+$BS: }$1" >&2 && exit 1; }
BS=${BASH_SOURCE[0]} &&
    [ ! -L "$BS" ] && _ROOT=$(cd "${BS%/*}/../desktop" && pwd -P) ||
    lk_die "unable to resolve path to script"

. "$_ROOT/../bin/settings-common.sh"
lk_require macos

lk_assert_not_root
lk_assert_is_macos

while [ $# -gt 0 ] && [[ $1 == -* ]]; do
    shift
done

_PRIV=${1-}
_PREFS=~/Library/Preferences
_APP_SUPPORT=~/Library/"Application Support"
_BASIC=
! lk_has_arg "--basic" || touch "$_ROOT/../.is_basic"
[ ! -e "$_ROOT/../.is_basic" ] || _BASIC=1

if lk_command_exists crontab; then
    lk_mktemp_with CRONTAB awk \
        -v STRETCHLY="$(lk_double_quote "$_ROOT/stretchly/stretchly.sh")" \
        '/^DISPLAY=/{next}$6=="stretchly"{$6=STRETCHLY}{print}' \
        "$_ROOT/cron/crontab"
    diff <(crontab -l) "$CRONTAB" >/dev/null || {
        lk_tty_print "Updating crontab"
        crontab <"$CRONTAB"
    }
    if ! launchctl list | awk '$3 == "net.hovancik.stretchly.align"' |
        grep . >/dev/null; then
        lk_tty_print "Creating launchd agent:" net.hovancik.stretchly.align
        lk_macos_launch_agent_install net.hovancik.stretchly.align \
            "$LK_BASE/bin/lk-run-after.sh" 60 "$_ROOT/stretchly/stretchly.sh"
    fi
fi

lk_tty_print "Cleaning up legacy settings"
FILE=~/Library/LaunchAgents/info.deseven.icanhazshortcut.plist
if [ -e "$FILE" ]; then
    lk_tty_run_detail launchctl unload -w "$FILE" || true
    lk_tty_run_detail rm -f "$FILE"
fi
! pgrep -xq iCanHazShortcut || lk_tty_run_detail pkill -x iCanHazShortcut

cleanup ~/.config/iCanHazShortcut

[ ! -d "$_PRIV" ] || {

    _PRIV=$(lk_realpath "$_PRIV")

    symlink_private_common "$_PRIV"
    symlink \
        "$_PRIV/espanso/" "$_PREFS/espanso"

    symlink_if_not_running \
        "$_PRIV/DBeaverData/" ~/Library/DBeaverData \
        DBeaver "pgrep -x dbeaver"

}

is_basic || [ -d /opt/db2_db2driver_for_jdbc_sqlj ] || {
    DB2_DRIVER=(~/Downloads/*/Db2/db2_db2driver_for_jdbc_sqlj.zip)
    [ ${#DB2_DRIVER[@]} -ne 1 ] || (umask 0022 &&
        cd /tmp &&
        rm -Rf "/tmp/db2_db2driver_for_jdbc_sqlj" &&
        unzip "${DB2_DRIVER[0]}" &&
        sudo mv "/tmp/db2_db2driver_for_jdbc_sqlj" /opt/)
}

DIR=/Applications/Firefox.app/Contents/Resources
is_basic || [ ! -d "$DIR" ] || {
    LK_SUDO=1
    lk_install -d -m 00755 "$DIR/defaults/pref"
    FILE=$DIR/defaults/pref/autoconfig.js
    lk_install -m 00644 "$FILE"
    lk_file_replace "$FILE" <<"EOF"
// the first line is ignored
pref("general.config.filename", "firefox.cfg");
pref("general.config.obscure_value", 0);
EOF
    FILE=$DIR/firefox.cfg
    lk_install -m 00644 "$FILE"
    lk_file_replace "$FILE" <<"EOF"
// the first line is ignored
defaultPref("services.sync.prefs.dangerously_allow_arbitrary", true);
EOF
    unset LK_SUDO
}

symlink "$_ROOT/.vimrc" ~/.vimrc
symlink "$_ROOT/.tidyrc" ~/.tidyrc
symlink "$_ROOT/.byoburc" ~/.byoburc
symlink "$_ROOT/byobu/" ~/.byobu
symlink -d "$_ROOT/git" ~/.config/git
symlink -d "$_ROOT/rubocop/.rubocop.yml" ~/.rubocop.yml
symlink -d "$_ROOT/displays/ColorSync/Profiles/" ~/Library/ColorSync/Profiles
symlink -d "$_ROOT/hammerspoon" ~/.hammerspoon

is_basic || symlink_if_not_running \
    "$_ROOT/nextcloud/sync-exclude.lst" "$_PREFS/Nextcloud/sync-exclude.lst" \
    Nextcloud "pgrep -x nextcloud"
[ -e "$_PREFS/Nextcloud/nextcloud.cfg" ] || [ ! -d "$_PREFS/Nextcloud" ] ||
    cp -v "$_ROOT/nextcloud/nextcloud.cfg" "$_PREFS/Nextcloud/nextcloud.cfg"

is_basic || symlink_if_not_running \
    "$_ROOT/subl/User/" "$_APP_SUPPORT/Sublime Text 3/Packages/User" \
    "Sublime Text 3" "pgrep -x 'Sublime Text'"

is_basic || symlink_if_not_running \
    "$_ROOT/smerge/User/" "$_APP_SUPPORT/Sublime Merge/Packages/User" \
    "$_ROOT/smerge/Default/" "$_APP_SUPPORT/Sublime Merge/Packages/Default" \
    "Sublime Merge" "pgrep -x sublime_merge"

FILE=~/Library/Containers/fr.handbrake.HandBrake/Data
FILE="$FILE/Library/Application Support/HandBrake/UserPresets.json"
is_basic || [ ! -d "${FILE%/*}" ] || {
    lk_tty_print "Checking HandBrake"
    pgrep -xq HandBrake &&
        lk_warn "cannot apply settings: HandBrake is running" ||
        lk_file_replace -b -f "$_ROOT/handbrake/presets.json" "$FILE"
}

lk_tty_print "Checking AltTab"
defaults write com.lwouis.alt-tab-macos hideWindowlessApps -string true
# Command (⌘)
defaults write com.lwouis.alt-tab-macos holdShortcut -string $'\xe2\x8c\x98'
# Option (⌥)
defaults write com.lwouis.alt-tab-macos holdShortcut2 -string $'\xe2\x8c\xa5'
# Shift-Tab (⇧⇥)
defaults write com.lwouis.alt-tab-macos previousWindowShortcut -string $'\xe2\x87\xa7\xe2\x87\xa5'
defaults write com.lwouis.alt-tab-macos menubarIcon -string 3
defaults write com.lwouis.alt-tab-macos mouseHoverEnabled -string false
defaults write com.lwouis.alt-tab-macos showOnScreen -string 0
defaults write com.lwouis.alt-tab-macos spacesToShow -string 1
defaults write com.lwouis.alt-tab-macos spacesToShow2 -string 1
is_basic || defaults write com.lwouis.alt-tab-macos startAtLogin -string true

! lk_command_exists espanso || {
    lk_tty_print "Checking espanso"
    [ -e ~/Library/LaunchAgents/com.federicoterzi.espanso.plist ] ||
        espanso register
}

symlink_if_not_running \
    "$_ROOT/flameshot/flameshot.ini" ~/.config/flameshot/flameshot.ini \
    Flameshot "pgrep -x flameshot"

lk_tty_print "Checking Flycut"
if pgrep -xq Flycut; then
    lk_warn "cannot apply settings: Flycut is running"
else
    FILE=~/Library/Containers/com.generalarcade.flycut/Data
    FILE=$FILE/Library/Preferences/com.generalarcade.flycut.plist
    [ ! -d "${FILE%/*}" ] || {
        lk_plist_set_file "$FILE"
        lk_plist_replace ":menuSelectionPastes" bool false
        lk_plist_replace ":savePreference" integer 2
        lk_plist_replace ":rememberNum" real 99
        lk_plist_maybe_add ":displayNum" real 20
        lk_plist_replace ":removeDuplicates" bool true
        lk_plist_replace ":pasteMovesToTop" bool true
        is_basic || {
            lk_plist_replace ":ShortcutRecorder mainHotkey" dict
            lk_plist_replace ":ShortcutRecorder mainHotkey:keyCode" integer 9
            lk_plist_replace ":ShortcutRecorder mainHotkey:modifierFlags" integer 1441792
        }
        lk_plist_replace ":menuIcon" integer 2
    }
fi

is_basic || {
    lk_tty_print "Checking Hammerspoon"
    if ! launchctl list | awk '$3 == "org.hammerspoon.Hammerspoon"' |
        grep . >/dev/null; then
        lk_tty_detail "Creating launchd agent"
        lk_macos_launch_agent_install org.hammerspoon.Hammerspoon \
            open -b org.hammerspoon.Hammerspoon
    fi
}

lk_tty_print "Checking iTerm2"
symlink "$_ROOT/iterm2/Scripts/" "$_APP_SUPPORT/iTerm2/Scripts"
defaults write com.googlecode.iterm2 AddNewTabAtEndOfTabs -bool false
defaults write com.googlecode.iterm2 AlternateMouseScroll -bool true
defaults write com.googlecode.iterm2 CopyWithStylesByDefault -bool true
defaults write com.googlecode.iterm2 DisallowCopyEmptyString -bool true
defaults write com.googlecode.iterm2 DoubleClickPerformsSmartSelection -bool true
defaults write com.googlecode.iterm2 EnableAPIServer -bool true
defaults write com.googlecode.iterm2 NoSyncTipsDisabled -bool true
defaults write com.googlecode.iterm2 OpenFileInNewWindows -bool true
defaults write com.googlecode.iterm2 OptionClickMovesCursor -bool false
defaults write com.googlecode.iterm2 QuitWhenAllWindowsClosed -bool true
defaults write com.googlecode.iterm2 SensitiveScrollWheel -bool true
defaults write com.googlecode.iterm2 SmartPlacement -bool true
defaults write com.googlecode.iterm2 SoundForEsc -bool false
defaults write com.googlecode.iterm2 SpacelessApplicationSupport -string ""
defaults write com.googlecode.iterm2 StatusBarPosition -int 1
defaults write com.googlecode.iterm2 StretchTabsToFillBar -bool false
defaults write com.googlecode.iterm2 SUEnableAutomaticChecks -bool true
defaults write com.googlecode.iterm2 SwitchTabModifier -int 5
defaults write com.googlecode.iterm2 UseBorder -bool true
defaults write com.googlecode.iterm2 VisualIndicatorForEsc -bool false
defaults delete com.googlecode.iterm2 TypingClearsSelection &>/dev/null || true

if pgrep -xq iTerm2; then
    lk_warn "cannot apply settings: iTerm2 is running"
else
    lk_plist_set_file "$_PREFS/com.googlecode.iterm2.plist"
    lk_plist_replace ":NoSyncConfirmRunOpenFile" bool true
    lk_plist_replace ":NoSyncConfirmRunOpenFile_selection" integer 0
    #lk_plist_maybe_add ":Window Arrangements" dict
    #lk_plist_replace ":Window Arrangements:No windows" array
    #lk_plist_replace ":Default Arrangement Name" string "No windows"
    #lk_plist_replace ":OpenArrangementAtStartup" bool true
    #lk_plist_replace ":OpenNoWindowsAtStartup" bool false

    lk_plist_replace_from_file ":Custom Color Presets" dict \
        "$_ROOT/iterm2/Custom Color Presets.plist"

    PLIST=$(lk_mktemp_file)
    lk_delete_on_exit "$PLIST"
    i=0
    while lk_plist_exists ":New Bookmarks:$i"; do
        GUID=$(lk_plist_get ":New Bookmarks:$i:Guid")
        lk_plist_replace ":NeverWarnAboutShortLivedSessions_${GUID}" bool true
        lk_plist_replace ":NeverWarnAboutShortLivedSessions_${GUID}_selection" integer 0
        lk_plist_replace ":New Bookmarks:$i:AWDS Pane Option" string "Recycle"
        lk_plist_replace ":New Bookmarks:$i:AWDS Tab Option" string "Recycle"
        lk_plist_replace ":New Bookmarks:$i:AWDS Window Option" string "Recycle"
        lk_plist_replace ":New Bookmarks:$i:BM Growl" bool false
        lk_plist_replace ":New Bookmarks:$i:Columns" integer 120
        lk_plist_replace ":New Bookmarks:$i:Custom Directory" string "Advanced"
        lk_plist_replace ":New Bookmarks:$i:Flashing Bell" bool true
        lk_plist_replace ":New Bookmarks:$i:Left Option Key Changeable" bool false
        lk_plist_replace ":New Bookmarks:$i:Mouse Reporting allow clicks and drags" bool false
        lk_plist_replace ":New Bookmarks:$i:Normal Font" string "Menlo-Regular 12"
        lk_plist_replace ":New Bookmarks:$i:Option Key Sends" integer 2
        lk_plist_replace ":New Bookmarks:$i:Place Prompt at First Column" bool false
        lk_plist_replace ":New Bookmarks:$i:Right Option Key Sends" integer 2
        lk_plist_replace ":New Bookmarks:$i:Rows" integer 35
        lk_plist_replace ":New Bookmarks:$i:Screen" integer -2
        lk_plist_replace ":New Bookmarks:$i:Scrollback Lines" integer 0
        lk_plist_replace ":New Bookmarks:$i:Show Mark Indicators" bool false
        lk_plist_replace ":New Bookmarks:$i:Silence Bell" bool true
        lk_plist_replace ":New Bookmarks:$i:Unlimited Scrollback" bool true
        lk_plist_maybe_delete ":New Bookmarks:$i:Prevent Opening in a Tab"
        lk_plist_maybe_delete ":New Bookmarks:$i:Title Components"
        lk_plist_maybe_delete ":New Bookmarks:$i:Use libtickit protocol"
        lk_plist_replace_from_file ":New Bookmarks:$i:Keyboard Map" dict \
            "$_ROOT/iterm2/Keyboard Map.plist"
        case "$i" in
        0)
            NAME=Default
            CUSTOM_COMMAND="Custom Shell"
            COMMAND=$(type -P bash)
            COLOR_PRESET=Elio
            ;;
        1)
            NAME="Bash 3.2"
            CUSTOM_COMMAND="No"
            COMMAND=""
            COLOR_PRESET=Broadcast
            ;;
        *)
            continue
            ;;
        esac
        lk_plist_replace ":New Bookmarks:$i:Name" string "$NAME"
        lk_plist_replace ":New Bookmarks:$i:Custom Command" string "$CUSTOM_COMMAND"
        lk_plist_replace ":New Bookmarks:$i:Command" string "$COMMAND"
        lk_plist_replace ":New Bookmarks:$i:Description" string "Default"
        plutil -extract "$COLOR_PRESET" xml1 -o "$PLIST" \
            "$_ROOT/iterm2/Custom Color Presets.plist" ||
            lk_warn "unable to extract color preset: $COLOR_PRESET" || continue
        for k in {"Ansi "{0..15},Background,Foreground}" Color"; do
            lk_plist_maybe_delete ":New Bookmarks:$i:$k"
        done
        lk_plist_merge_from_file ":New Bookmarks:$i" "$PLIST"
        ((++i))
    done
fi

is_basic || symlink_if_not_running \
    "$_ROOT/keepassxc/keepassxc.ini" "$_APP_SUPPORT/keepassxc/keepassxc.ini" \
    KeePassXC "pgrep -x KeePassXC"

lk_tty_print "Checking Magnet"
lk_plist_set_file "$_PREFS/com.crowdcafe.windowmagnet.plist"
lk_plist_replace ":appAlreadyLaunchedKey" bool true
lk_plist_replace ":launchAtLogin" bool true
lk_plist_replace ":expandWindowNorthWestComboKey" dict
lk_plist_replace ":expandWindowNorthWestComboKey:keyCode" integer 114
lk_plist_replace ":expandWindowNorthWestComboKey:modifierFlags" integer 786432
lk_plist_replace ":expandWindowNorthEastComboKey" dict
lk_plist_replace ":expandWindowNorthEastComboKey:keyCode" integer 116
lk_plist_replace ":expandWindowNorthEastComboKey:modifierFlags" integer 786432
lk_plist_replace ":expandWindowSouthWestComboKey" dict
lk_plist_replace ":expandWindowSouthWestComboKey:keyCode" integer 117
lk_plist_replace ":expandWindowSouthWestComboKey:modifierFlags" integer 786432
lk_plist_replace ":expandWindowSouthEastComboKey" dict
lk_plist_replace ":expandWindowSouthEastComboKey:keyCode" integer 121
lk_plist_replace ":expandWindowSouthEastComboKey:modifierFlags" integer 786432
lk_plist_replace ":expandWindowLeftThirdComboKey" dict
lk_plist_replace ":expandWindowLeftThirdComboKey:keyCode" integer 105
lk_plist_replace ":expandWindowLeftThirdComboKey:modifierFlags" integer 786432
lk_plist_replace ":expandWindowLeftTwoThirdsComboKey" dict
lk_plist_replace ":expandWindowLeftTwoThirdsComboKey:keyCode" integer 103
lk_plist_replace ":expandWindowLeftTwoThirdsComboKey:modifierFlags" integer 786432
lk_plist_replace ":expandWindowCenterThirdComboKey" dict
lk_plist_replace ":expandWindowCenterThirdComboKey:keyCode" integer 107
lk_plist_replace ":expandWindowCenterThirdComboKey:modifierFlags" integer 786432
lk_plist_replace ":expandWindowRightTwoThirdsComboKey" dict
lk_plist_replace ":expandWindowRightTwoThirdsComboKey:keyCode" integer 111
lk_plist_replace ":expandWindowRightTwoThirdsComboKey:modifierFlags" integer 786432
lk_plist_replace ":expandWindowRightThirdComboKey" dict
lk_plist_replace ":expandWindowRightThirdComboKey:keyCode" integer 113
lk_plist_replace ":expandWindowRightThirdComboKey:modifierFlags" integer 786432
lk_plist_replace ":moveWindowToNextDisplay" dict
lk_plist_replace ":moveWindowToNextDisplay:keyCode" integer 30
lk_plist_replace ":moveWindowToNextDisplay:modifierFlags" integer 786432
lk_plist_replace ":moveWindowToPreviousDisplay" dict
lk_plist_replace ":moveWindowToPreviousDisplay:keyCode" integer 33
lk_plist_replace ":moveWindowToPreviousDisplay:modifierFlags" integer 786432
lk_plist_replace ":centerWindowComboKey" dict
lk_plist_replace ":centerWindowComboKey:keyCode" integer 49
lk_plist_replace ":centerWindowComboKey:modifierFlags" integer 786432
lk_plist_replace ":restoreWindowComboKey" dict
lk_plist_replace ":restoreWindowComboKey:keyCode" integer 101
lk_plist_replace ":restoreWindowComboKey:modifierFlags" integer 786432

lk_tty_print "Checking KeepingYouAwake"
defaults write info.marcel-dierkes.KeepingYouAwake \
    "info.marcel-dierkes.KeepingYouAwake.LaunchAtLogin" -bool true

is_basic || symlink_if_not_running \
    "$_ROOT/stretchly/config.json" "$_APP_SUPPORT/stretchly/config.json" \
    Stretchly "pgrep -x stretchly"

is_basic || {
    lk_tty_print "Checking Todoist"
    FILE=~/Library/Containers/com.todoist.mac.Todoist/Data
    FILE="$FILE/Library/Application Support/Todoist/config.json"
    [ ! -e "$FILE" ] || {
        TEMP=$(lk_mktemp_file)
        lk_delete_on_exit "$TEMP"
        jq '
del(.global_shortcuts.quick_add) |
  .global_shortcuts.activate = "Ctrl+Cmd+o"' "$FILE" >"$TEMP"
        diff <(jq '.' "$FILE") "$TEMP" >/dev/null ||
            if pgrep -x Todoist >/dev/null; then
                lk_warn "cannot apply settings: Todoist is running"
            else
                lk_file_keep_original "$FILE"
                lk_file_replace -f "$TEMP" "$FILE"
            fi
    }
}

is_basic || {
    lk_tty_print "Checking Harvest"
    # ^⌘O
    defaults write com.getharvest.harvestxapp kNewTimerShortcut "<data>
YnBsaXN0MDDUAQIDBAUGBwpYJHZlcnNpb25ZJGFyY2hpdmVyVCR0b3BYJG9iamVjdHMS
AAGGoF8QD05TS2V5ZWRBcmNoaXZlctEICVRyb290gAGjCwwTVSRudWxs0w0ODxAREldL
ZXlDb2RlViRjbGFzc11Nb2RpZmllckZsYWdzEASAAhIAFAAA0hQVFhdaJGNsYXNzbmFt
ZVgkY2xhc3Nlc1tNQVNTaG9ydGN1dKIYGVtNQVNTaG9ydGN1dFhOU09iamVjdAgRGiQp
MjdJTFFTV11kbHOBg4WKj5qjr7K+AAAAAAAAAQEAAAAAAAAAGgAAAAAAAAAAAAAAAAAA
AMc=
</data>"
    for KEY in kShowFavoritesShortcut \
        kShowTimeSummaryShortcut \
        kShowTimesheetShortcut; do
        # Disabled
        defaults write com.getharvest.harvestxapp "$KEY" "<data>
YnBsaXN0MDDUAQIDBAUGBwpYJHZlcnNpb25ZJGFyY2hpdmVyVCR0b3BYJG9iamVjdHMS
AAGGoF8QD05TS2V5ZWRBcmNoaXZlctEICVRyb290gAChC1UkbnVsbAgRGiQpMjdJTFFT
VQAAAAAAAAEBAAAAAAAAAAwAAAAAAAAAAAAAAAAAAABb
</data>"
    done
}

# TODO: configure Typora via `defaults` in lieu of symlinking
# abnerworks.Typora.plist
is_basic || symlink_if_not_running \
    "$_ROOT/typora/themes" "$_APP_SUPPORT/abnerworks.Typora/themes" \
    Typora "pgrep -x Typora"

is_basic || symlink_if_not_running \
    "$_ROOT/vscode/settings.json" "$_APP_SUPPORT/Code/User/settings.json" \
    "$_ROOT/vscode/keybindings.mac.json" "$_APP_SUPPORT/Code/User/keybindings.json" \
    "$_ROOT/vscode/snippets" "$_APP_SUPPORT/Code/User/snippets" \
    "VS Code" "pgrep -f '^/Applications/Visual Studio Code.app/Contents/MacOS/Electron'"

FILE=/Applications/VSCodium.app/Contents/Resources/app/product.json
if [ -f "$FILE" ]; then
    VSCODE_PRODUCT_JSON=$(jq \
        '.extensionsGallery = {
    "serviceUrl": "https://marketplace.visualstudio.com/_apis/public/gallery",
    "itemUrl": "https://marketplace.visualstudio.com/items"
}' <"$FILE")
    diff <(jq <"$FILE") <(echo "$VSCODE_PRODUCT_JSON") >/dev/null ||
        LK_SUDO=1 lk_file_replace "$FILE" "$VSCODE_PRODUCT_JSON"
fi

lk_macos_maybe_install_pkg_url \
    "com.Brother.Brotherdriver.Brother_PrinterDrivers_MonochromeLaser" \
    "https://download.brother.com/welcome/dlf104416/Brother_PrinterDrivers_MonochromeLaser_1_3_0.dmg" \
    "Brother Printer Drivers (Monochrome Laser)"

lk_macos_maybe_install_pkg_url \
    "com.brother.brotherdriver.BrotherCL17" \
    "https://download.brother.com/welcome/dlf104984/Brother_PrinterDrivers_CL17_2_1_6_0.dmg" \
    "Brother Printer Drivers (Color Laser)"

# use `lpinfo -m` for driver names
lk_tty_print "Checking printers"
(
    lk_tty_detail "Brother HL-5450DN"
    sudo lpadmin -p HL5450DN -E \
        -D "Brother HL-5450DN" \
        -L "black and white" \
        -m "Library/Printers/PPDs/Contents/Resources/Brother HL-5450DN series CUPS.gz" \
        -v "socket://10.10.10.10" \
        -o PageSize=A4 \
        -o Duplex=DuplexNoTumble \
        -o printer-error-policy=abort-job

    lk_tty_detail "Brother HL-L3230CDW"
    sudo lpadmin -p HLL3230CDW -E \
        -D "Brother HL-L3230CDW" \
        -L "colour" \
        -m "Library/Printers/PPDs/Contents/Resources/Brother HL-L3230CDW series CUPS.gz" \
        -v "socket://10.10.10.11" \
        -o PageSize=A4 \
        -o Duplex=None \
        -o BRResolution=600x2400dpi \
        -o BRColorMatching=Normal \
        -o BRGray=ON \
        -o BREnhanceBlkPrt=OFF \
        -o BRImproveOutput=OFF \
        -o printer-error-policy=abort-job
) 2>/dev/null || lk_die "Error configuring printers"

lk_tty_print "Checking macOS"

if ! nvram StartupMute 2>/dev/null | grep -E "$S%01\$" >/dev/null; then
    lk_tty_detail "Disabling startup sound"
    sudo nvram StartupMute=%01
fi

# Trackpad
defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true
defaults write com.apple.AppleMultitouchTrackpad TrackpadCornerSecondaryClick -int 2
defaults write com.apple.AppleMultitouchTrackpad TrackpadRightClick -bool false
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadCornerSecondaryClick -int 2
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadRightClick -bool false
defaults write NSGlobalDomain com.apple.mouse.tapBehavior -int 1
defaults -currentHost write NSGlobalDomain com.apple.mouse.tapBehavior -int 1
defaults -currentHost write NSGlobalDomain com.apple.trackpad.trackpadCornerClickBehavior -int 1
defaults -currentHost write NSGlobalDomain com.apple.trackpad.enableSecondaryClick -bool false

defaults write com.apple.AppleMultitouchTrackpad ActuateDetents -bool false
defaults write com.apple.AppleMultitouchTrackpad ForceSuppressed -bool true

# Keyboard
defaults write NSGlobalDomain AppleKeyboardUIMode -int 3
is_basic || defaults write NSGlobalDomain com.apple.keyboard.fnState -bool true

defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false
defaults write NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled -bool false
is_basic || defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false
defaults write NSGlobalDomain WebAutomaticSpellingCorrectionEnabled -bool false

# Touch Bar typing suggestions
is_basic || defaults write NSGlobalDomain NSAutomaticTextCompletionEnabled -bool false
is_basic || defaults write com.apple.touchbar.agent PresentationModeGlobal -string functionKeys
is_basic || defaults write com.apple.touchbar.agent PresentationModeFnModes -dict functionKeys fullControlStrip

# Press Fn to: Do Nothing
is_basic || defaults write com.apple.HIToolbox AppleFnUsageType -int 0

defaults write com.apple.HIToolbox AppleDictationAutoEnable -int 0
# Disable Dictation > Shortcut
#defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add \
#    164 "<dict><key>enabled</key><false/></dict>"

# Sound
defaults write NSGlobalDomain com.apple.sound.beep.feedback -bool true

# General
is_basic || defaults write com.apple.loginwindow TALLogoutSavesState -bool false

defaults write NSGlobalDomain AppleAccentColor -int 0
defaults write NSGlobalDomain AppleHighlightColor -string "1.000000 0.733333 0.721569 Red"
defaults write NSGlobalDomain AppleShowScrollBars -string Always
defaults write NSGlobalDomain NSDocumentSaveNewDocumentsToCloud -bool false
is_basic || defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
is_basic || defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool true
is_basic || defaults write NSGlobalDomain NSTableViewDefaultSizeMode -int 1
is_basic || defaults write NSGlobalDomain PMPrintingExpandedStateForPrint -bool true
is_basic || defaults write NSGlobalDomain PMPrintingExpandedStateForPrint2 -bool true

defaults write NSGlobalDomain NSCloseAlwaysConfirmsChanges -bool true
defaults write NSGlobalDomain NSDisableAutomaticTermination -bool true
defaults write com.apple.systempreferences NSQuitAlwaysKeepsWindows -bool false

is_basic || defaults write NSGlobalDomain NSAutomaticWindowAnimationsEnabled -bool false
is_basic || defaults write NSGlobalDomain NSWindowResizeTime -float 0.001
is_basic || defaults write NSGlobalDomain QLPanelAnimationDuration -float 0

# Improve Big Sur performance, especially on 4K displays (note: these settings
# are applied to their com.apple.Accessibility counterparts automatically)
is_basic || defaults write com.apple.universalaccess reduceMotion -bool true
is_basic || defaults write com.apple.universalaccess reduceTransparency -bool true

is_basic || defaults write com.apple.menuextra.clock DateFormat -string "EEE d MMM  h:mm:ss a"
is_basic || defaults write com.apple.screencapture location -string "${LK_SCREENSHOT_DIR:-$HOME/Desktop}"
defaults -currentHost write com.apple.ImageCapture disableHotPlug -bool true

# Screen Saver
defaults -currentHost write com.apple.screensaver idleTime -int 300
defaults -currentHost write com.apple.screensaver showClock -bool true

# Hot Corners (5 = Start Screen Saver)
defaults write com.apple.dock wvous-tr-corner -int 5
defaults write com.apple.dock wvous-tr-modifier -int 0

# Dock
defaults write com.apple.dock appswitcher-all-displays -bool true
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock autohide-delay -float 0
defaults write com.apple.dock launchanim -bool false
defaults write com.apple.dock magnification -bool false
defaults write com.apple.dock mineffect -string scale
defaults write com.apple.dock minimize-to-application -bool true
defaults write com.apple.dock show-process-indicators -bool true
defaults write com.apple.dock show-recents -bool false
is_basic || defaults write com.apple.dock size-immutable -bool true
is_basic || defaults write com.apple.dock tilesize -int 60

# Finder
defaults write com.apple.finder FXDefaultSearchScope -string SCcf
is_basic || defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false
defaults write com.apple.finder FXPreferredViewStyle -string clmv
defaults write com.apple.finder _FXSortFoldersFirst -bool true
defaults write com.apple.finder NewWindowTarget -string PfHm
defaults write com.apple.finder NewWindowTargetPath -string "file://$HOME/"
is_basic || defaults write com.apple.finder ShowPathbar -bool true
defaults write com.apple.finder ShowRecentTags -bool false
is_basic || defaults write com.apple.finder ShowStatusBar -bool true
is_basic || defaults write com.apple.finder WarnOnEmptyTrash -bool false
is_basic || defaults write com.apple.finder DisableAllAnimations -bool true

defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true

# Messages
defaults write com.apple.MobileSMS PlaySoundsKey -bool false

# Safari
is_basic || defaults write com.apple.Safari AlwaysRestoreSessionAtLaunch -bool true
defaults write com.apple.Safari AutoOpenSafeDownloads -bool false
defaults write com.apple.Safari DownloadsClearingPolicy -int 0
defaults write com.apple.Safari HistoryAgeInDaysLimit -int 365000
defaults write com.apple.Safari NewTabBehavior -int 1
defaults write com.apple.Safari NewWindowBehavior -int 1
defaults write com.apple.Safari SendDoNotTrackHTTPHeader -bool true
defaults write com.apple.Safari ShowFullURLInSmartSearchField -bool true
defaults write com.apple.Safari ShowIconsInTabs -bool true
is_basic || defaults write com.apple.Safari SuppressSearchSuggestions -bool true

is_basic || defaults write com.apple.Safari IncludeDevelopMenu -bool true
is_basic || defaults write com.apple.Safari WebKitDeveloperExtrasEnabledPreferenceKey -bool true
is_basic || defaults write com.apple.Safari WebKitPreferences.developerExtrasEnabled -bool true
is_basic || defaults write com.apple.Safari.SandboxBroker ShowDevelopMenu -bool true

# Mail
defaults write com.apple.mail ConversationViewSpansMailboxes -bool false
defaults write com.apple.mail DeleteAttachmentsAfterHours -int 0
defaults write com.apple.mail NewMessagesSoundName -string ""
defaults write com.apple.mail PlayMailSounds -bool false
defaults write com.apple.mail ShouldShowUnreadMessagesInBold -bool true
if ! is_basic && lk_has_arg "--reset"; then
    defaults write com.apple.mail InboxViewerAttributes -dict-add \
        DisplayInThreadedMode NO SortOrder received-date SortedDescending YES
    defaults write com.apple.mail SentMessagesViewerAttributes -dict-add \
        DisplayInThreadedMode NO SortOrder received-date SortedDescending YES
    defaults write com.apple.mail ThreadingDefault -bool false
    lk_mapfile FILES <(find ~/Library/Mail -type d -name '*.mbox' \
        -exec test -f '{}/Info.plist' \; -print | sed -E 's/$/\/Info.plist/')
    for FILE in ${FILES+"${FILES[@]}"}; do
        lk_plist_set_file "$FILE"
        lk_plist_replace ":DisplayInThreadedMode" string NO &&
            lk_plist_replace ":SortOrder" string received-date &&
            lk_plist_replace ":SortedDescending" string YES &&
            lk_plist_maybe_delete ":MailboxViewingState" ||
            lk_warn "error updating $FILE" || break
    done
fi

# "Use classic layout" (<=10.14)
defaults write com.apple.mail RichMessageList -bool false

# "View" > "Use Column Layout" (>=10.15)
defaults write com.apple.mail ColumnLayoutMessageList -int 1

if ! is_basic; then
    if lk_has_arg "--reset"; then
        lk_macos_kb_reset_shortcuts NSGlobalDomain
        lk_macos_kb_reset_shortcuts com.apple.mail
        lk_macos_kb_reset_shortcuts abnerworks.Typora
    fi

    lk_macos_kb_add_shortcut com.apple.mail "Mark All Messages as Read" $'@$c'
    lk_macos_kb_add_shortcut com.apple.mail "Send" $'@\xe2\x86\xa9'
    lk_macos_kb_add_shortcut abnerworks.Typora "Toggle Sidebar" $'@$b'

    DISABLE=(
        7 8 9 10 11 12 13 57 # Control-F1 to Control-F8
        36 37                # F11 ("Show Desktop")
        70                   # Control-Command-D ("Look Up")
        127                  # Control-0 ("Switch to Desktop 10")
        128 129 130          # Control-Option-1 to Control-Option-6
        131 132 133          # ("Switch to Desktop" for desktops 11 to 16)
    )
    for KEY in ${DISABLE+"${DISABLE[@]}"}; do
        defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add "$KEY" "<dict><key>enabled</key><false/></dict>"
    done

    # Control-Command-<n> (^⌘<n>) -> "Switch to Desktop" for desktops 1 to 9
    KEY_CODES=(18 19 20 21 23 22 26 28 25)
    for i in {0..8}; do
        defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add $((118 + i)) "<dict><key>enabled</key><true/><key>value</key><dict><key>parameters</key><array><integer>$((49 + i))</integer><integer>${KEY_CODES[i]}</integer><integer>1310720</integer></array><key>type</key><string>standard</string></dict></dict>"
    done

    # Control-Option-Q (⌃⌥Q) -> "Turn Do Not Disturb On/Off"
    defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 175 "<dict><key>enabled</key><true/><key>value</key><dict><key>parameters</key><array><integer>113</integer><integer>12</integer><integer>786432</integer></array><key>type</key><string>standard</string></dict></dict>"

    # Control-Command-Left Arrow (^⌘←) -> "Move left a space"
    defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 79 "<dict><key>enabled</key><true/><key>value</key><dict><key>parameters</key><array><integer>65535</integer><integer>123</integer><integer>11796480</integer></array><key>type</key><string>standard</string></dict></dict>"
    defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 80 "<dict><key>enabled</key><true/><key>value</key><dict><key>parameters</key><array><integer>65535</integer><integer>123</integer><integer>11927552</integer></array><key>type</key><string>standard</string></dict></dict>"

    # Control-Command-Right Arrow (^⌘→) -> "Move right a space"
    defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 81 "<dict><key>enabled</key><true/><key>value</key><dict><key>parameters</key><array><integer>65535</integer><integer>124</integer><integer>11796480</integer></array><key>type</key><string>standard</string></dict></dict>"
    defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 82 "<dict><key>enabled</key><true/><key>value</key><dict><key>parameters</key><array><integer>65535</integer><integer>124</integer><integer>11927552</integer></array><key>type</key><string>standard</string></dict></dict>"

    lk_tty_print "Checking Dock"
    "$_ROOT/../bin/configure-macos-dock.sh"

    FILE=~/Library/Preferences/com.kapeli.dashdoc.plist
    START_DASH=
    if [ -e "$FILE" ]; then
        lk_tty_print "Checking Dash"
        ! pkill -xu "$USER" Dash &>/dev/null || START_DASH=1
        defaults write com.kapeli.dashdoc didShowStatusIconHello -bool true
        defaults write com.kapeli.dashdoc statusIconHelloSuppressCheckboxState -bool false
        defaults write com.kapeli.dashdoc syncFolderPath -string "$_ROOT/dash"
        if defaults read com.kapeli.dashdoc docsets &>/dev/null; then
            "$LK_BASE/lib/python/plist_sort.py" "$FILE" "$FILE" docsets docsetName
        fi
    fi
fi

killall -u "$USER" cfprefsd
! is_basic || killall Dock
killall Finder

is_basic || [ -z "${START_DASH-}" ] || open -b com.kapeli.dashdoc

is_basic || vscode_sync_extensions "$_ROOT/vscode/extensions.sh"
