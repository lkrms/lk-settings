#!/bin/bash

# shellcheck disable=SC1090,SC2015,SC2034,SC2207

set -euo pipefail
lk_die() { echo "${BS:+$BS: }$1" >&2 && exit 1; }
BS=${BASH_SOURCE[0]} &&
    [ ! -L "$BS" ] && SCRIPT_DIR=$(cd "${BS%/*}" && pwd -P) ||
    lk_die "unable to resolve path to script"

[ -d "${LK_BASE:-}" ] || lk_die "LK_BASE not set"

include=macos . "$LK_BASE/lib/bash/common.sh"

lk_assert_not_root
lk_assert_is_macos

LK_VERBOSE=2

set +e
shopt -s nullglob

PRIVATE_DIR=~/.cloud-settings

[ ! -d "$PRIVATE_DIR" ] || {

    lk_symlink "$PRIVATE_DIR/.bashrc" ~/.bashrc
    lk_symlink "$PRIVATE_DIR/.gitconfig" ~/.gitconfig
    lk_symlink "$PRIVATE_DIR/.gitignore" ~/.gitignore
    lk_symlink "$PRIVATE_DIR/acme.sh/" ~/.acme.sh
    lk_symlink "$PRIVATE_DIR/aws/" ~/.aws
    lk_symlink "$PRIVATE_DIR/espanso/" ~/Library/Preferences/espanso
    lk_symlink "$PRIVATE_DIR/linode-cli/linode-cli" ~/.config/linode-cli
    lk_symlink "$PRIVATE_DIR/ssh/" ~/.ssh
    lk_symlink "$PRIVATE_DIR/unison/" ~/"Library/Application Support/unison"

    pgrep -xq "dbeaver" &&
        lk_warn "cannot apply settings while DBeaver is running" ||
        lk_symlink "$PRIVATE_DIR/DBeaverData/" ~/Library/DBeaverData

    for FILE in "$PRIVATE_DIR"/.*-settings; do
        lk_symlink "$FILE" ~/"${FILE##*/}"
    done

}

[ -d /opt/db2_db2driver_for_jdbc_sqlj ] || {
    DB2_DRIVER=(~/Downloads/*/Db2/db2_db2driver_for_jdbc_sqlj.zip)
    [ ${#DB2_DRIVER[@]} -ne 1 ] || {
        pushd /tmp >/dev/null &&
            rm -Rf "/tmp/db2_db2driver_for_jdbc_sqlj" &&
            unzip "${DB2_DRIVER[0]}" &&
            sudo mv "/tmp/db2_db2driver_for_jdbc_sqlj" /opt/ &&
            popd >/dev/null
    }
}

[ ! -d /Applications/Firefox.app/Contents/Resources ] || {
    sudo mkdir -p /Applications/Firefox.app/Contents/Resources/defaults/pref
    printf '%s\n' \
        '// the first line is ignored' \
        'pref("general.config.filename", "firefox.cfg");' \
        'pref("general.config.obscure_value", 0);' |
        sudo tee /Applications/Firefox.app/Contents/Resources/defaults/pref/autoconfig.js >/dev/null
    printf '%s\n' \
        '// the first line is ignored' \
        'defaultPref("services.sync.prefs.dangerously_allow_arbitrary", true);' |
        sudo tee /Applications/Firefox.app/Contents/Resources/firefox.cfg >/dev/null
}

lk_symlink "$SCRIPT_DIR/.vimrc" ~/.vimrc
lk_symlink "$SCRIPT_DIR/.tidyrc" ~/.tidyrc
lk_symlink "$SCRIPT_DIR/.byoburc" ~/.byoburc
lk_symlink "$SCRIPT_DIR/byobu/" ~/.byobu

lk_symlink "$SCRIPT_DIR/nextcloud/sync-exclude.lst" \
    ~/Library/Preferences/Nextcloud/sync-exclude.lst && {
    [ -e ~/Library/Preferences/Nextcloud/nextcloud.cfg ] ||
        cp -v "$SCRIPT_DIR/nextcloud/nextcloud.cfg" \
            ~/Library/Preferences/Nextcloud/nextcloud.cfg
}

lk_console_message "Checking Sublime Text 3"
pgrep -xq "Sublime Text" &&
    lk_warn "cannot apply settings while Sublime Text 3 is running" ||
    lk_symlink "$SCRIPT_DIR/subl/User/" \
        ~/"Library/Application Support/Sublime Text 3/Packages/User"

lk_console_message "Checking Sublime Merge"
pgrep -xq "sublime_merge" &&
    lk_warn "cannot apply settings while Sublime Merge is running" ||
    lk_symlink "$SCRIPT_DIR/smerge/User/" \
        ~/"Library/Application Support/Sublime Merge/Packages/User"

lk_console_message "Checking HandBrake"
pgrep -xq "HandBrake" &&
    lk_warn "cannot apply settings while HandBrake is running" || {
    FILE=~/"Library/Containers/fr.handbrake.HandBrake/Data/Library/Application Support/HandBrake/UserPresets.json"
    diff -Nq "$SCRIPT_DIR/handbrake/presets.json" "$FILE" >/dev/null || {
        lk_file_backup "$FILE" &&
            mkdir -pv "${FILE%/*}" &&
            cp -fv "$SCRIPT_DIR/handbrake/presets.json" "$FILE"
    }
}

lk_console_message "Checking espanso"
! lk_command_exists espanso ||
    [ -e ~/Library/LaunchAgents/com.federicoterzi.espanso.plist ] ||
    espanso register

lk_console_message "Checking Flycut"
pgrep -xq "Flycut" &&
    lk_warn "cannot apply settings while Flycut is running" || {
    lk_plist_set_file ~/Library/Preferences/com.generalarcade.flycut.plist
    lk_plist_replace ":menuSelectionPastes" bool false
    lk_plist_replace ":savePreference" integer 2
    lk_plist_replace ":rememberNum" real 99
    lk_plist_maybe_add ":displayNum" real 20
    lk_plist_replace ":removeDuplicates" bool true
    lk_plist_replace ":pasteMovesToTop" bool true
    lk_plist_replace ":ShortcutRecorder mainHotkey" dict
    lk_plist_replace ":ShortcutRecorder mainHotkey:keyCode" integer 9
    lk_plist_replace ":ShortcutRecorder mainHotkey:modifierFlags" integer 1441792
    lk_plist_replace ":menuIcon" integer 2
}

lk_console_message "Checking iCanHazShortcut"
pgrep -xq "iCanHazShortcut" &&
    lk_warn "cannot apply settings while iCanHazShortcut is running" ||
    lk_symlink "$SCRIPT_DIR/icanhazshortcut/" \
        ~/.config/iCanHazShortcut
FILE=~/Library/LaunchAgents/info.deseven.icanhazshortcut.plist
if [ -d /Applications/iCanHazShortcut.app ] && [ ! -e "$FILE" ]; then
    mkdir -pv "${FILE%/*}"
    cat >"$FILE" <<"EOF"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>info.deseven.icanhazshortcut</string>
	<key>ProgramArguments</key>
	<array>
		<string>/usr/bin/open</string>
		<string>/Applications/iCanHazShortcut.app</string>
	</array>
	<key>RunAtLoad</key>
	<true/>
	<key>KeepAlive</key>
	<false/>
	<key>LimitLoadToSessionType</key>
	<string>Aqua</string></dict>
</plist>
EOF
    launchctl load -w "$FILE"
fi

lk_console_message "Checking iTerm2"
defaults write com.googlecode.iterm2 AddNewTabAtEndOfTabs -bool false
defaults write com.googlecode.iterm2 AlternateMouseScroll -bool true
defaults write com.googlecode.iterm2 CopyWithStylesByDefault -bool true
defaults write com.googlecode.iterm2 DisallowCopyEmptyString -bool true
defaults write com.googlecode.iterm2 DoubleClickPerformsSmartSelection -bool true
defaults write com.googlecode.iterm2 OptionClickMovesCursor -bool false
defaults write com.googlecode.iterm2 QuitWhenAllWindowsClosed -bool false
defaults write com.googlecode.iterm2 SensitiveScrollWheel -bool true
defaults write com.googlecode.iterm2 SmartPlacement -bool true
defaults write com.googlecode.iterm2 SoundForEsc -bool false
defaults write com.googlecode.iterm2 SpacelessApplicationSupport -string ""
defaults write com.googlecode.iterm2 StatusBarPosition -int 1
defaults write com.googlecode.iterm2 StretchTabsToFillBar -bool false
defaults write com.googlecode.iterm2 SUEnableAutomaticChecks -bool true
defaults write com.googlecode.iterm2 SwitchTabModifier -int 5
defaults write com.googlecode.iterm2 TypingClearsSelection -bool false
defaults write com.googlecode.iterm2 UseBorder -bool true
defaults write com.googlecode.iterm2 VisualIndicatorForEsc -bool false

pgrep -xq iTerm2 &&
    lk_warn "cannot apply settings while iTerm2 is running" || {
    lk_plist_set_file ~/Library/Preferences/com.googlecode.iterm2.plist
    lk_plist_maybe_add ":Window Arrangements" dict
    lk_plist_replace ":Window Arrangements:No windows" array
    lk_plist_replace ":Default Arrangement Name" string "No windows"
    lk_plist_replace ":OpenArrangementAtStartup" bool true
    lk_plist_replace ":OpenNoWindowsAtStartup" bool false

    lk_plist_replace_from_file ":Custom Color Presets" dict \
        "$SCRIPT_DIR/iterm2/Custom Color Presets.plist"

    ! lk_plist_exists ":New Bookmarks:0" &&
        lk_warn "no profile to configure" || {
        lk_plist_replace ":New Bookmarks:0:AWDS Pane Option" string "Recycle"
        lk_plist_replace ":New Bookmarks:0:AWDS Tab Option" string "Recycle"
        lk_plist_replace ":New Bookmarks:0:AWDS Window Option" string "Recycle"
        lk_plist_replace ":New Bookmarks:0:BM Growl" bool false
        lk_plist_replace ":New Bookmarks:0:Columns" integer 120
        lk_plist_replace ":New Bookmarks:0:Custom Directory" string "Advanced"
        lk_plist_replace ":New Bookmarks:0:Flashing Bell" bool true
        lk_plist_replace ":New Bookmarks:0:Normal Font" string "Menlo-Regular 12"
        lk_plist_replace ":New Bookmarks:0:Option Key Sends" integer 2
        lk_plist_replace ":New Bookmarks:0:Place Prompt at First Column" bool false
        lk_plist_replace ":New Bookmarks:0:Right Option Key Sends" integer 2
        lk_plist_replace ":New Bookmarks:0:Rows" integer 35
        lk_plist_replace ":New Bookmarks:0:Screen" integer -2
        lk_plist_replace ":New Bookmarks:0:Scrollback Lines" integer 0
        lk_plist_replace ":New Bookmarks:0:Show Mark Indicators" bool false
        lk_plist_replace ":New Bookmarks:0:Silence Bell" bool true
        lk_plist_replace ":New Bookmarks:0:Title Components" integer 512
        lk_plist_replace ":New Bookmarks:0:Unlimited Scrollback" bool true
        lk_plist_replace_from_file ":New Bookmarks:0:Keyboard Map" dict \
            "$SCRIPT_DIR/iterm2/Keyboard Map.plist"
    }
}

lk_console_message "Checking KeePassXC"
pgrep -xq "KeePassXC" &&
    lk_warn "cannot apply settings while KeePassXC is running" ||
    lk_symlink "$SCRIPT_DIR/keepassxc/keepassxc.ini" \
        ~/"Library/Application Support/keepassxc/keepassxc.ini"

lk_console_message "Checking Magnet"
lk_plist_set_file ~/Library/Preferences/com.crowdcafe.windowmagnet.plist
lk_plist_replace ":expandWindowNorthWestComboKey" dict
lk_plist_replace ":expandWindowNorthEastComboKey" dict
lk_plist_replace ":expandWindowSouthWestComboKey" dict
lk_plist_replace ":expandWindowSouthEastComboKey" dict
lk_plist_replace ":expandWindowLeftThirdComboKey" dict
lk_plist_replace ":expandWindowLeftTwoThirdsComboKey" dict
lk_plist_replace ":expandWindowCenterThirdComboKey" dict
lk_plist_replace ":expandWindowRightTwoThirdsComboKey" dict
lk_plist_replace ":expandWindowRightThirdComboKey" dict
lk_plist_replace ":moveWindowToNextDisplay" dict
lk_plist_replace ":moveWindowToPreviousDisplay" dict
lk_plist_replace ":centerWindowComboKey" dict
lk_plist_replace ":centerWindowComboKey:keyCode" integer 49
lk_plist_replace ":centerWindowComboKey:modifierFlags" integer 786432

lk_console_message "Checking Stretchly"
pgrep -xq "stretchly" &&
    lk_warn "cannot apply settings while Stretchly is running" ||
    lk_symlink "$SCRIPT_DIR/stretchly/config.json" \
        ~/"Library/Application Support/stretchly/config.json"

#for KEY in TDQuickAddShortcut TDToggleShortcut; do
#    defaults export com.todoist.mac.Todoist - |
#        plutil -extract "$KEY" xml1 -o - - |
#        xq -x '{data:.plist.data}'
#done

lk_console_message "Checking Todoist"
# ^⌘Q
defaults write com.todoist.mac.Todoist TDQuickAddShortcut "<data>
YnBsaXN0MDDUAQIDBAUGBwpYJHZlcnNpb25ZJGFyY2hpdmVyVCR0b3BYJG9iamVjdHMSAAGGoF8Q
D05TS2V5ZWRBcmNoaXZlctEICVRyb290gAGjCwwTVSRudWxs0w0ODxAREldLZXlDb2RlViRjbGFz
c11Nb2RpZmllckZsYWdzEAyAAhIAFAAA0hQVFhdaJGNsYXNzbmFtZVgkY2xhc3Nlc1tNQVNTaG9y
dGN1dKIYGVtNQVNTaG9ydGN1dFhOU09iamVjdAgRGiQpMjdJTFFTV11kbHOBg4WKj5qjr7K+AAAA
AAAAAQEAAAAAAAAAGgAAAAAAAAAAAAAAAAAAAMc=
</data>"
# ^⌘O
defaults write com.todoist.mac.Todoist TDToggleShortcut "<data>
YnBsaXN0MDDUAQIDBAUGBwpYJHZlcnNpb25ZJGFyY2hpdmVyVCR0b3BYJG9iamVjdHMSAAGGoF8Q
D05TS2V5ZWRBcmNoaXZlctEICVRyb290gAGjCwwTVSRudWxs0w0ODxAREldLZXlDb2RlViRjbGFz
c11Nb2RpZmllckZsYWdzEB+AAhIAFAAA0hQVFhdaJGNsYXNzbmFtZVgkY2xhc3Nlc1tNQVNTaG9y
dGN1dKIYGVtNQVNTaG9ydGN1dFhOU09iamVjdAgRGiQpMjdJTFFTV11kbHOBg4WKj5qjr7K+AAAA
AAAAAQEAAAAAAAAAGgAAAAAAAAAAAAAAAAAAAMc=
</data>"

lk_console_message "Checking Typora"
pgrep -xq "Typora" &&
    lk_warn "cannot apply settings while Typora is running" || {
    lk_symlink "$SCRIPT_DIR/typora/abnerworks.Typora.plist" \
        "$HOME/Library/Preferences/abnerworks.Typora.plist" &&
        lk_symlink "$SCRIPT_DIR/typora/themes" \
            ~/"Library/Application Support/abnerworks.Typora/themes"
}

lk_console_message "Checking Visual Studio Code"
pgrep -fq "^/Applications/VSCodium.app/Contents/MacOS/Electron" &&
    lk_warn "cannot apply settings while Visual Studio Code is running" || {
    FILE=/Applications/VSCodium.app/Contents/Resources/app/product.json
    [ ! -f "$FILE" ] || {
        VSCODE_PRODUCT_JSON="$(
            jq '.extensionsGallery = {
    "serviceUrl": "https://marketplace.visualstudio.com/_apis/public/gallery",
    "itemUrl": "https://marketplace.visualstudio.com/items"
}' <"$FILE"
        )"
        diff -q <(jq <"$FILE") <(echo "$VSCODE_PRODUCT_JSON") >/dev/null || {
            lk_console_detail "Configuring VSCodium to use Marketplace"
            echo -n "$VSCODE_PRODUCT_JSON" | sudo tee "$FILE" >/dev/null
        }
    }
    lk_symlink "$SCRIPT_DIR/vscode/settings.json" \
        ~/"Library/Application Support/VSCodium/User/settings.json" &&
        lk_symlink "$SCRIPT_DIR/vscode/keybindings.mac.json" \
            ~/"Library/Application Support/VSCodium/User/keybindings.json" &&
        lk_symlink "$SCRIPT_DIR/vscode/snippets" \
            ~/"Library/Application Support/VSCodium/User/snippets"
}

lk_macos_maybe_install_pkg_url \
    "com.Brother.Brotherdriver.Brother_PrinterDrivers_MonochromeLaser" \
    "https://download.brother.com/welcome/dlf104416/Brother_PrinterDrivers_MonochromeLaser_1_3_0.dmg" \
    "Brother Printer Drivers (Monochrome Laser)"

lk_macos_maybe_install_pkg_url \
    "com.brother.brotherdriver.BrotherCL17" \
    "https://download.brother.com/welcome/dlf104984/Brother_PrinterDrivers_CL17_2_1_6_0.dmg" \
    "Brother Printer Drivers (Color Laser)"

# use `lpinfo -m` for driver names
lk_console_message "Checking printers"
sudo lpadmin -p HL5450DN -E \
    -D "Brother HL-5450DN" \
    -L "black and white" \
    -m "Library/Printers/PPDs/Contents/Resources/Brother HL-5450DN series CUPS.gz" \
    -v "socket://10.10.10.10" \
    -o PageSize=A4 \
    -o Duplex=DuplexNoTumble \
    -o printer-error-policy=abort-job

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

lk_console_message "Checking macOS"

if ! nvram StartupMute 2>/dev/null | grep -E "$S%01\$" >/dev/null; then
    lk_console_detail "Disabling startup sound"
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
defaults write NSGlobalDomain com.apple.keyboard.fnState -bool true

defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false
defaults write NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false

# Sound
defaults write NSGlobalDomain com.apple.sound.beep.feedback -bool true

# General
defaults write NSGlobalDomain AppleAccentColor -int 0
defaults write NSGlobalDomain AppleHighlightColor -string "1.000000 0.733333 0.721569 Red"
defaults write NSGlobalDomain AppleShowScrollBars -string Always
defaults write NSGlobalDomain NSDocumentSaveNewDocumentsToCloud -bool false
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool true
defaults write NSGlobalDomain NSTableViewDefaultSizeMode -int 1
defaults write NSGlobalDomain PMPrintingExpandedStateForPrint -bool true
defaults write NSGlobalDomain PMPrintingExpandedStateForPrint2 -bool true

defaults write NSGlobalDomain NSCloseAlwaysConfirmsChanges -bool true
defaults write NSGlobalDomain NSDisableAutomaticTermination -bool true
defaults write com.apple.systempreferences NSQuitAlwaysKeepsWindows -bool false

defaults write NSGlobalDomain NSAutomaticWindowAnimationsEnabled -bool false
defaults write NSGlobalDomain NSWindowResizeTime -float 0.001
defaults write NSGlobalDomain QLPanelAnimationDuration -float 0

defaults write com.apple.menuextra.clock DateFormat -string "EEE d MMM  h:mm:ss a"
defaults write com.apple.screencapture location -string "${LK_SCREENSHOT_DIR:-$HOME/Desktop}"
defaults -currentHost write com.apple.ImageCapture disableHotPlug -bool true

# Screen Saver
defaults -currentHost write com.apple.screensaver idleTime -int 300
defaults -currentHost write com.apple.screensaver showClock -bool true

# Hot Corners (5 = Start Screen Saver)
defaults write com.apple.dock wvous-tr-corner -int 5
defaults write com.apple.dock wvous-tr-modifier -int 0

# Dock
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock autohide-delay -float 0
defaults write com.apple.dock launchanim -bool false
defaults write com.apple.dock magnification -bool false
defaults write com.apple.dock mineffect -string scale
defaults write com.apple.dock minimize-to-application -bool true
defaults write com.apple.dock show-process-indicators -bool true
defaults write com.apple.dock show-recents -bool false
defaults write com.apple.dock size-immutable -bool true
defaults write com.apple.dock tilesize -int 60

# Finder
defaults write com.apple.finder FXDefaultSearchScope -string SCcf
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false
defaults write com.apple.finder FXPreferredViewStyle -string clmv
defaults write com.apple.finder _FXSortFoldersFirst -bool true
defaults write com.apple.finder NewWindowTarget -string PfHm
defaults write com.apple.finder NewWindowTargetPath -string "file://$HOME/"
defaults write com.apple.finder ShowPathbar -bool true
defaults write com.apple.finder ShowRecentTags -bool false
defaults write com.apple.finder ShowStatusBar -bool true
defaults write com.apple.finder WarnOnEmptyTrash -bool false
defaults write com.apple.finder DisableAllAnimations -bool true

defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true

# Safari
defaults write com.apple.Safari AlwaysRestoreSessionAtLaunch -bool true
defaults write com.apple.Safari AutoOpenSafeDownloads -bool false
defaults write com.apple.Safari DownloadsClearingPolicy -int 0
defaults write com.apple.Safari HistoryAgeInDaysLimit -int 365000
defaults write com.apple.Safari NewTabBehavior -int 1
defaults write com.apple.Safari NewWindowBehavior -int 1
defaults write com.apple.Safari SendDoNotTrackHTTPHeader -bool true
defaults write com.apple.Safari ShowFullURLInSmartSearchField -bool true
defaults write com.apple.Safari ShowIconsInTabs -bool true
defaults write com.apple.Safari SuppressSearchSuggestions -bool true

defaults write com.apple.Safari IncludeDevelopMenu -bool true
defaults write com.apple.Safari WebKitDeveloperExtrasEnabledPreferenceKey -bool true
defaults write com.apple.Safari WebKitPreferences.developerExtrasEnabled -bool true

# Mail
defaults write com.apple.mail ConversationViewSpansMailboxes -bool false
defaults write com.apple.mail DeleteAttachmentsAfterHours -int 0
defaults write com.apple.mail NewMessagesSoundName -string ""
defaults write com.apple.mail PlayMailSounds -bool false
defaults write com.apple.mail ShouldShowUnreadMessagesInBold -bool true
defaults write com.apple.mail ThreadingDefault -bool false

# "Use classic layout" (<=10.14)
defaults write com.apple.mail RichMessageList -bool false

# "View" > "Use Column Layout" (>=10.15)
defaults write com.apple.mail ColumnLayoutMessageList -int 1

if lk_has_arg "--reset"; then
    lk_macos_kb_reset_shortcuts NSGlobalDomain
    lk_macos_kb_reset_shortcuts com.apple.mail
fi

lk_macos_kb_add_shortcut NSGlobalDomain "Lock Screen" "@^l"
lk_macos_kb_add_shortcut com.apple.mail "Mark All Messages as Read" "@\$c"
lk_macos_kb_add_shortcut com.apple.mail "Send" "@\U21a9"

killall -u "$USER" cfprefsd
killall Dock
killall Finder

! lk_command_exists code || {
    lk_console_message "Checking Visual Studio Code extensions"
    . "$SCRIPT_DIR/vscode/extensions.sh" || exit
    VSCODE_MISSING_EXTENSIONS=($(
        comm -13 \
            <(code --list-extensions | sort -u) \
            <(lk_echo_array VSCODE_EXTENSIONS | sort -u)
    ))
    [ "${#VSCODE_MISSING_EXTENSIONS[@]}" -eq "0" ] ||
        for EXT in "${VSCODE_MISSING_EXTENSIONS[@]}"; do
            code --install-extension "$EXT"
        done
    VSCODE_EXTRA_EXTENSIONS=($(
        comm -23 \
            <(code --list-extensions | sort -u) \
            <(lk_echo_array VSCODE_EXTENSIONS | sort -u)
    ))
    [ "${#VSCODE_EXTRA_EXTENSIONS[@]}" -eq "0" ] || {
        echo
        lk_echo_array VSCODE_EXTRA_EXTENSIONS |
            lk_console_detail_list \
                "Remove or add to $SCRIPT_DIR/vscode/extensions.sh:" \
                extension extensions
        lk_console_detail "To remove, run" "code --uninstall-extension <ext-id>"
    }
}
