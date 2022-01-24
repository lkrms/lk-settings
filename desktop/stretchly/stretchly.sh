#!/bin/sh

exec >>"/tmp/${0##*/}.stdout"
exec 2>>"/tmp/${0##*/}.stderr"

echo
echo "==== $(date)"

for COMMAND in stretchly \
    /Applications/Stretchly.app/Contents/MacOS/Stretchly; do
    type "$COMMAND" >/dev/null 2>&1 && break
    COMMAND=
done

[ -n "$COMMAND" ] || {
    echo "$0: command not found: stretchly" >&2
    exit 1
}

S="[[:blank:]]"
{ ! pgrep -x "[sS]tretchly" &&
    ! pgrep -f "/electron[0-9]*$S.*/[sS]tretchly/resources/app.asar"; } \
    >/dev/null || "$COMMAND" "$@"
