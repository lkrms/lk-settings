#!/usr/bin/env bash

# Usage: open-repo.sh [COMMAND [ARG...]]
#
# If one of the arguments to COMMAND is "{}", the command is executed once per
# selected repo after "{}" is replaced with its path.
#
# Otherwise, paths to the selected repos are added after the last ARG, and the
# command is only executed once.
#
# Default command:
#
#     smerge "{}"

. "${LK_BASE-/opt/lk-platform}"/bin/lk-bash-load.sh 2>/dev/null ||
    . ~/Code/lk/lk-platform/bin/lk-bash-load.sh || exit

shopt -s extglob nullglob

cd ~

DIR=~/.cache/lk-platform
[[ -d $DIR ]] || install -d "$DIR"
LIST_FILE=$DIR/git-repo.list
HIST_FILE=$DIR/git-repo.history
HIST_FILE2=$DIR/code-workspace.history

function generate_list() {
    find -H ./Code/* ./.dotfiles!(?) -maxdepth 4 -type d -name .git -prune -print0 |
        xargs -0r dirname |
        sort >"$LIST_FILE"
}

COMMAND=(yad)
! lk_is_macos || COMMAND=(bash -c "$(
    function run() {
        zenity "$@" &
        sleep 0.2
        "$LK_BASE/lib/macos/process-focus.js" $! >>"/tmp/${0##*/}.log" 2>&1
        wait
    }
    declare -f run
    echo 'run "$@"'
)" bash)

if [[ -e $LIST_FILE ]]; then
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
        { [[ ! -e $HIST_FILE ]] ||
            grep -Fxf <(lk_arr LIST) "$HIST_FILE" | tail -n24 ||
            test "${PIPESTATUS[*]}" = 10; } &&
        { [[ ! -e $HIST_FILE2 ]] ||
            grep -Fof <(lk_arr LIST) "$HIST_FILE2" | tail -n24 ||
            test "${PIPESTATUS[*]}" = 10; }; } |
        tac | lk_uniq |
        awk -v ORS='\0' '{ print; sub(/^Code\//, ""); print }' |
        xargs -0r "${COMMAND[@]}" \
            --list \
            --separator='\n' \
            --multiple \
            --column=FILE \
            --column=Repository \
            --print-column=1 \
            --hide-column=1 \
            --title "Open repo" \
            --text "Select one or more repositories:" \
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
