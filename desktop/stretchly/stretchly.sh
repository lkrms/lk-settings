#!/bin/bash

exec >>"/tmp/${0##*/}.out" 2>&1

echo
echo "==== $(date)"

for COMMAND in stretchly \
    /Applications/Stretchly.app/Contents/MacOS/Stretchly; do
    type -P "$COMMAND" >/dev/null && break
    COMMAND=
done

[ -n "$COMMAND" ] || {
    echo "$0: command not found: stretchly" >&2
    exit 1
}

REGEX="/electron[0-9]*[[:blank:]].*/[sS]tretchly\>"
{ pgrep -x "[sS]tretchly" || pgrep -f "$REGEX"; } >/dev/null || exit 0

function minutes() {
    echo "$((($1 / 100) * 60 + $1 % 100))"
}

if ((!$#)); then
    NOW=$(minutes "$(date +%k%M)")
    NEXT=0
    LAST=$(minutes 900)
    for START in 1000 1115 1215 1350 1505 1605 1700; do
        START=$(minutes "$START")
        if ((NOW < (START - 5) && NOW >= LAST)); then
            ((NEXT = START - 5))
            break
        fi
        LAST=$START
    done
    if ((NEXT)); then
        set -- long --wait "$((NEXT - NOW))"
    else
        echo "$0: nothing to do" >&2
        exit
    fi
fi

echo "Running: $COMMAND $*" >&2
"$COMMAND" "$@"
