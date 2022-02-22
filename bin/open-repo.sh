#!/bin/bash

. /opt/lk-platform/bin/lk-bash-load.sh || exit

shopt -s nullglob

cd ~/Code

DIR=~/.lk-platform/cache
[ -d "$DIR" ] || install -d "$DIR"
LIST_FILE=$DIR/git-repo.list
HIST_FILE=$DIR/git-repo.history

function generate_list() {
    find -H ./* -maxdepth 3 \
        -type d -exec test -d "{}/.git" \; -print -prune |
        sed -E 's/^\.\///; /^vendor\//d' | sort >"$LIST_FILE"
}

COMMAND=(zenity)
! lk_is_macos || COMMAND=(bash -c "$(
    function run() {
        zenity "$@" &
        "$LK_BASE/lib/macos/process-focus.js" $!
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

(($#)) || set -- smerge

IFS=$'\n'
OPEN=($(
    { IFS= && lk_arr LIST &&
        { [ ! -e "$HIST_FILE" ] ||
            grep -Fxf <(lk_arr LIST) "$HIST_FILE" | tail -n50 ||
            [[ ${PIPESTATUS[*]} == 10 ]]; }; } |
        sort | uniq -c | sort -k1,1nr -k2,2 |
        awk '{ printf("%s\0%s\0", $2, $2); }' |
        { IFS=' ' && xargs -0r "${COMMAND[@]}" --list \
            --title "Open repository with $*" \
            --text "Select one or more repositories:" \
            --hide-header --hide-column=1 \
            --column=Key --column=Name \
            --multiple --separator='\n' \
            --width=450 --height=550; } |
        tee -a "$HIST_FILE"
)) || OPEN=()

wait

[[ -n ${OPEN+1} ]] || exit 0

unset IFS
for ((i = 1; i <= $#; i++)); do
    if [[ ${!i} == "{}" ]]; then
        for FILE in "${OPEN[@]}"; do
            nohup "${@:1:i-1}" "$FILE" "${@:i+1}" &>/dev/null &
            disown
        done
        exit
    fi
done

exec "$@" "${OPEN[@]}"
