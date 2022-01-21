#!/bin/bash

[ $# -gt 0 ] || set -- \
    "/Applications/iTerm.app" \
    "/Applications/Firefox.app" \
    "/System/Applications/Mail.app" \
    "/System/Applications/Calendar.app" \
    "/System/Applications/Notes.app" \
    "/Applications/Todoist.app" \
    "/System/Applications/Messages.app" \
    "/Applications/Microsoft Teams.app" \
    "/Applications/Skype.app" \
    "/Applications/Messenger.app" \
    "/Applications/Visual Studio Code.app" \
    "/Applications/Dash.app" \
    "/Applications/DBeaver.app" \
    "/Applications/Sublime Merge.app" \
    "/Applications/KeePassXC.app"

defaults write com.apple.dock persistent-apps -array
for APP in "$@"; do
    [ ! -e "$APP" ] ||
        defaults write com.apple.dock persistent-apps -array-add "\
<dict>
  <key>GUID</key>
  <string>$(uuidgen)</string>
  <key>tile-data</key>
  <dict>
    <key>file-data</key>
    <dict>
      <key>_CFURLString</key>
      <string>$APP</string>
      <key>_CFURLStringType</key>
      <integer>0</integer>
    </dict>
  </dict>
  <key>tile-type</key>
  <string>file-tile</string>
</dict>"
done

defaults write com.apple.dock persistent-others -array "\
<dict>
  <key>GUID</key>
  <string>$(uuidgen)</string>
  <key>tile-data</key>
  <dict>
    <key>arrangement</key>
    <integer>1</integer>
    <key>displayas</key>
    <integer>1</integer>
    <key>file-data</key>
    <dict>
      <key>_CFURLString</key>
      <string>/Applications/</string>
      <key>_CFURLStringType</key>
      <integer>0</integer>
    </dict>
    <key>file-label</key>
    <string>Applications</string>
    <key>file-type</key>
    <integer>2</integer>
    <key>showas</key>
    <integer>2</integer>
  </dict>
  <key>tile-type</key>
  <string>directory-tile</string>
</dict>"

killall Dock
