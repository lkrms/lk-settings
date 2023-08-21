#!/bin/bash

lk_die() { echo "${BS:+$BS: }$1" >&2 && exit 1; }
BS=${BASH_SOURCE[0]} &&
    [ ! -L "$BS" ] && _ROOT=$(cd "${BS%/*}/../desktop" && pwd -P) ||
    lk_die "unable to resolve path to script"

. "$_ROOT/../bin/settings-common.sh"
lk_require linux provision

lk_assert_not_root
lk_assert_is_linux

DEFAULT_FONT="Source Sans Pro"
DEFAULT_MONOSPACE_FONT="JetBrains Mono NL"

while [ $# -gt 0 ] && [[ $1 == -* ]]; do
    shift
done

cleanup

rm -Rfv ~/.config/composer-dev

for FILE in "$_ROOT/bin"/*; do
    [[ -x $FILE ]] || continue
    symlink "$FILE" ~/.local/bin/"${FILE##*/}"
done

unset LK_FILE_REPLACE_NO_CHANGE
APPS=(org.flameshot.Flameshot.desktop)
for FILE in "${APPS[@]}"; do
    FILE=/usr/share/applications/$FILE
    [[ -e $FILE ]] || continue
    lk_file_replace ~/.local/share/applications/${FILE##*/} < <(
        sed -E 's/\/usr\/bin\/([^/]+)\b/\1/g' "$FILE"
    )
done

UPDATE_DESKTOP_DATABASE=0
! lk_false LK_FILE_REPLACE_NO_CHANGE ||
    UPDATE_DESKTOP_DATABASE=1

_PRIV=${1-}

[ ! -d "$_PRIV" ] || {

    _PRIV=$(realpath "$_PRIV")

    symlink_private_common "$_PRIV"
    symlink \
        "$_PRIV/.face" ~/.face \
        "$_PRIV/composer/auth.json" ~/.config/composer/auth.json \
        "$_PRIV/composer/composer.json" ~/.config/composer/composer.json \
        "$_PRIV/composer/composer.lock" ~/.config/composer/composer.lock \
        "$_PRIV/composer/config.json" ~/.config/composer/config.json \
        "$_PRIV/espanso/" ~/.config/espanso \
        "$_PRIV/offlineimap/.offlineimaprc" ~/.offlineimaprc \
        "$_PRIV/remmina/data/" ~/.local/share/remmina \
        "$_PRIV/robo3t/3T/" ~/.config/3T

    [[ -d ~/.cache/hexchat/logs ]] || install -vd ~/.cache/hexchat/logs
    [[ -d ~/.cache/hexchat/scrollback ]] || install -vd ~/.cache/hexchat/scrollback
    symlink_if_not_running \
        ~/.cache/hexchat/logs "$_PRIV/hexchat/logs" \
        ~/.cache/hexchat/scrollback "$_PRIV/hexchat/scrollback" \
        "$_PRIV/hexchat/" ~/.config/hexchat \
        HexChat "pgrep -x hexchat"

    symlink_if_not_running \
        "$_PRIV/DBeaverData/" ~/.local/share/DBeaverData \
        DBeaver "pgrep -x dbeaver"

    [ ! -e "$_PRIV/.face" ] ||
        lk_dir_parents -u ~ "$_PRIV/.face" |
        xargs -r chmod -c a+x

    for FILE in "$_PRIV/applications"/*.png; do
        lk_icon_install "$FILE"
    done

    for FILE in "$_PRIV/autostart"/*.desktop; do
        lk_symlink "$FILE" ~/.config/autostart/"${FILE##*/}" || true
    done

    unset LK_SYMLINK_NO_CHANGE
    for FILE in "$_PRIV/applications"/*.desktop; do
        _FILE=${FILE##*/}
        case "${_FILE%.desktop}" in
        caprine | skypeforlinux | teams | thunderbird)
            continue
            ;;
        *)
            lk_symlink "$FILE" ~/.local/share/applications/"${FILE##*/}"
            ;;
        esac
    done
    ! lk_false LK_SYMLINK_NO_CHANGE ||
        UPDATE_DESKTOP_DATABASE=1

}

((!UPDATE_DESKTOP_DATABASE)) ||
    lk_tty_run_detail update-desktop-database ~/.local/share/applications

LK_SUDO=1

FILE=~lightdm/.config/autorandr
sudo test -d "$FILE" || {
    sudo -u lightdm install -d -m 00700 "${FILE%/*}" &&
        sudo -u lightdm ln -sfTv "$_ROOT/autorandr/" "$FILE"
}
if ! lk_is_portable; then
    FILE=/etc/modules-load.d/i2c_dev.conf
    lk_install -m 00644 "$FILE"
    lk_file_replace "$FILE" <<EOF
i2c_dev
EOF
    FILE=/etc/sudoers.d/lightdm-ddcutil
    lk_install -m 00440 "$FILE"
    lk_file_replace "$FILE" <<EOF
lightdm ALL=(ALL) NOPASSWD:/usr/bin/ddcutil
EOF
    if [ "$(grep -Ec '^(iwlwifi|iwlmvm) ' /proc/modules)" -eq 2 ]; then
        FILE=/etc/modprobe.d/iwlwifi.conf
        lk_install -m 00644 "$FILE"
        lk_file_replace "$FILE" <<EOF
options iwlwifi 11n_disable=8
options iwlmvm power_scheme=1
EOF
    fi
else
    if lk_command_exists synclient; then
        FILE=/etc/X11/xorg.conf.d/99-synaptics.conf
        lk_install -m 00644 "$FILE"
        lk_file_replace -f "$_ROOT/X11/xorg.conf.d/synaptics.conf" "$FILE"
    fi
fi

symlink "$_ROOT/autorandr/postadd" /etc/xdg/autorandr/postadd
symlink "$_ROOT/autorandr/postremove" /etc/xdg/autorandr/postremove
symlink "$_ROOT/iptables/iptables.rules" /etc/iptables/iptables.rules
symlink "$_ROOT/iptables/ip6tables.rules" /etc/iptables/ip6tables.rules
symlink "$_ROOT/libvirt/hooks/qemu" /etc/libvirt/hooks/qemu

unset LK_SYMLINK_NO_CHANGE LK_FILE_REPLACE_NO_CHANGE
# Fix weird Calibri rendering in Thunderbird
symlink \
    "$_ROOT/fonts/ms-no-bitmaps.conf" /etc/fonts/conf.d/99-ms-no-bitmaps.conf
# Fix weird Nimbus Mono PS ligatures
symlink \
    "$_ROOT/fonts/no-nimbus-mono-ps.conf" /etc/fonts/conf.d/99-no-nimbus-mono-ps.conf
# Remove emoji from all fonts other than Twemoji
symlink \
    "$_ROOT/fonts/emoji-fix.conf" /etc/fonts/conf.d/99-emoji-fix.conf

unset LK_SUDO

mkdir -p ~/.config/fontconfig/conf.d
lk_file_replace -f "$_ROOT/fonts/fonts.conf" ~/.config/fontconfig/fonts.conf
lk_file_replace ~/.config/fontconfig/conf.d/99-default-fonts.conf < <(
    lk_expand_template "$_ROOT/fonts/default-fonts.conf.template"
)

! lk_false LK_SYMLINK_NO_CHANGE &&
    ! lk_false LK_FILE_REPLACE_NO_CHANGE ||
    { sudo -H fc-cache --really-force --verbose &&
        fc-cache --really-force --verbose; }

if lk_command_exists crontab; then
    CRONTAB=$(awk \
        -v STRETCHLY="$(lk_double_quote "$_ROOT/stretchly/stretchly.sh")" \
        '$6=="stretchly"{$6=STRETCHLY}{print}' \
        "$_ROOT/cron/crontab")
    diff <(crontab -l) <(echo "${CRONTAB%$'\n'}") >/dev/null || {
        lk_tty_print "Updating crontab"
        crontab <(echo "${CRONTAB%$'\n'}")
    }
    FILE=~/.config/autostart/net.hovancik.stretchly.align.desktop
    lk_file_replace "$FILE" <<EOF
[Desktop Entry]
Type=Application
Name=Stretchly startup
Icon=stretchly
Exec=lk-run-after.sh 60 $(lk_double_quote "$_ROOT/stretchly/stretchly.sh")
StartupNotify=false
Terminal=false
EOF
    lk_symlink "$FILE" ~/.local/share/applications/"${FILE##*/}"
fi

MIMEINFO_FILE=/usr/share/applications/mimeinfo.cache
MIMEAPPS_FILE=~/.config/mimeapps.list
[ ! -f "$MIMEINFO_FILE" ] || {
    REPLACE=(geany vim)
    REPLACE_WITH=(VSCodium VSCodium)
    PREFER=(
        codium

        # Prefer Firefox over vscode for text/html
        firefox

        # Prefer Thunar for inode/directory
        thunar

        #
        org.nomacs.ImageLounge
        org.xfce.ristretto

        #
        typora

        # Prefer Evince and VLC for everything they can open
        org.gnome.Evince
        vlc
    )
    SED_COMMAND=(sed -E)
    for i in "${!REPLACE[@]}"; do
        [ -f "/usr/share/applications/${REPLACE_WITH[$i]}.desktop" ] || continue
        SED_COMMAND+=(
            -e "s/\
([=;])(${REPLACE[$i]}.desktop(;|$))/\
\1${REPLACE_WITH[$i]}.desktop;\2/"
            -e "s/\
=((.+;)*)(${REPLACE_WITH[$i]}.desktop;((.+;)*))${REPLACE_WITH[$i]}.desktop;?((.+;)*)$/\
=\1\3\6/"
        )
    done
    for APP in "${PREFER[@]}"; do
        [ -f "/usr/share/applications/$APP.desktop" ] || continue
        SED_COMMAND+=(-e "s/=((.+;)*)($APP.desktop;?)((.+;)*)$/=\3\1\4/")
    done
    [ ${#SED_COMMAND[@]} -gt 2 ] &&
        lk_install -d -m 00755 "${MIMEAPPS_FILE%/*}" &&
        lk_install -m 00644 "$MIMEAPPS_FILE" && {
        echo "[Default Applications]"
        comm -23 \
            <(grep -E '.+=.+' "$MIMEINFO_FILE" | "${SED_COMMAND[@]}" | sort) \
            <(sort "$MIMEINFO_FILE")
    } >"$MIMEAPPS_FILE"
}

[ -d /opt/db2_db2driver_for_jdbc_sqlj ] || {
    DB2_DRIVER=(~/Downloads/*/Db2/db2_db2driver_for_jdbc_sqlj.zip)
    [ ${#DB2_DRIVER[@]} -ne 1 ] || (umask 0022 &&
        cd /tmp &&
        rm -Rf "/tmp/db2_db2driver_for_jdbc_sqlj" &&
        unzip "${DB2_DRIVER[0]}" &&
        sudo mv "/tmp/db2_db2driver_for_jdbc_sqlj" /opt/)
}

DIR=/usr/lib/firefox
[ ! -d "$DIR" ] || {
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
defaultPref("mousewheel.system_scroll_override.enabled", false);
defaultPref("services.sync.prefs.dangerously_allow_arbitrary", true);
defaultPref("services.sync.addons.ignoreUserEnabledChanges", true);
EOF
    unset LK_SUDO
}

DIR=~/.thunderbird
[[ ! -f $DIR/installs.ini ]] ||
    ! PROFILE=$DIR/$(awk \
        '/^Default=/ { sub(/^Default=/, ""); print; exit }' \
        "$DIR/installs.ini" | grep .) ||
    [[ ! -d $PROFILE ]] || {
    [[ -d $PROFILE/chrome ]] || install -d "$PROFILE/chrome"
    FILE=$PROFILE/chrome/userChrome.css
    lk_file_replace "$FILE" <<"EOF"
/**
 * The following rules only apply if 'toolkit.legacyUserProfileCustomizations.stylesheets' is set
 */
#tabbar-toolbar #task-tab-button,
#status-bar #tbsync\.status[value*='idle'i] {
  display: none;
}
EOF
}

symlink "$_ROOT/.tidyrc" ~/.tidyrc
symlink "$_ROOT/autorandr/" ~/.config/autorandr
symlink "$_ROOT/.byoburc" ~/.byoburc
symlink "$_ROOT/byobu/" ~/.byobu
symlink "$_ROOT/devilspie2/" ~/.config/devilspie2
symlink "$_ROOT/git" ~/.config/git
symlink "$_ROOT/plank/" ~/.config/plank
symlink "$_ROOT/quicktile/quicktile.cfg" ~/.config/quicktile.cfg
symlink "$_ROOT/remmina/" ~/.config/remmina
symlink "$_ROOT/rubocop/.rubocop.yml" ~/.rubocop.yml
symlink "$_ROOT/zeal/Zeal.conf" ~/.config/Zeal/Zeal.conf

unset LK_SYMLINK_NO_CHANGE
symlink "$_ROOT/systemd/user.control" ~/.config/systemd/user.control
! lk_false LK_SYMLINK_NO_CHANGE ||
    systemctl --user daemon-reload
[ "$(lk_system_memory)" -lt 7 ] || {
    lk_systemctl_enable_now -u libvirtd.service
    lk_systemctl_enable_now -u libvirt-guests.service
}

symlink_if_not_running \
    "$_ROOT/nextcloud/sync-exclude.lst" ~/.config/Nextcloud/sync-exclude.lst \
    Nextcloud "pgrep -x nextcloud"
[ -e ~/.config/Nextcloud/nextcloud.cfg ] || [ ! -d ~/.config/Nextcloud ] ||
    cp -v "$_ROOT/nextcloud/nextcloud.cfg" ~/.config/Nextcloud/nextcloud.cfg

symlink_if_not_running \
    "$_ROOT/subl/User/" ~/.config/sublime-text-3/Packages/User \
    "Sublime Text 3" "pgrep -x sublime_text"

symlink_if_not_running \
    "$_ROOT/smerge/User/" ~/.config/sublime-merge/Packages/User \
    "$_ROOT/smerge/Default/" ~/.config/sublime-merge/Packages/Default \
    "Sublime Merge" "pgrep -x sublime_merge"

symlink_if_not_running \
    "$_ROOT/clementine/Clementine.conf" ~/.config/Clementine/Clementine.conf \
    Clementine "pgrep -x clementine"

symlink_if_not_running \
    "$_ROOT/copyq/copyq.conf" ~/.config/copyq/copyq.conf \
    "$_ROOT/copyq/copyq-commands.ini" ~/.config/copyq/copyq-commands.ini \
    CopyQ "pgrep -x copyq"

symlink_if_not_running \
    "$_ROOT/geeqie/" ~/.config/geeqie \
    Geeqie "pgrep -x geeqie"

symlink_if_not_running \
    "$_ROOT/handbrake/presets.json" ~/.config/ghb/presets.json \
    HandBrake "pgrep -x ghb"

symlink_if_not_running \
    "$_ROOT/keepassxc/keepassxc.ini" ~/.config/keepassxc/keepassxc.ini \
    KeePassXC "pgrep -x keepassxc"

symlink_if_not_running \
    "$_ROOT/nomacs/" ~/.config/nomacs \
    nomacs "pgrep -x nomacs"

symlink_if_not_running \
    "$_ROOT/recoll/recoll.conf" ~/.recoll/recoll.conf \
    "$_ROOT/recoll/mimeview" ~/.recoll/mimeview \
    Recoll "pgrep -x 'recoll(index)?'"

symlink_if_not_running \
    "$_ROOT/stretchly/config.json" ~/.config/Stretchly/config.json \
    Stretchly "pgrep -f Stretchly"

symlink_if_not_running \
    "$_ROOT/todoist/config.json" ~/.config/Todoist/config.json \
    Todoist "pgrep -x todoist"

symlink_if_not_running \
    "$_ROOT/typora/profile.data" ~/.config/Typora/profile.data \
    "$_ROOT/typora/conf" ~/.config/Typora/conf \
    "$_ROOT/typora/themes" ~/.config/Typora/themes \
    Typora "pgrep -x Typora"

FILE=/opt/vscodium-bin/resources/app/product.json
if [ -f "$FILE" ]; then
    VSCODE_PRODUCT_JSON=$(jq '
.nameLong = "Visual Studio Code" |
.extensionsGallery = {
    "serviceUrl": "https://marketplace.visualstudio.com/_apis/public/gallery",
    "cacheUrl": "https://vscode.blob.core.windows.net/gallery/index",
    "itemUrl": "https://marketplace.visualstudio.com/items",
    "controlUrl": "",
    "recommendationsUrl": ""
  }' <"$FILE")
    diff <(jq <"$FILE") <(echo "$VSCODE_PRODUCT_JSON") >/dev/null ||
        LK_SUDO=1 lk_file_replace "$FILE" "$VSCODE_PRODUCT_JSON"
fi

# use `lpinfo -m` for driver names
lk_tty_print "Checking printers"
(
    lk_tty_detail "Brother HL-5450DN"
    sudo lpadmin -p HL5450DN -E \
        -D "Brother HL-5450DN" \
        -L "black and white" \
        -m "brother-HL-5450DN-cups-en.ppd" \
        -v "socket://10.10.10.10" \
        -o PageSize=A4 \
        -o Duplex=None \
        -o printer-error-policy=abort-job || exit

    lk_tty_detail "Brother HL-L3230CDW"
    sudo lpadmin -p HLL3230CDW -E \
        -D "Brother HL-L3230CDW" \
        -L "colour" \
        -m "brother_hll3230cdw_printer_en.ppd" \
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

LK_SUDO=1 lk_file_replace /etc/papersize a4

if [ -n "${DISPLAY-}" ]; then
    lk_tty_print "Setting dconf values"
    START_PLANK=1
    killall plank 2>/dev/null || START_PLANK=0
    if lk_has_arg --reset; then
        dconf reset -f /apps/guake/
        dconf reset -f /net/launchpad/plank/
        dconf reset -f /org/gnome/meld/
        dconf reset -f /org/gtk/settings/file-chooser/
    fi
    dconf load / <<"EOF"
[apps/guake/general]
infinite-history=true
prompt-on-quit=false
quick-open-command-line='code -g %(file_path)s:%(line_number)s'
quick-open-enable=true
restore-tabs-notify=false
restore-tabs-startup=false
save-tabs-when-changed=false
tab-ontop=true
use-popup=false
use-trayicon=false
window-halignment=1
window-losefocus=true
window-refocus=true

[apps/guake/keybindings/local]
switch-tab-last='disabled'
switch-tab1='<Alt>1'
switch-tab2='<Alt>2'
switch-tab3='<Alt>3'
switch-tab4='<Alt>4'
switch-tab5='<Alt>5'
switch-tab6='<Alt>6'
switch-tab7='<Alt>7'
switch-tab8='<Alt>8'
switch-tab9='<Alt>9'
switch-tab10='disabled'

[apps/guake/keybindings/global]
show-hide='F1'

[apps/guake/style/font]
palette='#303030303030:#E1E132321A1A:#6A6AB0B01717:#FFFFC0C00505:#72729F9FCFCF:#ECEC00004848:#2A2AA7A7E7E7:#F2F2F2F2F2F2:#5D5D5D5D5D5D:#FFFF36361E1E:#7B7BC9C91F1F:#FFFFD0D00A0A:#00007171FFFF:#FFFF1D1D6262:#4B4BB8B8FDFD:#A0A02020F0F0:#F2F2F2F2F2F2:#04041A1A3B3B'
palette-name='Elio'

[ca/desrt/dconf-editor]
show-warning=false

[net/launchpad/plank/docks/dock1]
current-workspace-only=true
dock-items=['thunderbird.dockitem', 'todoist.dockitem', 'clockify.dockitem', 'teams-for-linux.dockitem', 'msedge-hnpfjngllnobngcgfapefoaidbinmjnm-Default.dockitem', 'skypeforlinux.dockitem', 'caprine.dockitem', 'org.keepassxc.KeePassXC.dockitem']
lock-items=true
theme='Transparent'

[org/gnome/desktop/interface]
document-font-name='Source Sans Pro 9'
font-name='Source Sans Pro 9'
monospace-font-name='JetBrains Mono NL 9'

[org/gnome/meld]
custom-editor-command='code -g {file}:{line}'
folder-columns=[('size', true), ('modification time', true), ('permissions', true)]
highlight-syntax=true
indent-width=4
show-line-numbers=true
style-scheme='cobalt'
text-filters=[('CVS/SVN keywords', false, '\\$\\w+(:[^\\n$]+)?\\$'), ('C++ comment', false, '//.*'), ('C comment', false, '/\\*.*?\\*/'), ('All whitespace', false, '[ \\t\\r\\f\\v]*'), ('Leading whitespace', true, '^[ \\t\\r\\f\\v]*'), ('Trailing whitespace', false, '[ \\t\\r\\f\\v]*$'), ('Script comment', false, '#.*')]
use-system-editor=false
wrap-mode='word'

[org/gnome/nm-applet]
disable-connected-notifications=true

[org/gtk/settings/file-chooser]
date-format='with-time'
sort-directories-first=true

[org/mate/engrampa/dialogs/batch-add]
default-extension='.zip'

[org/virt-manager/virt-manager]
xmleditor-enabled=true

[org/virt-manager/virt-manager/connections]
autoconnect=['qemu:///system']

[org/virt-manager/virt-manager/console]
auto-redirect=false
grab-keys='65515,65516'
scaling=0

[org/virt-manager/virt-manager/new-vm]
add-spice-usbredir='no'
cpu-default='hv-default'
graphics-type='system'

[org/virt-manager/virt-manager/stats]
enable-cpu-poll=true
enable-disk-poll=true
enable-memory-poll=true
enable-net-poll=true
update-interval=5

[org/virt-manager/virt-manager/vmlist-fields]
cpu-usage=true
disk-usage=true
host-cpu-usage=true
memory-usage=true
network-traffic=true
EOF
    LK_SCREENSHOT_DIR=${LK_SCREENSHOT_DIR:-~/Desktop}
    dconf write /org/virt-manager/virt-manager/paths/screenshot-default \
        "'$LK_SCREENSHOT_DIR'"
    lk_false START_PLANK || (
        nohup plank &>/dev/null &
        disown
    )

    lk_tty_print "Checking Xfce4"
    ! lk_has_arg --reset ||
        set -- --reset
    "$_ROOT/../bin/configure-xfce4.sh" "$@" && {
        xfconf-query -c xfwm4 -p /general/theme -n -t string -s "Qogir-Dark"
        xfconf-query -c xfwm4 -p /general/title_font -n -t string -s "Source Sans Pro Semi-Bold 8"
        xfconf-query -c xsettings -p /Gtk/CursorThemeName -n -t string -s "Qogir-dark"
        xfconf-query -c xsettings -p /Gtk/FontName -n -t string -s "$DEFAULT_FONT 9"
        xfconf-query -c xsettings -p /Gtk/ButtonImages -n -t bool -s false
        xfconf-query -c xsettings -p /Gtk/MenuImages -n -t bool -s true
        xfconf-query -c xsettings -p /Gtk/MonospaceFontName -n -t string -s "$DEFAULT_MONOSPACE_FONT 9"
        xfconf-query -c xsettings -p /Net/IconThemeName -n -t string -s "Tela-dark"
        xfconf-query -c xsettings -p /Net/ThemeName -n -t string -s "Qogir-Dark"
    }
fi
