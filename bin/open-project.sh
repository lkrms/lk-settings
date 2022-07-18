#!/bin/bash

. /opt/lk-platform/bin/lk-bash-load.sh || exit

shopt -s nullglob

cd ~/Code

DIR=~/.lk-platform/cache
[ -d "$DIR" ] || install -d "$DIR"
LIST_FILE=$DIR/code-workspace.list
HIST_FILE=$DIR/code-workspace.history

function generate_list() {
    printf '%s\n' {,*/,*/*/,*/*/*/,*/*/*/*/}*.code-workspace >"$LIST_FILE"
}

COMMAND=(zenity)
! lk_is_macos || COMMAND=(bash -c "$(
    function run() {
        zenity "$@" &
        sleep 0.2
        "$LK_BASE/lib/macos/process-focus.js" $! >>"/tmp/open-project.log" 2>&1
        wait
    }
    declare -f run
    echo 'run "$@"'
)" bash)

if [ -e "$LIST_FILE" ]; then
    lk_mapfile LIST <"$LIST_FILE"
    generate_list &
else
    generate_list
    lk_mapfile LIST <"$LIST_FILE"
fi

IFS=$'\n'
OPEN=($(
    { IFS= && lk_arr LIST &&
        { [ ! -e "$HIST_FILE" ] ||
            grep -Fxf <(lk_arr LIST) "$HIST_FILE" | tail -n24 ||
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
        tee -a "$HIST_FILE"
)) || OPEN=()

wait

[[ -z ${OPEN+1} ]] ||
    exec code "${OPEN[@]}"
