#!/bin/bash

. /opt/lk-platform/bin/lk-bash-load.sh || exit

shopt -s nullglob

cd ~/Code

DIR=~/.lk-platform/cache
[ -d "$DIR" ] || install -d "$DIR"
LISTFILE=$DIR/code-workspace.list
HISTFILE=$DIR/code-workspace.history

function generate_list() {
    printf '%s\n' */{,*/}*.code-workspace >"$LISTFILE"
}

COMMAND=(zenity)
! lk_is_macos || COMMAND=(bash -c "$(
    function run() {
        zenity "$@" &
        osascript -l JavaScript >/dev/null <<EOF
Application('System Events').processes.whose({unixId: $!})[0].frontmost = true
EOF
        wait
    }
    declare -f run
    echo 'run "$@"'
)" bash)

if [ -e "$LISTFILE" ]; then
    lk_mapfile LIST <"$LISTFILE"
    generate_list &
else
    generate_list
    lk_mapfile LIST <"$LISTFILE"
fi

IFS=$'\n'
OPEN=($(
    { IFS= && lk_arr LIST &&
        { [ ! -e "$HISTFILE" ] ||
            grep -Fxf <(lk_arr LIST) "$HISTFILE" | tail -n50 ||
            [[ ${PIPESTATUS[*]} == 10 ]]; }; } |
        sort | uniq -c | sort -k1,1nr -k2,2 | awk '{print $2}' |
        gnu_sed -E 'p; s/\.code-workspace$//; s/([^/]+)\/\1$/\1/' |
        tr '\n' '\0' |
        xargs -0r "${COMMAND[@]}" --list \
            --title "Open workspace" \
            --text "Select one or more workspaces:" \
            --hide-header --hide-column=1 \
            --column=Key --column=Name \
            --multiple --separator='\n' \
            --width=450 --height=550 |
        tee -a "$HISTFILE"
)) || OPEN=()

wait

[[ -z ${OPEN+1} ]] ||
    exec code "${OPEN[@]}"
