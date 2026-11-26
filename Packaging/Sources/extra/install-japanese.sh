#!/bin/bash
#
# NEXTSPACE (japanese branch): one-step build & install for Debian.
# Called by Packaging/Debian13/install.sh (trixie, amd64) and
# Packaging/Debian12_x86/install.sh (bookworm, i386) with NS_DEBIAN set to
# the Debian major version; the package list is Packaging/Sources/debian-$NS_DEBIAN.deps.sh.
#
# Runs, in order, the stages below.  Each stage calls the existing scripts in
# Packaging/Sources (which stay the reference for building each component).
#
#   deps      apt pin for Debian's GNUstep + all build/runtime packages
#   core      libdispatch, CoreFoundation, libobjc2, gnustep-make, libwraster,
#             libs-base, libs-gui (+ Japanese strings, inline input patch),
#             libs-back                        (Packaging/Sources/0..7_*.sh)
#   nextspace Frameworks and applications (Login, Workspace, Preferences...)
#                                              (Packaging/Sources/8, 9_*.sh)
#   extra     Applications/Extra: gs-desktop apps, WebBrowser, browser wrappers
#   system    root profile (setup_user_home.sh as root), sudoers rule for
#             time zone changes, input method environment
#   user      home directory for the user running this script: NEXTSPACE
#             profile, Japanese UI and fonts, inline input, fcitx5 XIM,
#             tray (wmsystemtray/pasystray) autostart
#
# Usage:  ./install.sh                 run all stages
#         ./install.sh extra user      run only the given stages
#         ./install.sh --from extra    run from a stage to the end
#         ./install.sh --list          list stages
# Run as the normal user who will use NEXTSPACE (sudo is used when needed).

set -e

STAGES="deps core nextspace extra system user"
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd "$HERE/../../.." && pwd)
SRC="$ROOT/Packaging/Sources"
EXTRA_DIR="$ROOT/Packaging/Sources/extra"

# Non-interactive runs can set SUDO_ASKPASS: every sudo (also in the /bin/sh
# component scripts, which do not see bash functions) then uses "sudo -A"
# through a wrapper put first in PATH.
if [ -n "$SUDO_ASKPASS" ]; then
  SUDO_WRAP=$(mktemp -d)
  printf '#!/bin/sh\nexec /usr/bin/sudo -A "$@"\n' > "$SUDO_WRAP/sudo"
  chmod 755 "$SUDO_WRAP/sudo"
  export PATH="$SUDO_WRAP:$PATH"
  trap 'rm -rf "$SUDO_WRAP"' EXIT
fi

info() { printf '\n\033[1;33m==== %s\033[0m\n' "$*"; }
die()  { printf '\033[1;31m%s\033[0m\n' "$*" >&2; exit 1; }

[ "$(id -u)" != 0 ] || die "Run this script as a normal user, not as root (it uses sudo)."
. /etc/os-release
[ -n "$NS_DEBIAN" ] || die "Run Packaging/Debian13/install.sh or Packaging/Debian12_x86/install.sh."
[ "$ID" = debian ] && [ "${VERSION_ID%%.*}" = "$NS_DEBIAN" ] || die "This script is for Debian $NS_DEBIAN (found $PRETTY_NAME)."
if [ -n "$NS_ARCH" ] && [ "$(dpkg --print-architecture)" != "$NS_ARCH" ]; then
  die "This script is for $NS_ARCH (found $(dpkg --print-architecture))."
fi

# Keep a log of everything (appended, so re-runs and --from resumes stay in
# one file).  sudo asks for the password on the terminal, not through the log.
LOG="$HOME/nextspace-install.log"
exec > >(tee -a "$LOG") 2>&1
echo "==== $(date '+%F %T') install.sh (Debian $NS_DEBIAN) $*  (log: $LOG)"

#---------------------------------------------------------------- stages
stage_deps() {
  info "Keep Debian's GNUstep packages away (apt pin)"
  sudo install -m 644 "$EXTRA_DIR/apt-preferences-nextspace" /etc/apt/preferences.d/nextspace

  info "Install build and runtime packages"
  . "$SRC/debian-$NS_DEBIAN.deps.sh"
  sudo apt-get update
  # shellcheck disable=SC2086
  sudo apt-get install -y $BUILD_TOOLS $RUNTIME_DEPS $GNUSTEP_MAKE_DEPS $RUNTIME_RUN_DEPS \
       $WRASTER_DEPS $WRASTER_RUN_DEPS $GNUSTEP_BASE_DEPS $GNUSTEP_BASE_RUN_DEPS \
       $GNUSTEP_GUI_DEPS $GNUSTEP_GUI_RUN_DEPS $BACK_ART_DEPS $BACK_ART_RUN_DEPS \
       $FRAMEWORKS_BUILD_DEPS $FRAMEWORKS_RUN_DEPS $APPS_BUILD_DEPS $APPS_RUN_DEPS \
       $JAPANESE_DEPS $TRAY_DEPS $EXTRA_APPS_BUILD_DEPS $EXTRA_APPS_RUN_DEPS

  info "Window Maker dockapps (Applications/Extra/Dockapps/dockapps.list)"
  # shellcheck disable=SC2046
  sudo apt-get install -y $DOCKAPPS_BUILD_DEPS $(awk -F'|' '!/^#/ && $4 ~ /deb:/ \
       {sub(/.*deb:/, "", $4); gsub(/ /, "", $4); print $4}' "$ROOT/Applications/Extra/Dockapps/dockapps.list")

  info "Install security updates (Firefox, Chromium, ...) automatically"
  sudo apt-get install -y unattended-upgrades
  sudo install -m 644 "$EXTRA_DIR/apt-20auto-upgrades" /etc/apt/apt.conf.d/20auto-upgrades
}

run_sources() {
  # The component scripts expect to be run from Packaging/Sources.
  for s in "$@"; do
    info "Packaging/Sources/$s"
    (cd "$SRC" && ./"$s") || die "$s failed"
  done
}

stage_core() {
  run_sources 0_build_libdispatch.sh 1_build_libcorefoundation.sh 2_build_libobjc2.sh \
              3_build_core.sh 3_build_tools-make.sh 4_build_libwraster.sh \
              5_build_libs-base.sh 6_build_libs-gui.sh 7_build_libs-back.sh
}

stage_nextspace() {
  run_sources 8_build_Frameworks.sh 9_build_Applications.sh
}

stage_extra() {
  info "Applications/Extra"
  "$ROOT/Applications/Extra/build.sh"
}

stage_system() {
  info "NEXTSPACE profile for root (Login.app runs as root)"
  (cd "$SRC" && sudo -H ./setup_user_home.sh)

  info "Time zone changes from Preferences without a password (sudo group)"
  sudo install -m 440 -o root -g root "$EXTRA_DIR/nextspace-timezone.sudoers" \
       /etc/sudoers.d/nextspace-timezone
  sudo visudo -c -f /etc/sudoers.d/nextspace-timezone

  info "systemd: stop timeout 15 s (shutdown no longer waits 1 min 30 s)"
  for d in system user; do
    sudo install -D -m 644 "$EXTRA_DIR/systemd-timeout.conf" \
         /etc/systemd/$d.conf.d/nextspace-timeout.conf
  done
  sudo systemctl daemon-reexec

  info "Fonts: nextspace-fonts makes fontconfig's fonts usable in NEXTSPACE"
  sudo install -m 755 "$EXTRA_DIR/nextspace-fonts" /usr/local/bin/nextspace-fonts
  sudo install -m 644 "$EXTRA_DIR/apt-99nextspace-fonts" /etc/apt/apt.conf.d/99nextspace-fonts

  info "fcitx5 for all applications (/etc/environment)"
  for kv in XMODIFIERS=@im=fcitx GTK_IM_MODULE=fcitx QT_IM_MODULE=fcitx; do
    grep -q "^${kv%%=*}=" /etc/environment 2>/dev/null || echo "$kv" | sudo tee -a /etc/environment >/dev/null
  done
  sudo ldconfig
}

stage_user() {
  info "NEXTSPACE profile in $HOME"
  (cd "$SRC" && ./setup_user_home.sh)

  info "Japanese UI, fonts and inline (on-the-spot) input"
  local d=/Library/bin/defaults
  [ -x "$d" ] || d=defaults
  . /etc/profile.d/nextspace.sh 2>/dev/null || true
  $d write NSGlobalDomain NSLanguages '(Japanese, English)'
  $d write NSGlobalDomain GSXIMInputMethodStyle OnTheSpot
  for k in NSFont NSUserFont NSMenuFont NSMessageFont NSControlContentFont NSLabelFont NSToolTipsFont; do
    $d write NSGlobalDomain $k NotoSansCJKjp-Regular
  done
  for k in NSBoldFont NSTitleBarFont NSMenuBarFont NSPaletteFont; do
    $d write NSGlobalDomain $k NotoSansCJKjp-Bold
  done
  $d write NSGlobalDomain NSUserFixedPitchFont NotoSansMonoCJKjp-Regular
  $d write NSGlobalDomain GSFontAntiAlias YES   # smooth (anti-aliased) text
  for k in NSFontSize NSBoldFontSize NSUserFontSize NSUserFixedPitchFontSize NSMenuFontSize \
           NSMenuBarFontSize NSTitleBarFontSize NSPaletteFontSize NSControlContentFontSize \
           NSLabelFontSize; do
    $d write NSGlobalDomain $k 12
  done
  $d write NSGlobalDomain NSMessageFontSize 14
  $d write NSGlobalDomain NSToolTipsFontSize 11
  $d write NSGlobalDomain NSSmallFontSize 10
  $d write NSGlobalDomain NSMiniFontSize 9
  # Terminal: VL Gothic (a real monospaced Japanese font; full-width
  # characters are exactly two cells wide)
  $d write Terminal TerminalFont VL-Gothic-Regular
  $d write Terminal TerminalFontSize 14

  info "Window manager: Japanese fonts, browsers and tray in the Dock, window attributes"
  mkdir -p "$HOME/.local/bin" "$HOME/.local/state/nextspace"
  install -m 755 "$EXTRA_DIR/wm-setup.py" "$HOME/.local/bin/nextspace-wm-setup"
  if pgrep -u "$(id -u)" -x Workspace >/dev/null; then
    # The WM would overwrite its state at logout: apply at the next login
    # (nextspace-autostart, before Workspace starts).
    touch "$HOME/.local/state/nextspace/wm-setup-pending"
    echo "NEXTSPACE is running: window manager settings will be applied at the next login."
  else
    "$HOME/.local/bin/nextspace-wm-setup"
  fi

  info "Fonts installed on the system (fontconfig) -> ~/Library/Fonts"
  /usr/local/bin/nextspace-fonts -v || true

  info "fcitx5: XIM on-the-spot style"
  mkdir -p "$HOME/.config/fcitx5/conf"
  cp "$EXTRA_DIR/fcitx5-xim.conf" "$HOME/.config/fcitx5/conf/xim.conf"

  info "Session: fcitx5, tray icons (wmsystemtray, pasystray)"
  mkdir -p "$HOME/.local/bin"
  install -m 755 "$EXTRA_DIR/nextspace-autostart" "$HOME/.local/bin/nextspace-autostart"
  install -m 755 "$EXTRA_DIR/nextspace-logout" "$HOME/.local/bin/nextspace-logout"
  local login="$HOME/Library/Preferences/.NextSpace/Login"
  mkdir -p "$(dirname "$login")"
  [ -f "$login" ] && cp -p "$login" "$login.before-install"
  cat > "$login" <<EOF
{
  LoginHook = "";
  SessionScript = (
    ("/usr/NextSpace/bin/gnustep-services", "start"),
    ("/usr/bin/fcitx5", "-d"),
    ("$HOME/.local/bin/nextspace-autostart"),
    ("/usr/NextSpace/Apps/Workspace.app/Workspace"),
    ("/usr/NextSpace/bin/gnustep-services", "stop")
  );
  LogoutHook = "$HOME/.local/bin/nextspace-logout";
}
EOF
  echo "Done. Log in to NEXTSPACE (or log out and in again) to use it."
}

#---------------------------------------------------------------- main
run=""
case "$1" in
  --list) echo "$STAGES"; exit 0 ;;
  --from)
    [ -n "$2" ] || die "--from needs a stage"
    on=""; for s in $STAGES; do [ "$s" = "$2" ] && on=1; [ -n "$on" ] && run="$run $s"; done
    [ -n "$run" ] || die "unknown stage: $2" ;;
  "") run="$STAGES" ;;
  *) for s in "$@"; do case " $STAGES " in *" $s "*) run="$run $s" ;; *) die "unknown stage: $s" ;; esac; done ;;
esac

echo "Stages to run:$run"
for s in $run; do "stage_$s"; done
info "All done:$run"
echo "Log of this installation: $LOG"
echo "You can delete it after logging in to NEXTSPACE successfully:  rm $LOG"
