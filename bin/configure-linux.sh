#!/bin/bash

lk_die() { echo "${BS:+$BS: }$1" >&2 && exit 1; }
BS=${BASH_SOURCE[0]} &&
    [ ! -L "$BS" ] && _ROOT=$(cd "${BS%/*}/../desktop" && pwd -P) ||
    lk_die "unable to resolve path to script"

# shellcheck source=./settings-common.sh
include=linux . "$_ROOT/../bin/settings-common.sh"

lk_assert_not_root
lk_assert_is_linux

cleanup

_PRIV=${1:-}

[ ! -d "$_PRIV" ] || {

    symlink_private_common "$_PRIV"
    symlink \
        "$_PRIV/.face" ~/.face \
        "$_PRIV/espanso/" ~/.config/espanso \
        "$_PRIV/offlineimap/.offlineimaprc" ~/.offlineimaprc \
        "$_PRIV/remmina/data/" ~/.local/share/remmina \
        "$_PRIV/robo3t/.3T/" ~/.3T \
        "$_PRIV/robo3t/3T/" ~/.config/3T \
        "$_PRIV/unison/" ~/.unison

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
        lk_symlink \
            "$FILE" ~/.config/autostart/"${FILE##*/}"
    done

    for FILE in "$_PRIV/applications"/*.desktop; do
        _FILE=${FILE##*/}
        case "${_FILE%.desktop}" in
        caprine | skypeforlinux | teams | thunderbird)
            continue
            ;;
        *)
            lk_symlink \
                "$FILE" ~/.local/share/applications/"${FILE##*/}"
            ;;
        esac
    done

}

LK_SUDO=1

lk_symlink "$_ROOT/.vimrc" /root/.vimrc

lk_symlink "$_ROOT/iptables/iptables.rules" /etc/iptables/iptables.rules
lk_symlink "$_ROOT/iptables/ip6tables.rules" /etc/iptables/ip6tables.rules
lk_symlink "$_ROOT/libvirt/hooks/qemu" /etc/libvirt/hooks/qemu

unset LK_SYMLINK_NO_CHANGE
# Fix weird Calibri rendering in Thunderbird
lk_symlink \
    "$_ROOT/fonts/ms-no-bitmaps.conf" /etc/fonts/conf.d/99-ms-no-bitmaps.conf
# Remove emoji from all fonts other than Noto Color Emoji
lk_symlink \
    "$_ROOT/fonts/emoji-fix.conf" /etc/fonts/conf.d/99-emoji-fix.conf
lk_is_true LK_SYMLINK_NO_CHANGE ||
    { sudo -H fc-cache --force --verbose && fc-cache --force --verbose; }

unset LK_SUDO

! lk_command_exists crontab || {
    CRONTAB=$(awk \
        -v STRETCHLY="$(lk_double_quote "$_ROOT/stretchly/stretchly.sh")" \
        '$6=="stretchly"{$6=STRETCHLY}{print}' \
        "$_ROOT/cron/crontab")
    diff -q <(crontab -l) <(echo "${CRONTAB%$'\n'}") >/dev/null || {
        lk_console_message "Updating crontab"
        crontab <(echo "${CRONTAB%$'\n'}")
    }
}

MIMEINFO_FILE=/usr/share/applications/mimeinfo.cache
MIMEAPPS_FILE=~/.config/mimeapps.list
[ ! -f "$MIMEINFO_FILE" ] || {
    REPLACE=(geany vim)
    REPLACE_WITH=(VSCodium VSCodium)
    PREFER=(
        VSCodium

        # Prefer Firefox over vscode for text/html
        firefox

        # Prefer Thunar for inode/directory
        thunar

        #
        nomacs
        ristretto

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
        mkdir -pv "${MIMEAPPS_FILE%/*}" && {
        echo "[Default Applications]"
        comm -23 \
            <(grep -E '.+=.+' "$MIMEINFO_FILE" | "${SED_COMMAND[@]}" | sort) \
            <(sort "$MIMEINFO_FILE")
    } >"$MIMEAPPS_FILE"
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

[ ! -d /usr/lib/firefox ] || {
    sudo mkdir -p /usr/lib/firefox/defaults/pref
    printf '%s\n' \
        '// the first line is ignored' \
        'pref("general.config.filename", "firefox.cfg");' \
        'pref("general.config.obscure_value", 0);' |
        sudo tee /usr/lib/firefox/defaults/pref/autoconfig.js >/dev/null
    printf '%s\n' \
        '// the first line is ignored' \
        'defaultPref("services.sync.prefs.dangerously_allow_arbitrary", true);' |
        sudo tee /usr/lib/firefox/firefox.cfg >/dev/null
}

lk_symlink "$_ROOT/.vimrc" ~/.vimrc
lk_symlink "$_ROOT/.tidyrc" ~/.tidyrc
lk_symlink "$_ROOT/autorandr/" ~/.config/autorandr
lk_symlink "$_ROOT/.byoburc" ~/.byoburc
lk_symlink "$_ROOT/byobu/" ~/.byobu
lk_symlink "$_ROOT/devilspie2/" ~/.config/devilspie2
lk_symlink "$_ROOT/git" ~/.config/git
lk_symlink "$_ROOT/plank/" ~/.config/plank
lk_symlink "$_ROOT/quicktile/quicktile.cfg" ~/.config/quicktile.cfg
lk_symlink "$_ROOT/remmina/" ~/.config/remmina
lk_symlink "$_ROOT/todoist/.todoist-linux.json" ~/.config/.todoist-linux.json

lk_symlink "$_ROOT/nextcloud/sync-exclude.lst" \
    ~/.config/Nextcloud/sync-exclude.lst && {
    [ -e ~/.config/Nextcloud/nextcloud.cfg ] ||
        cp -v "$_ROOT/nextcloud/nextcloud.cfg" \
            ~/.config/Nextcloud/nextcloud.cfg
}

lk_console_message "Checking Sublime Text 3"
pgrep -x "sublime_text" >/dev/null &&
    lk_warn "cannot apply settings while Sublime Text 3 is running" ||
    lk_symlink "$_ROOT/subl/User/" \
        ~/.config/sublime-text-3/Packages/User

lk_console_message "Checking Sublime Merge"
pgrep -x "sublime_merge" >/dev/null &&
    lk_warn "cannot apply settings while Sublime Merge is running" ||
    lk_symlink "$_ROOT/smerge/User/" \
        ~/.config/sublime-merge/Packages/User

lk_console_message "Checking Clementine"
pgrep -x "clementine" >/dev/null &&
    lk_warn "cannot apply settings while Clementine is running" ||
    lk_symlink "$_ROOT/clementine/Clementine.conf" \
        ~/.config/Clementine/Clementine.conf

lk_console_message "Checking CopyQ"
pgrep -x "copyq" >/dev/null &&
    lk_warn "cannot apply settings while CopyQ is running" || {
    lk_symlink "$_ROOT/copyq/copyq.conf" \
        ~/.config/copyq/copyq.conf &&
        lk_symlink "$_ROOT/copyq/copyq-commands.ini" \
            ~/.config/copyq/copyq-commands.ini
}

lk_console_message "Checking Flameshot"
pgrep -x "flameshot" >/dev/null &&
    lk_warn "cannot apply settings while Flameshot is running" ||
    lk_symlink "$_ROOT/flameshot/flameshot.ini" \
        ~/.config/flameshot/flameshot.ini

lk_console_message "Checking Geeqie"
pgrep -x "geeqie" >/dev/null &&
    lk_warn "cannot apply settings while Geeqie is running" ||
    lk_symlink "$_ROOT/geeqie/" \
        ~/.config/geeqie

lk_console_message "Checking HandBrake"
pgrep -x "ghb" >/dev/null &&
    lk_warn "cannot apply settings while HandBrake is running" ||
    lk_symlink "$_ROOT/handbrake/presets.json" \
        ~/.config/ghb/presets.json

lk_console_message "Checking KeePassXC"
pgrep -x "keepassxc" >/dev/null &&
    lk_warn "cannot apply settings while KeePassXC is running" ||
    lk_symlink "$_ROOT/keepassxc/keepassxc.ini" \
        ~/.config/keepassxc/keepassxc.ini

lk_console_message "Checking nomacs"
pgrep -x "nomacs" >/dev/null &&
    lk_warn "cannot apply settings while nomacs is running" ||
    lk_symlink "$_ROOT/nomacs/" \
        ~/.config/nomacs

lk_console_message "Checking Recoll"
pgrep -x "recoll(index)?" >/dev/null &&
    lk_warn "cannot apply settings while Recoll is running" || {
    lk_symlink "$_ROOT/recoll/recoll.conf" \
        ~/.recoll/recoll.conf &&
        lk_symlink "$_ROOT/recoll/mimeview" \
            ~/.recoll/mimeview
}

lk_console_message "Checking Stretchly"
pgrep -f "Stretchly" >/dev/null &&
    lk_warn "cannot apply settings while Stretchly is running" || {
    lk_symlink "$_ROOT/stretchly/config.json" \
        ~/.config/Stretchly/config.json
}

lk_console_message "Checking Typora"
pgrep -x "Typora" >/dev/null &&
    lk_warn "cannot apply settings while Typora is running" || {
    lk_symlink "$_ROOT/typora/profile.data" \
        ~/.config/Typora/profile.data &&
        lk_symlink "$_ROOT/typora/conf" \
            ~/.config/Typora/conf &&
        lk_symlink "$_ROOT/typora/themes" \
            ~/.config/Typora/themes
}

lk_console_message "Checking Visual Studio Code"
pgrep -x 'codium' >/dev/null &&
    lk_warn "cannot apply settings while Visual Studio Code is running" || {
    FILE=/usr/share/vscodium-bin/resources/app/product.json
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
    lk_symlink "$_ROOT/vscode/settings.json" \
        ~/.config/VSCodium/User/settings.json &&
        lk_symlink "$_ROOT/vscode/keybindings.linux.json" \
            ~/.config/VSCodium/User/keybindings.json &&
        lk_symlink "$_ROOT/vscode/snippets" \
            ~/.config/VSCodium/User/snippets
}

# use `lpinfo -m` for driver names
lk_console_message "Checking printers"
sudo lpadmin -p HL5450DN -E \
    -D "Brother HL-5450DN" \
    -L "black and white" \
    -m "brother-HL-5450DN-cups-en.ppd" \
    -v "socket://10.10.10.10" \
    -o PageSize=A4 \
    -o Duplex=None \
    -o printer-error-policy=abort-job
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

[ -e /etc/papersize ] && grep -q ^a4$ /etc/papersize ||
    echo "a4" | sudo tee /etc/papersize >/dev/null

if [ -n "${DISPLAY:-}" ]; then
    lk_console_message "Setting dconf values"
    START_PLANK=1
    killall plank 2>/dev/null || START_PLANK=0
    if lk_has_arg --reset; then
        dconf reset -f /apps/guake/
        dconf reset -f /net/launchpad/plank/
        dconf reset -f /org/gnome/meld/
        dconf reset -f /org/gtk/settings/file-chooser/
    fi
    LK_SCREENSHOT_DIR=${LK_SCREENSHOT_DIR:-~/Desktop}
    dconf load / <<EOF
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

[net/launchpad/plank/docks/dock1]
current-workspace-only=true
dock-items=['thunderbird.dockitem', 'todoist.dockitem', 'teams.dockitem', 'skypeforlinux.dockitem', 'caprine.dockitem', 'org.keepassxc.KeePassXC.dockitem']
lock-items=true
theme='Adapta'

[org/gnome/desktop/interface]
document-font-name='Cantarell 9'
font-name='Cantarell 9'
monospace-font-name='Source Code Pro 10'

[org/gnome/meld]
custom-editor-command='code -g {file}:{line}'
folder-columns=[('size', true), ('modification time', true), ('permissions', true)]
highlight-syntax=true
indent-width=4
show-line-numbers=true
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

[org/virt-manager/virt-manager/paths]
screenshot-default='$LK_SCREENSHOT_DIR'

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
    lk_is_false START_PLANK || {
        nohup plank </dev/null &>/dev/null &
        disown
        sleep 2
    }

    lk_console_message "Checking Xfce4"
    "$_ROOT/../bin/configure-xfce4.sh" "$@" && {
        xfconf-query -c xfwm4 -p /general/theme -n -t string -s "Adapta"
        xfconf-query -c xfwm4 -p /general/title_font -n -t string -s "Cantarell 9"
        xfconf-query -c xsettings -p /Gtk/FontName -n -t string -s "Cantarell 9"
        xfconf-query -c xsettings -p /Gtk/MonospaceFontName -n -t string -s "Source Code Pro 10"
        xfconf-query -c xsettings -p /Net/IconThemeName -n -t string -s "Papirus"
        xfconf-query -c xsettings -p /Net/SoundThemeName -n -t string -s "elementary"
        xfconf-query -c xsettings -p /Net/ThemeName -n -t string -s "Adapta"
    }
fi

! lk_command_exists code || {
    lk_console_message "Checking Visual Studio Code extensions"
    . "$_ROOT/vscode/extensions.sh" || exit
    VSCODE_MISSING_EXTENSIONS=($(
        comm -13 \
            <(code --list-extensions | sort -u) \
            <(lk_echo_array VSCODE_EXTENSIONS | sort -u)
    ))
    [ ${#VSCODE_MISSING_EXTENSIONS[@]} -eq 0 ] ||
        for EXT in "${VSCODE_MISSING_EXTENSIONS[@]}"; do
            code --install-extension "$EXT"
        done
    VSCODE_EXTRA_EXTENSIONS=($(
        comm -23 \
            <(code --list-extensions | sort -u) \
            <(lk_echo_array VSCODE_EXTENSIONS | sort -u)
    ))
    [ ${#VSCODE_EXTRA_EXTENSIONS[@]} -eq 0 ] || {
        [ ${#VSCODE_MISSING_EXTENSIONS[@]} -eq 0 ] || lk_console_blank
        lk_echo_array VSCODE_EXTRA_EXTENSIONS |
            lk_console_detail_list \
                "Remove or add to $_ROOT/vscode/extensions.sh:" \
                extension extensions
        lk_console_detail "To remove, run" "code --uninstall-extension <ext-id>"
    }
}
