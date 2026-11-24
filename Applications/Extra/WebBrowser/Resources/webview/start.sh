#!/usr/bin/env bash
# Started by ChromeController.m with the application name as argument.
# Execs the Chrome DevTools Protocol bridge (cdpbridge.py), which launches
# Chromium, serves WebBrowser.app's document windows, and cleans up (lock,
# Chromium) when WebBrowser.app quits or goes away.

APPNAME="$1"
LOCK="/tmp/$UID-$APPNAME-controller.lock"

if [ -f "$LOCK" ];then
  # stale lock from a crashed session?
  if ! pgrep -f "cdpbridge.py $APPNAME" >/dev/null; then
    rm -f "$LOCK"
  else
    echo "lock $LOCK exists, exit"
    exit 1
  fi
fi
echo "" > "$LOCK"

exec python3 -I "$(dirname "$(realpath "$0")")/cdpbridge.py" "$APPNAME" "$LOCK"
