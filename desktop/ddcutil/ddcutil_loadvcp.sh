#!/bin/bash

set -euo pipefail

shopt -s nullglob

[ $# -gt 0 ] || set -- "$(dirname "$0")"/*.ddc

while [ $# -gt 0 ]; do
    echo "Loading $1..." >&2
    sudo ddcutil loadvcp "$1"
    shift
done
