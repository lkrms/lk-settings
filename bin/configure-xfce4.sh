#!/bin/bash

lk_die() { echo "${BS:+$BS: }$1" >&2 && exit 1; }
BS=${BASH_SOURCE[0]} &&
    [ ! -L "$BS" ] && _ROOT=$(cd "${BS%/*}/../desktop" && pwd -P) ||
    lk_die "unable to resolve path to script"

# shellcheck source=./settings-common.sh
. "$_ROOT/../bin/settings-common.sh"
lk_include linux provision

lk_assert_command_exists xfconf-query

function xfce4_apply_setting() {
    local ARGS
    case "$VALUE_TYPE" in
    bool | int | uint | int64 | uint64 | double | string)
        eval "VALUE=\"$VALUE\""
        xfconf-query -c "$CHANNEL" -p "$PROPERTY" -nt "$VALUE_TYPE" -s "$VALUE"
        ;;
    array)
        eval "ARGS=($VALUE)"
        xfconf-query -c "$CHANNEL" -p "$PROPERTY" -na "${ARGS[@]}"
        ;;
    reset)
        xfconf-query -c "$CHANNEL" -p "$PROPERTY" -rR
        ;;
    *)
        lk_console_warning \
            "Invalid syntax in $FILE at setting #$i: ${XFCONF_SETTING[$i]}"
        ;;
    esac
}

function xfce4_string_array() {
    local ELEM
    for ELEM in "$@"; do
        echo "-t string -s $ELEM"
    done
}

PLUGINS=()
while read -r PLUGIN_ID PLUGIN_NAME; do
    PLUGINS[$PLUGIN_ID]=$PLUGIN_NAME
done < <(xfconf-query -c xfce4-panel -p /plugins -lv |
    grep -Po "(?<=^/plugins/plugin-)[0-9]+$S+$NS+\$" | sort -n)

FILE=$_ROOT/xfce4/xfconf-settings
lk_mapfile XFCONF_SETTING <(sed -E "/^($S*\$|#)/d" "$FILE")

for i in "${!XFCONF_SETTING[@]}"; do
    IFS=',' read -r CHANNEL PROPERTY VALUE_TYPE VALUE \
        <<<"${XFCONF_SETTING[$i]}"

    if [[ $CHANNEL =~ ^.+:.+ ]]; then
        CUSTOM_TYPE=${CHANNEL%%:*}
        CHANNEL=${CHANNEL#*:}
        case "$CUSTOM_TYPE" in
        *desktop*)
            ! lk_is_portable || continue
            ;;&
        *laptop*)
            lk_is_portable || continue
            ;;&
        *reset*)
            lk_has_arg "--reset" || continue
            ;;
        esac
    fi

    if [ "$CHANNEL" = xfce4-panel ] && [[ $PROPERTY == /plugins/* ]]; then
        PLUGIN_NAME=${PROPERTY#/plugins/}
        PLUGIN_NAME=${PLUGIN_NAME%%/*}
        PLUGIN_PROPERTY=${PROPERTY#/plugins/$PLUGIN_NAME/}
        for j in "${!PLUGINS[@]}"; do
            if [ "${PLUGINS[$j]}" = "$PLUGIN_NAME" ]; then
                PROPERTY=/plugins/plugin-$j/$PLUGIN_PROPERTY
                xfce4_apply_setting
            fi
        done
        continue
    fi

    xfce4_apply_setting
done

! lk_command_exists autorandr ||
    lk_env_clean autorandr -c --force

DPI=$(lk_x_dpi) || DPI=

CONF=$(grep -Ev \
    "^(xft-dpi$S*=|\$)" \
    "$_ROOT/xfce4/lightdm/lightdm-gtk-greeter.conf" &&
    [ -z "$DPI" ] || echo "xft-dpi = $DPI")
LK_SUDO=1 lk_file_replace /etc/lightdm/lightdm-gtk-greeter.conf "$CONF"

if [ -n "$DPI" ] && [ -f /etc/default/grub ]; then
    _MULTIPLIER=$(bc <<<"scale = 10; $DPI / 96")
    _16=$(bc <<<"v = 16 * $_MULTIPLIER / 1; v - v % 2")
    GRUB_FONT_FILE=${GRUB_FONT_FILE-$(
        fc-list --format="%{file}" \
            ":family=xos4 Terminus:style=Regular:pixelsize=$_16"
    )}
    if [ -f "$GRUB_FONT_FILE" ]; then
        GRUB_FONT=${GRUB_FONT_FILE##*/}
        GRUB_FONT=/boot/grub/fonts/${GRUB_FONT%%.*}-$_16.pf2
        GRUB_FONT_VAR=$(lk_get_shell_var GRUB_FONT)
        if ! grep -Fxq "$GRUB_FONT_VAR" /etc/default/grub ||
            [ ! -f "$GRUB_FONT" ]; then
            _PF2=$(mktemp)
            grub-mkfont -s "$_16" -o "$_PF2" "$GRUB_FONT_FILE"
            [ -d "${_GRUB_FONT_DIR:=${GRUB_FONT%/*}}" ] ||
                sudo install -v -d -m 0755 "$_GRUB_FONT_DIR"
            sudo install -v -m 0755 "$_PF2" "$GRUB_FONT"
            LK_SUDO=1
            _FILE=$(sed -E '/^GRUB_FONT=/d' /etc/default/grub)
            lk_file_replace /etc/default/grub \
                "$(echo "$_FILE" &&
                    echo "$GRUB_FONT_VAR")"
            unset LK_SUDO
            ! lk_command_exists update-grub ||
                sudo update-grub
        fi
    fi
fi

mkdir -pv ~/.config/xfce4/panel
cp -nv "$_ROOT/xfce4/panel"/*.rc ~/.config/xfce4/panel/
lk_symlink "$_ROOT/xfce4/terminal/config" ~/.config/xfce4/terminal
lk_symlink "$_ROOT/xfce4/terminal/data" ~/.local/share/xfce4/terminal
lk_symlink "$_ROOT/xfce4/thunar/" ~/.config/Thunar
lk_symlink "$_ROOT/xfce4/xfce4-panel-profiles/" \
    ~/.local/share/xfce4-panel-profiles

lk_symlink "$_ROOT/xfce4/share/themes/Adapta/plank/" \
    ~/.local/share/plank/themes/Adapta
lk_symlink /usr/share/themes/Adapta/gtk-3.24/gtk.gresource \
    "$_ROOT/xfce4/share/themes/Adapta/gtk-3.24/gtk.gresource" &&
    lk_symlink "$_ROOT/xfce4/share/themes/" \
        ~/.local/share/themes

rm -Rfv ~/.cache/sessions

[ -e ~/.config/pulse/default.pa ] || {
    mkdir -p ~/.config/pulse &&
        cp -v "$_ROOT/xfce4/pulse/default.pa" ~/.config/pulse/default.pa
}

# Make hddtemp work with xfce4-sensors-plugin
[ ! -f /etc/hddtemp.db ] ||
    LK_SUDO=1 lk_conf_enable_row \
        '"Samsung SSD 860 EVO" 190 C "Samsung SSD 860 EVO"' \
        /etc/hddtemp.db
[ ! -x /usr/sbin/hddtemp ] ||
    sudo chmod -c u+s /usr/sbin/hddtemp || true

lk_console_success "Xfce4 settings applied successfully"
