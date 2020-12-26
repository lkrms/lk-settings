#!/bin/sh

S="[[:blank:]]"
NS="[^[:blank:]]"

! pgrep -fx "$NS+/electron$S+$NS*Stretchly$NS*/app.asar" ||
    stretchly "$@"
