#!/bin/bash
#
# NEXTSPACE-J installer ISO (Debian installer + NEXTSPACE-J), built with
# simple-cdd from the Debian mirror and the NEXTSPACE-J packages:
#
#   Packaging/iso/build-iso.sh bookworm|trixie DEB_DIR [OUTPUT_DIR]
#
#   bookworm -> i386  (Debian 12; Debian 13 has no i386 installer)
#   trixie   -> amd64 (Debian 13)
#
# DEB_DIR holds the nextspace-j*.deb of that Debian release and architecture
# (Packaging/deb/build-debs.sh).  Needs: sudo apt install simple-cdd
# Work files go to $ISO_WORK (default ~/nextspace-iso-work/DIST); a few GB.
#
# The installer is Japanese (language, keyboard, time zone are preset) and
# installs NEXTSPACE-J instead of a Debian desktop; it asks for the network,
# host name, accounts and disks as usual.
set -e

DIST=$1
DEBS=$2
HERE=$(cd "$(dirname "$0")" && pwd)
case "$DIST" in
  bookworm) ARCH=i386;  DEBVER=12 ;;
  trixie)   ARCH=amd64; DEBVER=13 ;;
  *) echo "usage: $0 bookworm|trixie DEB_DIR [OUTPUT_DIR]" >&2; exit 1 ;;
esac
[ -d "$DEBS" ] || { echo "no directory: $DEBS" >&2; exit 1; }
DEBS=$(cd "$DEBS" && pwd)
OUT=$(mkdir -p "${3:-$HERE/out}" && cd "${3:-$HERE/out}" && pwd)
WORK=${ISO_WORK:-$HOME/nextspace-iso-work}/$DIST
command -v build-simple-cdd >/dev/null || { echo "simple-cdd is not installed" >&2; exit 1; }

# The packages of this release only (version ~debNN, architecture)
mkdir -p "$WORK/local"
rm -f "$WORK/local"/*.deb
n=0
for deb in "$DEBS"/nextspace-j*_*~deb${DEBVER}_${ARCH}.deb; do
  [ -e "$deb" ] || continue
  cp "$deb" "$WORK/local/"; n=$((n + 1))
done
[ $n -gt 0 ] || { echo "no nextspace-j*~deb${DEBVER}_${ARCH}.deb in $DEBS" >&2; exit 1; }
VERSION=$(dpkg-deb -f "$(ls "$WORK"/local/nextspace-j-desktop_*.deb)" Version)

# Installer images (dists/DIST/main/installer-ARCH/current/images), verified
# against Debian's signed Release file.  simple-cdd would also fetch the i386
# images for an amd64 build (an old debian-cd need), which Debian 13 no longer
# has: give it the installer ourselves (custom_installer).
get_installer() {
  local base="http://deb.debian.org/debian/dists/$DIST" di="$WORK/installer"
  local rel="main/installer-$ARCH/current/images"
  local d="$di/installer-$ARCH/current/images"
  rm -rf "$di"; mkdir -p "$d"
  wget -q -O "$di/Release" "$base/Release"
  wget -q -O "$di/Release.gpg" "$base/Release.gpg"
  gpgv --keyring /usr/share/keyrings/debian-archive-keyring.gpg \
       "$di/Release.gpg" "$di/Release" 2>/dev/null || { echo "Release: bad signature" >&2; exit 1; }
  wget -q -O "$d/SHA256SUMS" "$base/$rel/SHA256SUMS"
  local want
  want=$(awk -v f="$rel/SHA256SUMS" '/^SHA256:/{s=1; next} /^[A-Za-z]/{s=0} s && $3 == f {print $1}' "$di/Release")
  [ "$(sha256sum < "$d/SHA256SUMS" | cut -d' ' -f1)" = "$want" ] || { echo "SHA256SUMS: bad checksum" >&2; exit 1; }
  # The CD installer: everything under ./cdrom/
  grep ' \./cdrom/' "$d/SHA256SUMS" | while read -r sum f; do
    f=${f#./}
    mkdir -p "$d/$(dirname "$f")"
    wget -q -O "$d/$f" "$base/$rel/$f"
    echo "$sum  $d/$f" | sha256sum -c --quiet - || { echo "$f: bad checksum" >&2; exit 1; }
  done
  echo "Installer: $(grep -c ' \./cdrom/' "$d/SHA256SUMS") files of installer-$ARCH (verified)"
}
get_installer

rm -rf "$WORK/profiles"
cp -r "$HERE/profiles" "$WORK/profiles"
cat > "$WORK/nextspace-j.conf" <<EOF
profiles="nextspace-j"
auto_profiles="nextspace-j"
debian_mirror="http://deb.debian.org/debian/"
security_mirror="http://deb.debian.org/debian-security/"
mirror_components="main non-free-firmware"
local_packages="$WORK/local"
custom_installer="$WORK/installer"
export ARCH=$ARCH
export ARCHES=$ARCH
# Japanese installer: these are asked before the preseed file is read
export KERNEL_PARAMS="preseed/file=/cdrom/simple-cdd/default.preseed locale=ja_JP.UTF-8 keyboard-configuration/xkb-keymap=jp"
export DISKINFO="NEXTSPACE-J $VERSION: Debian GNU/Linux $DEBVER $DIST $ARCH"
# No 32-bit UEFI boot files on the amd64 image: they come from the i386
# installer, which Debian 13 does not have
export DISABLE_UEFI_32=1
# One image with everything (Chromium, Firefox, CJK fonts: more than a CD)
export DISKTYPE=DVD
export MAXCDS=1
export OMIT_MANUAL=1
export OMIT_RELEASE_NOTES=1
export DOJIGDO=0
EOF

cd "$WORK"
build-simple-cdd --conf nextspace-j.conf --dist "$DIST" 2>&1 | tee build.log
iso=$(ls -t images/*.iso | head -1)
name="nextspace-j-$(echo "$VERSION" | cut -c1-8)-${ARCH}.iso"   # e.g. nextspace-j-20261128-amd64.iso
cp "$iso" "$OUT/$name"
(cd "$OUT" && sha256sum "$name" > "$name.sha256")
echo "ISO: $OUT/$name ($(du -h "$OUT/$name" | cut -f1))"
