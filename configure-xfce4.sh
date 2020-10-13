#!/bin/bash
# shellcheck disable=SC1090,SC2015

set -euo pipefail
lk_die() { echo "${BS:+$BS: }$1" >&2 && exit 1; }
BS="${BASH_SOURCE[0]}" && [ ! -L "$BS" ] &&
    SCRIPT_DIR="$(cd "$(dirname "$BS")" && pwd -P)" ||
    lk_die "unable to resolve path to script"

[ -d "${LK_BASE:-}" ] || lk_die "LK_BASE not set"

include=linux,provision . "$LK_BASE/lib/bash/common.sh"

lk_assert_command_exists xfconf-query

function xfce4_apply_setting() {

    local ARGS

    case "$VALUE_TYPE" in

    bool | int | uint | int64 | uint64 | double | string)
        eval "VALUE=\"$VALUE\""
        xfconf-query -c "$CHANNEL" -p "$PROPERTY" -n -t "$VALUE_TYPE" -s "$VALUE"
        ;;

    array)
        eval "ARGS=($VALUE)"
        xfconf-query -c "$CHANNEL" -p "$PROPERTY" -na "${ARGS[@]}"
        ;;

    reset)
        xfconf-query -c "$CHANNEL" -p "$PROPERTY" -rR
        ;;

    *)
        lk_console_warning "Invalid syntax in $SCRIPT_DIR/xfce4/xfconf-settings at setting #$i: ${XFCONF_SETTING[$i]}"
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

    PLUGINS[$PLUGIN_ID]="$PLUGIN_NAME"

done < <(xfconf-query -c xfce4-panel -p /plugins -lv | grep -Po '(?<=^/plugins/plugin-)[0-9]+\s+[^\s]+$' | sort -n)

lk_mapfile "$SCRIPT_DIR/xfce4/xfconf-settings" XFCONF_SETTING '^([[:blank:]]*$|#)'

for i in "${!XFCONF_SETTING[@]}"; do

    IFS=',' read -r CHANNEL PROPERTY VALUE_TYPE VALUE <<<"${XFCONF_SETTING[$i]}"

    if [[ "$CHANNEL" =~ ^.+:.+ ]]; then

        CUSTOM_TYPE="${CHANNEL%%:*}"
        CHANNEL="${CHANNEL#*:}"

        case "$CUSTOM_TYPE" in

        *desktop*)
            ! lk_is_portable || continue
            ;;&

        *laptop*)
            lk_is_portable || continue
            ;;&

        *reset*)
            lk_has_arg "--reset" || continue
            ;;&

        esac

    fi

    if [ "$CHANNEL" = "xfce4-panel" ] && [[ "$PROPERTY" == /plugins/* ]]; then

        PLUGIN_NAME="${PROPERTY#/plugins/}"
        PLUGIN_NAME="${PLUGIN_NAME%%/*}"
        PLUGIN_PROPERTY="${PROPERTY#/plugins/$PLUGIN_NAME/}"

        for j in "${!PLUGINS[@]}"; do

            if [ "${PLUGINS[$j]}" = "$PLUGIN_NAME" ]; then

                PROPERTY="/plugins/plugin-$j/$PLUGIN_PROPERTY"

                xfce4_apply_setting

            fi

        done

        continue

    fi

    xfce4_apply_setting

done

! lk_command_exists autorandr ||
    autorandr -c --force

function lightdm_gtk_greeter_conf() {
    cat <(grep -Ev '^(xft-dpi[[:blank:]]*=|$)' \
        "$SCRIPT_DIR/xfce4/lightdm/lightdm-gtk-greeter.conf")
    [ -z "$DPI" ] || echo "xft-dpi = $DPI"
}

DPI="$(lk_x_dpi)" || DPI=

if ! diff -Nq \
    <(lightdm_gtk_greeter_conf) \
    <(cat "/etc/lightdm/lightdm-gtk-greeter.conf") >/dev/null; then
    sudo cp -v "$SCRIPT_DIR/xfce4/lightdm/lightdm-gtk-greeter.conf" \
        "/etc/lightdm/lightdm-gtk-greeter.conf"
    lightdm_gtk_greeter_conf |
        sudo tee "/etc/lightdm/lightdm-gtk-greeter.conf" >/dev/null
fi

if [ -n "$DPI" ] && [ -f "/etc/default/grub" ]; then
    _MULTIPLIER="$(bc <<<"scale = 10; $DPI / 96")"
    _16="$(bc <<<"v = 16 * $_MULTIPLIER / 1; v - v % 2")"
    GRUB_FONT_FILE="${GRUB_FONT_FILE-$(
        fc-list --format="%{file}" \
            ":family=xos4 Terminus:style=Regular:pixelsize=$_16"
    )}"
    if [ -f "$GRUB_FONT_FILE" ]; then
        GRUB_FONT="${GRUB_FONT_FILE##*/}"
        GRUB_FONT="/boot/grub/fonts/${GRUB_FONT%%.*}-$_16.pf2"
        GRUB_FONT_VAR=$(lk_get_shell_var GRUB_FONT)
        if ! grep -Fxq "$GRUB_FONT_VAR" "/etc/default/grub" ||
            [ ! -f "$GRUB_FONT" ]; then
            _PF2="$(mktemp)"
            grub-mkfont -s "$_16" -o "$_PF2" "$GRUB_FONT_FILE"
            [ -d "${_GRUB_FONT_DIR:=${GRUB_FONT%/*}}" ] ||
                sudo install -v -d -m 0755 "$_GRUB_FONT_DIR"
            sudo install -v -m 0755 "$_PF2" "$GRUB_FONT"
            LK_SUDO=1 lk_maybe_add_newline "/etc/default/grub"
            LK_SUDO=1 lk_maybe_replace "/etc/default/grub" \
                "$(
                    sed -E '/^GRUB_FONT=/d' "/etc/default/grub"
                    echo "$GRUB_FONT_VAR"
                )"
            ! lk_command_exists update-grub || sudo update-grub
        fi
    fi
fi

mkdir -pv "$HOME/.config/xfce4/panel"
cp -nv "$SCRIPT_DIR/xfce4/panel"/*.rc "$HOME/.config/xfce4/panel/"
lk_safe_symlink "$SCRIPT_DIR/xfce4/terminal/config" "$HOME/.config/xfce4/terminal"
lk_safe_symlink "$SCRIPT_DIR/xfce4/terminal/data" "$HOME/.local/share/xfce4/terminal"
lk_safe_symlink "$SCRIPT_DIR/xfce4/thunar/" "$HOME/.config/Thunar"
lk_safe_symlink "$SCRIPT_DIR/xfce4/xfce4-panel-profiles/" "$HOME/.local/share/xfce4-panel-profiles"

rm -Rfv "$HOME/.cache/sessions"

[ -e "$HOME/.config/pulse/default.pa" ] || {
    mkdir -p "$HOME/.config/pulse" &&
        cp -v "$SCRIPT_DIR/xfce4/pulse/default.pa" "$HOME/.config/pulse/default.pa"
}

# otherwise xfce4-sensors-plugin will not work
[ ! -f "/etc/hddtemp.db" ] ||
    LK_SUDO=1 lk_enable_entry "/etc/hddtemp.db" \
        '"Samsung SSD 860 EVO" 190 C "Samsung SSD 860 EVO"' "# " ""
[ ! -x "/usr/sbin/hddtemp" ] ||
    sudo chmod -c u+s "/usr/sbin/hddtemp" || true

lk_console_message "Xfce4 settings applied successfully"
