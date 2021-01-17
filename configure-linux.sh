#!/bin/bash

# shellcheck disable=SC1090,SC2015,SC2034,SC2207

set -euo pipefail
lk_die() { echo "${BS:+$BS: }$1" >&2 && exit 1; }
BS=${BASH_SOURCE[0]} &&
    [ ! -L "$BS" ] && SCRIPT_DIR=$(cd "${BS%/*}" && pwd -P) ||
    lk_die "unable to resolve path to script"

[ -d "${LK_BASE:-}" ] || lk_die "LK_BASE not set"

include=linux . "$LK_BASE/lib/bash/common.sh"

lk_assert_not_root
lk_assert_is_linux

LK_VERBOSE=1

set +e
shopt -s nullglob

! lk_command_exists yay ||
    yay --save --nocleanmenu --nodiffmenu --noremovemake

PRIVATE_DIR=~/.cloud-settings

[ ! -d "$PRIVATE_DIR" ] || {

    [ ! -e "$PRIVATE_DIR/.face" ] || {
        FACE_DIR=$(realpath "$PRIVATE_DIR/.face")
        FACE_DIR=${FACE_DIR%/*}
        HOME_DIR=$(realpath ~)
        while [ "${FACE_DIR:0:${#HOME_DIR}}" = "$HOME_DIR" ]; do
            chmod -c a+x "$FACE_DIR"
            FACE_DIR=${FACE_DIR%/*}
        done
    }

    lk_symlink "$PRIVATE_DIR/.bashrc" ~/.bashrc
    lk_symlink "$PRIVATE_DIR/.face" ~/.face
    lk_symlink "$PRIVATE_DIR/.gitconfig" ~/.gitconfig
    lk_symlink "$PRIVATE_DIR/.gitignore" ~/.gitignore
    lk_symlink "$PRIVATE_DIR/acme.sh/" ~/.acme.sh
    lk_symlink "$PRIVATE_DIR/aws/" ~/.aws
    lk_symlink "$PRIVATE_DIR/espanso/" ~/.config/espanso
    lk_symlink "$PRIVATE_DIR/linode-cli/linode-cli" ~/.config/linode-cli
    lk_symlink "$PRIVATE_DIR/offlineimap/.offlineimaprc" ~/.offlineimaprc
    lk_symlink "$PRIVATE_DIR/remmina/data/" ~/.local/share/remmina
    lk_symlink "$PRIVATE_DIR/robo3t/.3T/" ~/.3T
    lk_symlink "$PRIVATE_DIR/robo3t/3T/" ~/.config/3T
    lk_symlink "$PRIVATE_DIR/ssh/" ~/.ssh
    lk_symlink "$PRIVATE_DIR/unison/" ~/.unison

    pgrep -x "dbeaver" >/dev/null &&
        lk_warn "cannot apply settings while DBeaver is running" ||
        lk_symlink "$PRIVATE_DIR/DBeaverData/" ~/.local/share/DBeaverData

    for FILE in "$PRIVATE_DIR"/.*-settings; do
        lk_symlink "$FILE" ~/"${FILE##*/}"
    done

    for ICON_FILE in "$PRIVATE_DIR"/applications/*.png; do
        lk_icon_install "$ICON_FILE"
    done

    for DESKTOP_FILE in "$PRIVATE_DIR"/autostart/*.desktop; do
        lk_symlink "$DESKTOP_FILE" \
            ~/.config/autostart/"${DESKTOP_FILE##*/}"
    done

    for DESKTOP_FILE in "$PRIVATE_DIR"/applications/*.desktop; do
        [[ ${DESKTOP_FILE##*/} =~ \
        ^(caprine|skypeforlinux|teams|thunderbird)\.desktop$ ]] ||
            lk_symlink "$DESKTOP_FILE" \
                ~/.local/share/applications/"${DESKTOP_FILE##*/}"
    done

}

LK_SUDO=1
lk_symlink "$SCRIPT_DIR/.vimrc" /root/.vimrc
lk_symlink "$SCRIPT_DIR/iptables/iptables.rules" /etc/iptables/iptables.rules
lk_symlink "$SCRIPT_DIR/iptables/ip6tables.rules" /etc/iptables/ip6tables.rules
lk_symlink "$SCRIPT_DIR/libvirt/hooks/qemu" /etc/libvirt/hooks/qemu
# Fix weird Calibri rendering in Thunderbird
unset LK_SYMLINK_NO_CHANGE
lk_symlink "$SCRIPT_DIR/fonts/ms-no-bitmaps.conf" \
    /etc/fonts/conf.d/99-ms-no-bitmaps.conf
# Remove emoji from all fonts other than Noto Color Emoji
lk_symlink "$SCRIPT_DIR/fonts/emoji-fix.conf" \
    /etc/fonts/conf.d/99-emoji-fix.conf
lk_is_true LK_SYMLINK_NO_CHANGE ||
    { sudo -H fc-cache --force --verbose &&
        fc-cache --force --verbose; }

unset LK_SUDO

CRONTAB=$(awk \
    -v STRETCHLY="$(lk_double_quote "$SCRIPT_DIR/stretchly/stretchly.sh")" \
    '$6=="stretchly"{$6=STRETCHLY}{print}' \
    "$SCRIPT_DIR/crontab")
diff -q <(crontab -l) <(echo "${CRONTAB%$'\n'}") >/dev/null ||
    crontab <(echo "${CRONTAB%$'\n'}")

MIMEINFO_FILE=/usr/share/applications/mimeinfo.cache
MIMEAPPS_FILE=~/.config/mimeapps.list
[ ! -f "$MIMEINFO_FILE" ] || {
    REPLACE=(geany)
    REPLACE_WITH=(VSCodium)
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

lk_symlink "$SCRIPT_DIR/.vimrc" ~/.vimrc
lk_symlink "$SCRIPT_DIR/.tidyrc" ~/.tidyrc
lk_symlink "$SCRIPT_DIR/autorandr/" ~/.config/autorandr
lk_symlink "$SCRIPT_DIR/.byoburc" ~/.byoburc
lk_symlink "$SCRIPT_DIR/byobu/" ~/.byobu
lk_symlink "$SCRIPT_DIR/devilspie2/" ~/.config/devilspie2
lk_symlink "$SCRIPT_DIR/plank/" ~/.config/plank
lk_symlink "$SCRIPT_DIR/quicktile/quicktile.cfg" ~/.config/quicktile.cfg
lk_symlink "$SCRIPT_DIR/remmina/" ~/.config/remmina
lk_symlink "$SCRIPT_DIR/todoist/.todoist-linux.json" ~/.config/.todoist-linux.json

lk_symlink "$SCRIPT_DIR/nextcloud/sync-exclude.lst" \
    ~/.config/Nextcloud/sync-exclude.lst && {
    [ -e ~/.config/Nextcloud/nextcloud.cfg ] ||
        cp -v "$SCRIPT_DIR/nextcloud/nextcloud.cfg" \
            ~/.config/Nextcloud/nextcloud.cfg
}

lk_console_message "Checking Sublime Text 3"
pgrep -x "sublime_text" >/dev/null &&
    lk_warn "cannot apply settings while Sublime Text 3 is running" ||
    lk_symlink "$SCRIPT_DIR/subl/User/" \
        ~/.config/sublime-text-3/Packages/User

lk_console_message "Checking Sublime Merge"
pgrep -x "sublime_merge" >/dev/null &&
    lk_warn "cannot apply settings while Sublime Merge is running" ||
    lk_symlink "$SCRIPT_DIR/smerge/User/" \
        ~/.config/sublime-merge/Packages/User

lk_console_message "Checking Clementine"
pgrep -x "clementine" >/dev/null &&
    lk_warn "cannot apply settings while Clementine is running" ||
    lk_symlink "$SCRIPT_DIR/clementine/Clementine.conf" \
        ~/.config/Clementine/Clementine.conf

lk_console_message "Checking CopyQ"
pgrep -x "copyq" >/dev/null &&
    lk_warn "cannot apply settings while CopyQ is running" || {
    lk_symlink "$SCRIPT_DIR/copyq/copyq.conf" \
        ~/.config/copyq/copyq.conf &&
        lk_symlink "$SCRIPT_DIR/copyq/copyq-commands.ini" \
            ~/.config/copyq/copyq-commands.ini
}

lk_console_message "Checking Flameshot"
pgrep -x "flameshot" >/dev/null &&
    lk_warn "cannot apply settings while Flameshot is running" ||
    lk_symlink "$SCRIPT_DIR/flameshot/flameshot.ini" \
        ~/.config/flameshot/flameshot.ini

lk_console_message "Checking Geeqie"
pgrep -x "geeqie" >/dev/null &&
    lk_warn "cannot apply settings while Geeqie is running" ||
    lk_symlink "$SCRIPT_DIR/geeqie/" \
        ~/.config/geeqie

lk_console_message "Checking HandBrake"
pgrep -x "ghb" >/dev/null &&
    lk_warn "cannot apply settings while HandBrake is running" ||
    lk_symlink "$SCRIPT_DIR/handbrake/presets.json" \
        ~/.config/ghb/presets.json

lk_console_message "Checking KeePassXC"
pgrep -x "keepassxc" >/dev/null &&
    lk_warn "cannot apply settings while KeePassXC is running" ||
    lk_symlink "$SCRIPT_DIR/keepassxc/keepassxc.ini" \
        ~/.config/keepassxc/keepassxc.ini

lk_console_message "Checking nomacs"
pgrep -x "nomacs" >/dev/null &&
    lk_warn "cannot apply settings while nomacs is running" ||
    lk_symlink "$SCRIPT_DIR/nomacs/" \
        ~/.config/nomacs

lk_console_message "Checking Recoll"
pgrep -x "recoll(index)?" >/dev/null &&
    lk_warn "cannot apply settings while Recoll is running" || {
    lk_symlink "$SCRIPT_DIR/recoll/recoll.conf" \
        ~/.recoll/recoll.conf &&
        lk_symlink "$SCRIPT_DIR/recoll/mimeview" \
            ~/.recoll/mimeview
}

lk_console_message "Checking Stretchly"
pgrep -f "Stretchly" >/dev/null &&
    lk_warn "cannot apply settings while Stretchly is running" || {
    lk_symlink "$SCRIPT_DIR/stretchly/config.json" \
        ~/.config/Stretchly/config.json
}

lk_console_message "Checking Typora"
pgrep -x "Typora" >/dev/null &&
    lk_warn "cannot apply settings while Typora is running" || {
    lk_symlink "$SCRIPT_DIR/typora/profile.data" \
        ~/.config/Typora/profile.data &&
        lk_symlink "$SCRIPT_DIR/typora/conf" \
            ~/.config/Typora/conf &&
        lk_symlink "$SCRIPT_DIR/typora/themes" \
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
    lk_symlink "$SCRIPT_DIR/vscode/settings.json" \
        ~/.config/VSCodium/User/settings.json &&
        lk_symlink "$SCRIPT_DIR/vscode/keybindings.linux.json" \
            ~/.config/VSCodium/User/keybindings.json &&
        lk_symlink "$SCRIPT_DIR/vscode/snippets" \
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
        nohup plank </dev/null >/dev/null 2>&1 &
        disown
        sleep 2
    }

    lk_console_message "Checking Xfce4"
    "$SCRIPT_DIR/configure-xfce4.sh" "$@" &&
        lk_symlink "$LK_BASE/etc/xfce4/xinitrc" ~/.config/xfce4/xinitrc && {
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
    . "$SCRIPT_DIR/vscode/extensions.sh" || exit
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
                "Remove or add to $SCRIPT_DIR/vscode/extensions.sh:" \
                extension extensions
        lk_console_detail "To remove, run" "code --uninstall-extension <ext-id>"
    }
}
