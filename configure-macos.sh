#!/bin/bash
# shellcheck disable=SC1090,SC2015,SC2034,SC2207

set -euo pipefail
lk_die() { echo "${BS:+$BS: }$1" >&2 && exit 1; }
BS="${BASH_SOURCE[0]}" && [ ! -L "$BS" ] &&
    SCRIPT_DIR="$(cd "$(dirname "$BS")" && pwd -P)" ||
    lk_die "unable to resolve path to script"

[ -d "${LK_BASE:-}" ] || lk_die "LK_BASE not set"

include=macos . "$LK_BASE/lib/bash/common.sh"

lk_assert_not_root
lk_assert_is_macos

set +e
shopt -s nullglob

function PlistBuddy() {
    /usr/libexec/PlistBuddy "$@"
}

function plist_quote() {
    echo "\"${1//\"/\\\"}\""
}

function plist_delete() {
    PlistBuddy -c \
        "Delete $(plist_quote "$1")" "$PLIST" 2>/dev/null
}

function plist_add() {
    PlistBuddy -c \
        "Add $(plist_quote "$1") $2${3+ $(plist_quote "$3")}" "$PLIST"
}

function plist_replace() {
    plist_delete "$1"
    plist_add "$@"
}

function plist_replace_from_file() {
    plist_replace "${@:1:2}"
    PlistBuddy -c \
        "Merge $(plist_quote "$3") $(plist_quote "$1")" "$PLIST"
}

function plist_exists() {
    PlistBuddy -c \
        "Print $(plist_quote "$1")" "$PLIST" >/dev/null 2>&1
}

function plist_maybe_add() {
    plist_exists "$1" ||
        plist_add "$@"
}

CLOUD_SETTINGS="$HOME/.cloud-settings"

[ ! -d "$CLOUD_SETTINGS" ] || {

    lk_safe_symlink "$CLOUD_SETTINGS/.bashrc" "$HOME/.bashrc"
    lk_safe_symlink "$CLOUD_SETTINGS/.gitconfig" "$HOME/.gitconfig"
    lk_safe_symlink "$CLOUD_SETTINGS/.gitignore" "$HOME/.gitignore"
    lk_safe_symlink "$CLOUD_SETTINGS/acme.sh/" "$HOME/.acme.sh"
    lk_safe_symlink "$CLOUD_SETTINGS/aws/" "$HOME/.aws"
    lk_safe_symlink "$CLOUD_SETTINGS/espanso/" "$HOME/Library/Preferences/espanso"
    lk_safe_symlink "$CLOUD_SETTINGS/linode-cli/linode-cli" \
        "$HOME/.config/linode-cli"
    lk_safe_symlink "$CLOUD_SETTINGS/ssh/" "$HOME/.ssh"
    lk_safe_symlink "$CLOUD_SETTINGS/unison/" "$HOME/Library/Application Support/unison"

    pgrep -xq "dbeaver" &&
        lk_warn "cannot apply settings while DBeaver is running" || {
        lk_safe_symlink "$CLOUD_SETTINGS/DBeaverData/workspace6/General/" \
            "$HOME/Library/DBeaverData/workspace6/General"
        lk_safe_symlink "$CLOUD_SETTINGS/DBeaverData/.settings/" \
            "$HOME/Library/DBeaverData/workspace6/.metadata/.plugins/org.eclipse.core.runtime/.settings"
    }

    for FILE in "$CLOUD_SETTINGS"/.*-settings; do
        lk_safe_symlink "$FILE" "$HOME/$(basename "$FILE")"
    done

}

[ -d "/opt/db2_db2driver_for_jdbc_sqlj" ] || {
    DB2_DRIVER=("$HOME/Downloads"/*/Db2/db2_db2driver_for_jdbc_sqlj.zip)
    [ "${#DB2_DRIVER[@]}" -ne "1" ] || {
        pushd /tmp >/dev/null && {
            rm -Rf "/tmp/db2_db2driver_for_jdbc_sqlj" &&
                unzip "${DB2_DRIVER[0]}" &&
                sudo mv "/tmp/db2_db2driver_for_jdbc_sqlj" /opt/
            popd >/dev/null
        }
    }
}

[ ! -d "/Applications/Firefox.app/Contents/Resources" ] || {
    sudo mkdir -p "/Applications/Firefox.app/Contents/Resources/defaults/pref"
    printf '%s\n' \
        '// the first line is ignored' \
        'pref("general.config.filename", "firefox.cfg");' \
        'pref("general.config.obscure_value", 0);' |
        sudo tee "/Applications/Firefox.app/Contents/Resources/defaults/pref/autoconfig.js" >/dev/null
    printf '%s\n' \
        '// the first line is ignored' \
        'defaultPref("services.sync.prefs.dangerously_allow_arbitrary", true);' |
        sudo tee "/Applications/Firefox.app/Contents/Resources/firefox.cfg" >/dev/null
}

lk_safe_symlink "$SCRIPT_DIR/.vimrc" \
    "$HOME/.vimrc"

lk_safe_symlink "$SCRIPT_DIR/.tidyrc" \
    "$HOME/.tidyrc"

lk_safe_symlink "$SCRIPT_DIR/byobu/" \
    "$HOME/.byobu"

lk_safe_symlink "$SCRIPT_DIR/nextcloud/sync-exclude.lst" \
    "$HOME/Library/Preferences/Nextcloud/sync-exclude.lst" && {
    [ -e "$HOME/Library/Preferences/Nextcloud/nextcloud.cfg" ] ||
        cp -v "$SCRIPT_DIR/nextcloud/nextcloud.cfg" \
            "$HOME/Library/Preferences/Nextcloud/nextcloud.cfg"
}

lk_console_message "Checking Sublime Text 3"
pgrep -xq "Sublime Text" &&
    lk_warn "cannot apply settings while Sublime Text 3 is running" ||
    lk_safe_symlink "$SCRIPT_DIR/subl/User/" \
        "$HOME/Library/Application Support/Sublime Text 3/Packages/User"

lk_console_message "Checking Sublime Merge"
pgrep -xq "sublime_merge" &&
    lk_warn "cannot apply settings while Sublime Merge is running" ||
    lk_safe_symlink "$SCRIPT_DIR/smerge/User/" \
        "$HOME/Library/Application Support/Sublime Merge/Packages/User"

lk_console_message "Checking HandBrake"
pgrep -xq "HandBrake" &&
    lk_warn "cannot apply settings while HandBrake is running" || {
    FILE="\
$HOME/Library/Containers/fr.handbrake.HandBrake/Data\
/Library/Application Support/HandBrake/UserPresets.json"
    diff -Nq "$SCRIPT_DIR/handbrake/presets.json" "$FILE" >/dev/null || {
        LK_BACKUP_SUFFIX="-$(lk_timestamp).bak" lk_keep_original "$FILE" &&
            mkdir -pv "$(dirname "$FILE")" &&
            cp -fv "$SCRIPT_DIR/handbrake/presets.json" "$FILE"
    }
}

lk_console_message "Checking iTerm2"
pgrep -xq iTerm2 &&
    lk_warn "cannot apply settings while iTerm2 is running" || {
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

    PLIST=~/Library/Preferences/com.googlecode.iterm2.plist
    plist_maybe_add ":Window Arrangements" dict
    plist_replace ":Window Arrangements:No windows" array
    plist_replace ":Default Arrangement Name" string "No windows"
    plist_replace ":OpenArrangementAtStartup" bool true
    plist_replace ":OpenNoWindowsAtStartup" bool false

    plist_replace_from_file ":Custom Color Presets" dict \
        "$SCRIPT_DIR/iterm2/Custom Color Presets.plist"

    ! plist_exists ":New Bookmarks:0" &&
        lk_warn "no profile to configure" || {
        plist_replace ":New Bookmarks:0:AWDS Pane Option" string "Recycle"
        plist_replace ":New Bookmarks:0:AWDS Tab Option" string "Recycle"
        plist_replace ":New Bookmarks:0:AWDS Window Option" string "Recycle"
        plist_replace ":New Bookmarks:0:BM Growl" bool false
        plist_replace ":New Bookmarks:0:Columns" integer 120
        plist_replace ":New Bookmarks:0:Custom Directory" string "Advanced"
        plist_replace ":New Bookmarks:0:Flashing Bell" bool true
        plist_replace ":New Bookmarks:0:Normal Font" string "Menlo-Regular 12"
        plist_replace ":New Bookmarks:0:Option Key Sends" integer 2
        plist_replace ":New Bookmarks:0:Place Prompt at First Column" bool false
        plist_replace ":New Bookmarks:0:Right Option Key Sends" integer 2
        plist_replace ":New Bookmarks:0:Rows" integer 35
        plist_replace ":New Bookmarks:0:Screen" integer -2
        plist_replace ":New Bookmarks:0:Scrollback Lines" integer 0
        plist_replace ":New Bookmarks:0:Show Mark Indicators" bool false
        plist_replace ":New Bookmarks:0:Silence Bell" bool true
        plist_replace ":New Bookmarks:0:Title Components" integer 512
        plist_replace ":New Bookmarks:0:Unlimited Scrollback" bool true
        plist_replace_from_file ":New Bookmarks:0:Keyboard Map" dict \
            "$SCRIPT_DIR/iterm2/Keyboard Map.plist"
    }
}

lk_console_message "Checking KeePassXC"
pgrep -xq "KeePassXC" &&
    lk_warn "cannot apply settings while KeePassXC is running" ||
    lk_safe_symlink "$SCRIPT_DIR/keepassxc/keepassxc.ini" \
        "$HOME/Library/Application Support/keepassxc/keepassxc.ini"

lk_console_message "Checking Stretchly"
pgrep -xq "stretchly" &&
    lk_warn "cannot apply settings while Stretchly is running" ||
    lk_safe_symlink "$SCRIPT_DIR/stretchly/config.json" \
        "$HOME/Library/Application Support/stretchly/config.json"

lk_console_message "Checking Typora"
pgrep -xq "Typora" &&
    lk_warn "cannot apply settings while Typora is running" || {
    lk_safe_symlink "$SCRIPT_DIR/typora/abnerworks.Typora.plist" \
        "$HOME/Library/Preferences/abnerworks.Typora.plist" &&
        lk_safe_symlink "$SCRIPT_DIR/typora/themes" \
            "$HOME/Library/Application Support/abnerworks.Typora/themes"
}

lk_console_message "Checking Visual Studio Code"
pgrep -fq "^/Applications/VSCodium.app/Contents/MacOS/Electron" &&
    lk_warn "cannot apply settings while Visual Studio Code is running" || {
    FILE="/Applications/VSCodium.app/Contents/Resources/app/product.json"
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
    lk_safe_symlink "$SCRIPT_DIR/vscode/settings.json" \
        "$HOME/Library/Application Support/VSCodium/User/settings.json" &&
        lk_safe_symlink "$SCRIPT_DIR/vscode/keybindings.mac.json" \
            "$HOME/Library/Application Support/VSCodium/User/keybindings.json" &&
        lk_safe_symlink "$SCRIPT_DIR/vscode/snippets" \
            "$HOME/Library/Application Support/VSCodium/User/snippets"
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
            <(code --list-extensions | sort | uniq) \
            <(lk_echo_array VSCODE_EXTENSIONS | sort | uniq)
    ))
    [ "${#VSCODE_MISSING_EXTENSIONS[@]}" -eq "0" ] ||
        for EXT in "${VSCODE_MISSING_EXTENSIONS[@]}"; do
            code --install-extension "$EXT"
        done
    VSCODE_EXTRA_EXTENSIONS=($(
        comm -23 \
            <(code --list-extensions | sort | uniq) \
            <(lk_echo_array VSCODE_EXTENSIONS | sort | uniq)
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
