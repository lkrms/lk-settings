#!/bin/bash

. "${LK_BASE:-/opt/lk-platform}"/bin/lk-bash-load.sh 2>/dev/null ||
    . ~/Code/lk/lk-platform/bin/lk-bash-load.sh || exit

shopt -s extglob nullglob

cd ~

OLD_DIR=~/.lk-platform/cache
DIR=~/.cache/lk-platform
[[ ! -d $OLD_DIR ]] ||
    if [[ -d $DIR ]]; then
        MOVE=("$OLD_DIR"/git-repo.*)
        if [[ -n ${MOVE+1} ]]; then
            mv -nv "${MOVE[@]}" "$DIR/"
            rm -f "${MOVE[@]}"
        fi
    else
        install -d "${DIR%/*}"
        gnu_mv -T "$OLD_DIR" "$DIR"
    fi
[ -d "$DIR" ] || install -d "$DIR"
LIST_FILE=$DIR/git-repo.list
HIST_FILE=$DIR/git-repo.history
HIST_FILE2=$DIR/code-workspace.history

function generate_list() {
    find -H ./Code/* ./.dotfiles!(?) -maxdepth 3 \
        -type d -exec test -d "{}/.git" \; -print -prune |
        sed -E 's/^\.\///; /^vendor\//d' | sort >"$LIST_FILE"
}

COMMAND=(yad)
! lk_is_macos || COMMAND=(bash -c "$(
    function run() {
        zenity "$@" &
        sleep 0.2
        "$LK_BASE/lib/macos/process-focus.js" $! >>"/tmp/open-repo.log" 2>&1
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

(($#)) || set -- smerge '{}'

IFS=$'\n'
OPEN=($(
    { IFS= && lk_arr LIST &&
        { [ ! -e "$HIST_FILE" ] ||
            grep -Fxf <(lk_arr LIST) "$HIST_FILE" | tail -n24 ||
            [ "${PIPESTATUS[*]}" = 10 ]; } &&
        { [ ! -e "$HIST_FILE2" ] ||
            grep -Eof <(sed 's/^/^/' "$LIST_FILE") "$HIST_FILE2" | tail -n24 ||
            [ "${PIPESTATUS[*]}" = 10 ]; }; } |
        tac | lk_uniq | awk '{print $1; sub(/^Code\//, "", $1); print $1}' |
        tr '\n' '\0' |
        { IFS=' ' && xargs -0r "${COMMAND[@]}" \
            --list \
            --separator='\n' \
            --multiple \
            --column=FILE \
            --column=Repository \
            --print-column=1 \
            --hide-column=1 \
            --title "Open repository with $*" \
            --text "Select one or more repositories:" \
            --width=450 \
            --height=550; } |
        tr -s '\n' |
        tee -a "$HIST_FILE"
)) || OPEN=()

wait

[[ -n ${OPEN+1} ]] || exit 0

unset IFS
COUNT=0
for ((i = 1; i <= $#; i++)); do
    if [[ ${!i} == "{}" ]]; then
        for FILE in "${OPEN[@]}"; do
            ((!COUNT++)) || sleep 0.2
            nohup "${@:1:i-1}" "$FILE" "${@:i+1}" &>/dev/null &
            disown
        done
        exit
    fi
done

exec "$@" "${OPEN[@]}"
