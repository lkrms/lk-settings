#!/bin/bash

s=/
FILE=/tmp/${0//"$s"/__}-$EUID
exec >>"$FILE.out" 2>>"$FILE.err"

{
    printf '\n\n==> '
    date
} | tee /dev/stderr

echo "Arguments ($#):"
((!$#)) || printf -- '- %s\n' "$@"

echo
echo "Environment:"
printenv
