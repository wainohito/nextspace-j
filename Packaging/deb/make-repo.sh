#!/bin/bash
#
# Make (or update) the NEXTSPACE-J apt repository from built packages:
#
#   Packaging/deb/make-repo.sh REPO_DIR DEB...
#
# REPO_DIR gets the usual layout (pool/, dists/bookworm, dists/trixie),
# signed with the NEXTSPACE-J archive key (InRelease and Release.gpg).
# The Debian release of each package comes from its version (~deb12 ->
# bookworm, ~deb13 -> trixie).  Packages already in the pool are kept;
# old versions are removed (the newest KEEP=2 versions of each package
# and architecture stay).
#
# Users add it with nextspace-j.sources (see README.md).
set -e

KEY=${NEXTSPACE_J_KEY:-36EB10F693EF98C9DEB4C1E557D700E6A05D8FAF}
KEEP=${KEEP:-2}
REPO=$1; shift || true
[ -n "$REPO" ] && [ $# -gt 0 ] || { echo "usage: $0 REPO_DIR DEB..." >&2; exit 1; }
HERE=$(cd "$(dirname "$0")" && pwd)
mkdir -p "$REPO"
REPO=$(cd "$REPO" && pwd)

codename() {
  case "$1" in
    *~deb12) echo bookworm ;;
    *~deb13) echo trixie ;;
    *) echo "unknown Debian release in version $1" >&2; exit 1 ;;
  esac
}

# Add the packages
for deb in "$@"; do
  v=$(dpkg-deb -f "$deb" Version)
  c=$(codename "$v")
  install -D -m 644 "$deb" "$REPO/pool/$c/main/n/$(dpkg-deb -f "$deb" Package)/$(basename "$deb")"
done

# Keep the newest $KEEP versions of each package and architecture
for dir in "$REPO"/pool/*/main/n/*/; do
  for arch in $(ls "$dir" | sed 's/.*_\([^_]*\)\.deb$/\1/' | sort -u); do
    ls "$dir" | grep "_$arch.deb$" | sort -t_ -k2 -V -r | tail -n +$((KEEP + 1)) |
      while read -r old; do rm -f "$dir/$old"; done
  done
done

# Indexes and signed Release files
cd "$REPO"
for c in bookworm trixie; do
  [ -d "pool/$c" ] || continue
  for arch in amd64 i386; do
    d="dists/$c/main/binary-$arch"
    mkdir -p "$d"
    apt-ftparchive --arch "$arch" packages "pool/$c" > "$d/Packages"
    gzip -9 -n -k -f "$d/Packages"
  done
  apt-ftparchive \
    -o APT::FTPArchive::Release::Origin="NEXTSPACE-J" \
    -o APT::FTPArchive::Release::Label="NEXTSPACE-J" \
    -o APT::FTPArchive::Release::Suite="$c" \
    -o APT::FTPArchive::Release::Codename="$c" \
    -o APT::FTPArchive::Release::Architectures="amd64 i386" \
    -o APT::FTPArchive::Release::Components="main" \
    -o APT::FTPArchive::Release::Description="NEXTSPACE-J (Japanese NEXTSPACE desktop) for Debian $c" \
    release "dists/$c" > "dists/$c/Release"
  rm -f "dists/$c/InRelease" "dists/$c/Release.gpg"
  gpg --batch --yes --local-user "$KEY" --clearsign -o "dists/$c/InRelease" "dists/$c/Release"
  gpg --batch --yes --local-user "$KEY" --armor --detach-sign -o "dists/$c/Release.gpg" "dists/$c/Release"
done

# The public key and the apt source file next to the repository
cp "$HERE/nextspace-j-archive-key.asc" "$REPO/nextspace-j-archive-key.asc"
echo "Repository: $REPO"
find dists -name Packages | while read -r p; do
  echo "  $(dirname "$p"): $(grep -c '^Package:' "$p") packages"
done
