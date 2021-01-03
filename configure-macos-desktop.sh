#!/bin/bash

# shellcheck disable=SC1090,SC2015,SC2034

set -euo pipefail
lk_die() { echo "${BS:+$BS: }$1" >&2 && exit 1; }
BS=${BASH_SOURCE[0]} &&
    [ ! -L "$BS" ] && SCRIPT_DIR=$(cd "${BS%/*}" && pwd -P) ||
    lk_die "unable to resolve path to script"

[ -d "${LK_BASE:-}" ] || lk_die "LK_BASE not set"

include=macos . "$LK_BASE/lib/bash/common.sh"

lk_assert_not_root
lk_assert_is_macos

LK_VERBOSE=1

set +e
shopt -s nullglob

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
#defaults write NSGlobalDomain com.apple.keyboard.fnState -bool true

defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false
defaults write NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled -bool false
#defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false

# Sound
defaults write NSGlobalDomain com.apple.sound.beep.feedback -bool true

# General
defaults write NSGlobalDomain AppleAccentColor -int 0
defaults write NSGlobalDomain AppleHighlightColor -string "1.000000 0.733333 0.721569 Red"
defaults write NSGlobalDomain AppleShowScrollBars -string Always
defaults write NSGlobalDomain NSDocumentSaveNewDocumentsToCloud -bool false
#defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
#defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool true
#defaults write NSGlobalDomain NSTableViewDefaultSizeMode -int 1
#defaults write NSGlobalDomain PMPrintingExpandedStateForPrint -bool true
#defaults write NSGlobalDomain PMPrintingExpandedStateForPrint2 -bool true

defaults write NSGlobalDomain NSCloseAlwaysConfirmsChanges -bool true
defaults write NSGlobalDomain NSDisableAutomaticTermination -bool true
defaults write com.apple.systempreferences NSQuitAlwaysKeepsWindows -bool false

#defaults write NSGlobalDomain NSAutomaticWindowAnimationsEnabled -bool false
#defaults write NSGlobalDomain NSWindowResizeTime -float 0.001
#defaults write NSGlobalDomain QLPanelAnimationDuration -float 0

#defaults write com.apple.menuextra.clock DateFormat -string "EEE d MMM  h:mm:ss a"
#defaults write com.apple.screencapture location -string "${LK_SCREENSHOT_DIR:-$HOME/Desktop}"
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
#defaults write com.apple.dock size-immutable -bool true
#defaults write com.apple.dock tilesize -int 60

# Finder
defaults write com.apple.finder FXDefaultSearchScope -string SCcf
#defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false
defaults write com.apple.finder FXPreferredViewStyle -string clmv
defaults write com.apple.finder _FXSortFoldersFirst -bool true
defaults write com.apple.finder NewWindowTarget -string PfHm
defaults write com.apple.finder NewWindowTargetPath -string "file://$HOME/"
#defaults write com.apple.finder ShowPathbar -bool true
defaults write com.apple.finder ShowRecentTags -bool false
#defaults write com.apple.finder ShowStatusBar -bool true
#defaults write com.apple.finder WarnOnEmptyTrash -bool false
#defaults write com.apple.finder DisableAllAnimations -bool true

defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true

# Safari
#defaults write com.apple.Safari AlwaysRestoreSessionAtLaunch -bool true
defaults write com.apple.Safari AutoOpenSafeDownloads -bool false
defaults write com.apple.Safari DownloadsClearingPolicy -int 0
defaults write com.apple.Safari HistoryAgeInDaysLimit -int 365000
defaults write com.apple.Safari NewTabBehavior -int 1
defaults write com.apple.Safari NewWindowBehavior -int 1
defaults write com.apple.Safari SendDoNotTrackHTTPHeader -bool true
defaults write com.apple.Safari ShowFullURLInSmartSearchField -bool true
defaults write com.apple.Safari ShowIconsInTabs -bool true
#defaults write com.apple.Safari SuppressSearchSuggestions -bool true

#defaults write com.apple.Safari IncludeDevelopMenu -bool true
#defaults write com.apple.Safari WebKitDeveloperExtrasEnabledPreferenceKey -bool true
#defaults write com.apple.Safari WebKitPreferences.developerExtrasEnabled -bool true

# Mail
defaults write com.apple.mail ConversationViewSpansMailboxes -bool false
defaults write com.apple.mail DeleteAttachmentsAfterHours -int 0
defaults write com.apple.mail NewMessagesSoundName -string ""
defaults write com.apple.mail PlayMailSounds -bool false
defaults write com.apple.mail ShouldShowUnreadMessagesInBold -bool true
#defaults write com.apple.mail ThreadingDefault -bool false

# "Use classic layout" (<=10.14)
defaults write com.apple.mail RichMessageList -bool false

# "View" > "Use Column Layout" (>=10.15)
defaults write com.apple.mail ColumnLayoutMessageList -int 1

#if lk_has_arg "--reset"; then
#    lk_macos_kb_reset_shortcuts NSGlobalDomain
#    lk_macos_kb_reset_shortcuts com.apple.mail
#fi

#lk_macos_kb_add_shortcut NSGlobalDomain "Lock Screen" "@^l"
#lk_macos_kb_add_shortcut com.apple.mail "Mark All Messages as Read" "@\$c"
#lk_macos_kb_add_shortcut com.apple.mail "Send" "@\U21a9"

killall -u "$USER" cfprefsd
killall Dock
killall Finder
