#!/bin/bash
#
# Build the NEXTSPACE-J .deb packages.
#
# Run on a Debian system where NEXTSPACE-J was installed with install.sh
# from the same commit (the build of each part uses the headers and libraries
# of the installed parts), as the normal user who ran install.sh:
#
#   Packaging/deb/build-debs.sh [output directory]   (default Packaging/deb/out)
#
# Packages (version: commit date + hash, ~debNN for the Debian release):
#   nextspace-j-core      libraries: libdispatch, CoreFoundation, libobjc2,
#                         gnustep-make, libwraster, libs-base/gui/back
#   nextspace-j           Frameworks and applications (Login, Workspace...)
#   nextspace-j-ja        Japanese environment: session scripts, first login
#                         settings, fcitx5, fonts, system settings
#   nextspace-j-extra     Applications/Extra and the browser wrappers
#   nextspace-j-dockapps  /Applications/Dockapps
#   nextspace-j-desktop   all of the above with Firefox and Chromium
set -e

HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/../.." && pwd)
SRC="$ROOT/Packaging/Sources"
EXTRA_DIR="$SRC/extra"
OUT=$(mkdir -p "${1:-$HERE/out}" && cd "${1:-$HERE/out}" && pwd)

. /etc/os-release
DEB=${VERSION_ID%%.*}
ARCH=$(dpkg --print-architecture)
VERSION=$(git -C "$ROOT" log -1 --format=%cd --date=format:%Y%m%d.%H%M)+g$(git -C "$ROOT" rev-parse --short=8 HEAD)~deb$DEB
MAINTAINER="NEXTSPACE-J <https://github.com/wainohito/nextspace-j>"
. "$SRC/debian-$DEB.deps.sh"

STAGE=$(mktemp -d /var/tmp/nextspace-j-stage.XXXXXX)
trap 'rm -rf "$STAGE"' EXIT

# Non-interactive runs can set SUDO_ASKPASS (also for the /bin/sh scripts)
if [ -n "$SUDO_ASKPASS" ]; then
  mkdir -p "$STAGE/.sudo"
  printf '#!/bin/sh\nexec /usr/bin/sudo -A "$@"\n' > "$STAGE/.sudo/sudo"
  chmod 755 "$STAGE/.sudo/sudo"
  export PATH="$STAGE/.sudo:$PATH"
fi

info() { printf '\n\033[1;33m==== %s\033[0m\n' "$*"; }
die()  { printf '\033[1;31m%s\033[0m\n' "$*" >&2; exit 1; }

# Comma separated, unique
deplist() { tr ' \n' '\n\n' | sed '/^$/d' | sort -u | paste -sd, | sed 's/,/, /g'; }

# Debian packages of the shared libraries the ELF files under $1 need (the
# libraries of our own packages are not dpkg-owned on the build system)
shlib_deps() {
  local f lib path pkg
  find "$1" -type f \( -perm -u+x -o -name '*.so*' \) -print0 |
    xargs -0 -r file -N -F '|' | grep -E '\| *ELF' | cut -d'|' -f1 |
    while read -r f; do objdump -p "$f" 2>/dev/null | awk '/NEEDED/{print $2}'; done |
    sort -u | while read -r lib; do
      path=$(ldconfig -p | awk -v l="$lib" '$1 == l {print $NF; exit}')
      [ -n "$path" ] || continue
      path=$(readlink -f "$path")
      pkg=$(dpkg -S "$path" 2>/dev/null || dpkg -S "${path#/usr}" 2>/dev/null || true)
      [ -n "$pkg" ] && echo "${pkg%%:*}" | cut -d, -f1
    done | sed 's/:.*//' | sort -u
}

# make_deb NAME "DEPENDS" "SHORT DESCRIPTION" "LONG DESCRIPTION"
# The tree is $STAGE/NAME; optional maintainer scripts in $STAGE/NAME.debian/
make_deb() {
  local name=$1 depends=$2 short=$3 long=$4 dir="$STAGE/$1" size
  mkdir -p "$dir/DEBIAN"
  if [ -d "$STAGE/$name.debian" ]; then
    cp "$STAGE/$name.debian"/* "$dir/DEBIAN/"
    chmod 755 "$dir"/DEBIAN/{preinst,postinst,prerm,postrm} 2>/dev/null || true
  fi
  if [ -d "$dir/etc" ]; then
    (cd "$dir" && find etc -type f | sed 's|^|/|') > "$dir/DEBIAN/conffiles"
  fi
  size=$(du -sk --exclude=DEBIAN "$dir" | cut -f1)
  cat > "$dir/DEBIAN/control" <<EOF
Package: $name
Version: $VERSION
Architecture: $ARCH
Maintainer: $MAINTAINER
Installed-Size: $size
Depends: $depends
Section: x11
Priority: optional
Homepage: https://github.com/wainohito/nextspace-j
Description: $short
$(echo "$long" | fold -s -w 72 | sed 's/^/ /')
EOF
  dpkg-deb --root-owner-group -Zxz --build "$dir" "$OUT/${name}_${VERSION}_${ARCH}.deb" >/dev/null
  echo "  $OUT/${name}_${VERSION}_${ARCH}.deb ($(du -h "$OUT/${name}_${VERSION}_${ARCH}.deb" | cut -f1))"
}

run_sources() {  # DEST script...
  local dest=$1; shift
  for s in "$@"; do
    info "Packaging/Sources/$s -> $(basename "$dest")"
    (cd "$SRC" && ./"$s" "$dest") || die "$s failed"
  done
}

#================================================================ core
info "nextspace-j-core"
P="$STAGE/nextspace-j-core"
run_sources "$P" 0_build_libdispatch.sh 1_build_libcorefoundation.sh 2_build_libobjc2.sh \
            3_build_core.sh 3_build_tools-make.sh 4_build_libwraster.sh \
            5_build_libs-base.sh 6_build_libs-gui.sh 7_build_libs-back.sh
install -D -m 644 "$EXTRA_DIR/apt-preferences-nextspace" "$P/etc/apt/preferences.d/nextspace"
mkdir -p "$STAGE/nextspace-j-core.debian"
cat > "$STAGE/nextspace-j-core.debian/postinst" <<'EOF'
#!/bin/sh
set -e
if [ "$1" = configure ]; then
  ldconfig
  for s in gdomap gdnc gdnc-local gpbs; do
    systemctl enable /usr/NextSpace/lib/systemd/$s.service >/dev/null 2>&1 || true
  done
  if [ -d /run/systemd/system ]; then
    systemctl daemon-reload || true
    systemctl restart gdomap gdnc gpbs >/dev/null 2>&1 || true
  fi
fi
EOF
cat > "$STAGE/nextspace-j-core.debian/prerm" <<'EOF'
#!/bin/sh
set -e
if [ "$1" = remove ]; then
  for s in gpbs gdnc-local gdnc gdomap; do
    [ -d /run/systemd/system ] && systemctl stop $s >/dev/null 2>&1 || true
    systemctl disable $s.service >/dev/null 2>&1 || true
  done
fi
EOF
cat > "$STAGE/nextspace-j-core.debian/postrm" <<'EOF'
#!/bin/sh
set -e
[ "$1" = remove ] && ldconfig || true
EOF

#================================================================ nextspace
info "nextspace-j"
P="$STAGE/nextspace-j"
run_sources "$P" 8_build_Frameworks.sh 9_build_Applications.sh
mkdir -p "$STAGE/nextspace-j.debian"
cat > "$STAGE/nextspace-j.debian/postinst" <<'EOF'
#!/bin/sh
set -e
if [ "$1" = configure ]; then
  ldconfig
  # The Login window is the display manager
  if [ -z "$2" ]; then
    systemctl disable display-manager.service >/dev/null 2>&1 || true
    systemctl enable /usr/NextSpace/lib/systemd/loginwindow.service >/dev/null 2>&1 || true
    systemctl set-default graphical.target >/dev/null 2>&1 || true
  fi
  [ -d /run/systemd/system ] && systemctl daemon-reload || true
fi
EOF
cat > "$STAGE/nextspace-j.debian/prerm" <<'EOF'
#!/bin/sh
set -e
if [ "$1" = remove ]; then
  systemctl disable loginwindow.service >/dev/null 2>&1 || true
  systemctl set-default multi-user.target >/dev/null 2>&1 || true
fi
EOF

#================================================================ ja
info "nextspace-j-ja"
P="$STAGE/nextspace-j-ja"
B="$P/usr/NextSpace/bin"
install -D -m 755 "$EXTRA_DIR/nextspace-autostart" "$B/nextspace-autostart"
install -D -m 755 "$EXTRA_DIR/nextspace-logout" "$B/nextspace-logout"
install -D -m 755 "$EXTRA_DIR/nextspace-user-setup" "$B/nextspace-user-setup"
install -D -m 755 "$EXTRA_DIR/wm-setup.py" "$B/nextspace-wm-setup"
install -D -m 755 "$EXTRA_DIR/nextspace-fonts" "$B/nextspace-fonts"
install -D -m 644 "$EXTRA_DIR/fcitx5-xim.conf" "$P/etc/xdg/fcitx5/conf/xim.conf"
install -D -m 644 "$EXTRA_DIR/apt-99nextspace-fonts" "$P/etc/apt/apt.conf.d/99nextspace-fonts"
# unattended-upgrades makes 20auto-upgrades itself: a later file wins
install -D -m 644 "$EXTRA_DIR/apt-20auto-upgrades" "$P/etc/apt/apt.conf.d/21nextspace-auto-upgrades"
install -D -m 440 "$EXTRA_DIR/nextspace-timezone.sudoers" "$P/etc/sudoers.d/nextspace-timezone"
for d in system user; do
  install -D -m 644 "$EXTRA_DIR/systemd-timeout.conf" "$P/etc/systemd/$d.conf.d/nextspace-timeout.conf"
done
mkdir -p "$STAGE/nextspace-j-ja.debian"
cat > "$STAGE/nextspace-j-ja.debian/postinst" <<'EOF'
#!/bin/sh
set -e
if [ "$1" = configure ]; then
  # fcitx5 for all applications
  for kv in XMODIFIERS=@im=fcitx GTK_IM_MODULE=fcitx QT_IM_MODULE=fcitx; do
    grep -q "^${kv%%=*}=" /etc/environment 2>/dev/null || echo "$kv" >> /etc/environment
  done
  # NEXTSPACE profile for root (Login.app runs as root)
  [ -d /etc/skel/Library ] && mkdir -p /root/Library && cp -Rn /etc/skel/Library/. /root/Library/ || true
  [ -d /etc/skel/.config ] && cp -Rn /etc/skel/.config /root/ || true
fi
EOF

#================================================================ extra
info "nextspace-j-extra"
P="$STAGE/nextspace-j-extra"
DESTDIR="$P" NO_DOCKAPPS=1 "$ROOT/Applications/Extra/build.sh"

#================================================================ dockapps
info "nextspace-j-dockapps"
P="$STAGE/nextspace-j-dockapps"
DESTDIR="$P" "$ROOT/Applications/Extra/Dockapps/build.sh"
DOCKAPP_PKGS=$(awk -F'|' '!/^#/ && $4 ~ /deb:/ {sub(/.*deb:/, "", $4); gsub(/ /, "", $4); print $4}' \
               "$ROOT/Applications/Extra/Dockapps/dockapps.list")

#================================================================ check
info "Files in more than one package?"
dups=$(for p in core "" ja extra dockapps; do
         n=nextspace-j${p:+-$p}
         (cd "$STAGE/$n" && find . ! -type d ! -path './DEBIAN/*')
       done | sort | uniq -d)
[ -z "$dups" ] || die "Files in more than one package:
$dups"
echo "none"

#================================================================ build
info "Packages ($VERSION, $ARCH)"
V="(= $VERSION)"
make_deb nextspace-j-core \
  "$( (shlib_deps "$STAGE/nextspace-j-core"; echo $RUNTIME_RUN_DEPS $WRASTER_RUN_DEPS \
      $GNUSTEP_BASE_RUN_DEPS $GNUSTEP_GUI_RUN_DEPS $BACK_ART_RUN_DEPS) | deplist)" \
  "NEXTSPACE-J core libraries" \
  "GNUstep libraries (libs-base, libs-gui with the Japanese localization and inline input, libs-back), libobjc2, libdispatch, CoreFoundation, libwraster and gnustep-make for NEXTSPACE-J, a Japanese fork of the NEXTSPACE desktop."
make_deb nextspace-j \
  "nextspace-j-core $V, nextspace-j-ja $V, $( (shlib_deps "$STAGE/nextspace-j"; echo $FRAMEWORKS_RUN_DEPS $APPS_RUN_DEPS) | deplist)" \
  "NEXTSPACE-J desktop: frameworks and applications" \
  "Login window, Workspace (file viewer, Dock and window manager), Preferences, Terminal, TextEdit and the other NEXTSPACE applications, with Japanese localization."
make_deb nextspace-j-ja \
  "nextspace-j-core $V, python3, unattended-upgrades, $(echo $JAPANESE_DEPS $TRAY_DEPS | deplist)" \
  "NEXTSPACE-J Japanese environment" \
  "Session scripts and the first login settings of NEXTSPACE-J: Japanese UI and fonts, fcitx5 + Mozc inline input, input mode and volume in the Dock, fontconfig fonts for NEXTSPACE, time zone changes from Preferences, automatic security updates."
make_deb nextspace-j-extra \
  "nextspace-j $V, $( (shlib_deps "$STAGE/nextspace-j-extra"; echo $EXTRA_APPS_RUN_DEPS) | deplist)" \
  "NEXTSPACE-J extra applications" \
  "Applications ported from GNUstep Desktop (gs-desktop) with Japanese localization, WebBrowser, and the Firefox.app and Chromium.app wrappers."
make_deb nextspace-j-dockapps \
  "nextspace-j $V, $( (shlib_deps "$STAGE/nextspace-j-dockapps"; echo $DOCKAPP_PKGS) | deplist)" \
  "NEXTSPACE-J dockapps" \
  "Window Maker dockapps as /Applications/Dockapps/*.app for the NEXTSPACE Dock."
mkdir -p "$STAGE/nextspace-j-desktop"
make_deb nextspace-j-desktop \
  "nextspace-j $V, nextspace-j-ja $V, nextspace-j-extra $V, nextspace-j-dockapps $V, firefox-esr, chromium" \
  "NEXTSPACE-J desktop (all packages)" \
  "Installs the whole NEXTSPACE-J desktop: NEXTSPACE with Japanese localization and input, extra applications, dockapps, Firefox and Chromium."
info "Done: $OUT"
