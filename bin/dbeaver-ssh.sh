#!/bin/bash

# Usage in "Before Connect":
#
#     dbeaver-ssh.sh SSH_HOST ${port} ${url} [HOST_PORT]
#
# In "After Disconnect":
#
#     dbeaver-ssh.sh -d SSH_HOST ${port} ${url} [HOST_PORT]
#
# - Arguments must be identical in both locations (aside from the -d flag)
# - Set the connection's "Server Host" and "Port" to "localhost" and a unique
#   port number respectively
# - The default remote listening port (HOST_PORT) is based on the driver given
#   in the connection URL

set -euo pipefail

exec 2>&1

CONNECT=1
[[ ${1-} != -d ]] || { CONNECT=0 && shift; }

(($# >= 3)) || exit

HOST=$1
PORT=$2
URL=$3
HOST_PORT=${4-}

[[ -n $HOST_PORT ]] ||
    case "$URL" in
    *:mysql:* | *:mariadb:*)
        HOST_PORT=3306
        ;;
    *)
        echo "Driver not recognised: $URL"
        exit 1
        ;;
    esac

COMMAND=(
    ssh
    -L "$PORT:localhost:$HOST_PORT"
    -fN
    -o ExitOnForwardFailure=yes
    -o ControlPath=none
    "$HOST"
)

if ((CONNECT)); then
    PID=$(pgrep -f "${COMMAND[*]}") &&
        echo "SSH is already running (PID $PID)" || {
        echo "Starting SSH in the background"
        "${COMMAND[@]}"
    }
else
    echo "Stopping background SSH"
    pkill -f "${COMMAND[*]}" ||
        echo "Background SSH has already been stopped"
fi
