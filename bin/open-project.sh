#!/bin/bash

. "${LK_BASE:-/opt/lk-platform}"/bin/lk-bash-load.sh 2>/dev/null ||
    . ~/Code/lk/lk-platform/bin/lk-bash-load.sh || exit

shopt -s nullglob

cd ~

OLD_DIR=~/.lk-platform/cache
DIR=~/.cache/lk-platform
[[ ! -d $OLD_DIR ]] ||
    if [[ -d $DIR ]]; then
        MOVE=("$OLD_DIR"/code-workspace.*)
        if [[ -n ${MOVE+1} ]]; then
            mv -nv "${MOVE[@]}" "$DIR/"
            rm -f "${MOVE[@]}"
        fi
    else
        install -d "${DIR%/*}"
        gnu_mv -T "$OLD_DIR" "$DIR"
    fi
[ -d "$DIR" ] || install -d "$DIR"
LIST_FILE=$DIR/code-workspace.list
HIST_FILE=$DIR/code-workspace.history

function generate_list() {
    printf '%s\n' {Code,.dotfiles}/{,*/,*/*/,*/*/*/,*/*/*/*/}*.code-workspace >"$LIST_FILE"
}

COMMAND=(yad)
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

(($#)) || set -- code

IFS=$'\n'
OPEN=($(
    { IFS= && lk_arr LIST &&
        { [ ! -e "$HIST_FILE" ] ||
            grep -Fxf <(lk_arr LIST) "$HIST_FILE" | tail -n24 ||
            [ "${PIPESTATUS[*]}" = 10 ]; }; } |
        #sort | uniq -c | sort -k1,1nr -k2,2 | awk '{print $2}' |
        tac | lk_uniq |
        gnu_sed -E 'p; s/(^Code\/|\.code-workspace$)//g; s/([^/]+)\/\1$/\1/' |
        tr '\n' '\0' |
        xargs -0r "${COMMAND[@]}" \
            --list \
            --separator='\n' \
            --multiple \
            --column=FILE \
            --column=Workspace \
            --print-column=1 \
            --hide-column=1 \
            --title "Open workspace" \
            --text "Select one or more workspaces:" \
            --width=450 \
            --height=550 |
        tr -s '\n' |
        tee -a "$HIST_FILE"
)) || OPEN=()

wait

[[ -n ${OPEN+1} ]] || exit 0

FILES=()
for FILE in "${OPEN[@]}"; do
    FILES[${#FILES[@]}]=$(lk_realpath "$FILE")
done

unset IFS
COUNT=0
for ((i = 1; i <= $#; i++)); do
    if [[ ${!i} == "{}" ]]; then
        for FILE in "${FILES[@]}"; do
            ((!COUNT++)) || sleep 0.2
            nohup "${@:1:i-1}" "$FILE" "${@:i+1}" &>/dev/null &
            disown
        done
        exit
    fi
done

exec "$@" "${FILES[@]}"
