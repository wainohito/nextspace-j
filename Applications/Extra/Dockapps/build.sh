#!/bin/bash
# Window Maker dockapps for NEXTSPACE: /Applications/Dockapps/<name>.app
#
# 1. builds the dockapps in src/ (not in Debian) and installs them into
#    /usr/local/bin;
# 2. makes one .app per dockapps.list entry: Workspace shows them with an
#    icon, a double click starts the dockapp, and an .app dragged into the
#    Dock is attached to the running dockapp (the wrapper's executable is
#    named after the dockapp's WM_CLASS).  Autolaunch at login is set in
#    Workspace Preferences > Dock.
#
# The Debian dockapps (source "deb:" in dockapps.list) are installed by
# install.sh (deps stage); entries whose program is missing are skipped.
# Usage: ./build.sh            (asks for sudo when installing)
set -e
cd "$(dirname "$0")"
HERE=$(pwd)
DEST=/Applications/Dockapps
CC=gcc
BUILD=$(mktemp -d)
trap 'rm -rf "$BUILD"' EXIT

#---------------------------------------------------------------- 1. build
build() {  # name: build a copy of src/<name> in $BUILD, print the binary path
  local n=$1 b="$BUILD/src/$1"
  mkdir -p "$BUILD/src"
  cp -r "src/$n" "$b"
  (
    cd "$b"
    case $n in
      cputnik)   make CC=$CC ;;
      wmbluecpu) make CC=$CC ;;
      wmamixer)  $CC -O2 wmamixer.c -Wall -lm -lXpm -lXext -lX11 -lasound -o wmamixer ;;
      wmnetload) CPPFLAGS=-I/usr/include/libdockapp ./configure -q && make ;;
      wmwifi)    autoreconf -fi && ./configure -q && make ;;
    esac
  ) > "$BUILD/$n.log" 2>&1 || { tail -20 "$BUILD/$n.log"; echo "$n: build failed" >&2; exit 1; }
}

for n in $(awk -F'|' '!/^#/ && NF >= 4 && $4 ~ /src/ {gsub(/ /, "", $1); print $1}' dockapps.list); do
  echo "Building $n"
  build "$n"
  bin=$(find "$BUILD/src/$n" -type f -name "$n" -perm -u+x | head -1)
  [ -n "$bin" ] || { echo "$n: binary not found" >&2; exit 1; }
  sudo install -m 755 -s "$bin" "/usr/local/bin/$n"
done

#---------------------------------------------------------------- 2. .app
STAGE="$BUILD/Dockapps"
mkdir -p "$STAGE"
while IFS='|' read -r name cmd wmclass source desc; do
  name=$(echo $name)
  case "$name" in ''|'#'*) continue ;; esac
  cmd=$(echo $cmd); wmclass=$(echo $wmclass); desc=$(echo $desc)
  prog=${cmd%% *}
  if ! command -v "$prog" >/dev/null && [ ! -x "/usr/local/bin/$prog" ]; then
    echo "Skipping $name ($prog not installed)"
    continue
  fi
  app="$STAGE/$name.app"
  mkdir -p "$app/Resources"
  cat > "$app/$wmclass" <<EOF
#!/bin/sh
# $name.app: starts the $name dockapp.  This file is named after the
# dockapp's WM_CLASS ($wmclass), so that the Dock attaches the running
# dockapp to an icon dragged from /Applications/Dockapps.  Resources/dockapp
# names the program: nextspace-logout stops it at logout.
pgrep -u "\$(id -u)" -x "$(basename "$prog" | cut -c1-15)" >/dev/null && exit 0
log=\$HOME/.local/state/nextspace/dockapps.log
mkdir -p "\${log%/*}"
echo "\$(date '+%F %T') $cmd \$*" >> "\$log"
exec $cmd "\$@" 2>> "\$log"
EOF
  chmod 755 "$app/$wmclass"
  basename "$prog" > "$app/Resources/dockapp"
  cp "icons/$name.png" "$app/Resources/AppIcon.png"
  # ApplicationDescription: \U escapes keep the plist ASCII
  pdesc=$(printf '%s' "$desc" | python3 -c 'import sys; print("".join(c if ord(c) < 128 else "\\U%04X" % ord(c) for c in sys.stdin.read()))')
  cat > "$app/Resources/Info-gnustep.plist" <<EOF
{
  NSExecutable = "$wmclass";
  ApplicationName = "$name.app";
  ApplicationDescription = "$pdesc";
  ApplicationRelease = "Window Maker dockapp";
  NSIcon = "AppIcon.png";
  NSRole = None;
}
EOF
done < dockapps.list

echo "Installing $(ls "$STAGE" | wc -l) dockapps into $DEST"
sudo rm -rf "$DEST"
sudo mkdir -p "$DEST"
sudo cp -r "$STAGE"/. "$DEST"/
sudo chmod -R a+rX "$DEST"
