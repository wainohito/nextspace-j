#!/bin/bash
#
# Publish NEXTSPACE-J packages in the apt repository on GitHub Pages
# (https://github.com/wainohito/nextspace-j-apt):
#
#   Packaging/deb/publish-repo.sh DEB...
#
# Adds the packages to the local copy ($APT_REPO_DIR, default
# ~/nextspace-j-apt; see make-repo.sh), and pushes it as a single commit
# (no history: the repository keeps only the current packages).
set -e

HERE=$(cd "$(dirname "$0")" && pwd)
REPO_DIR=${APT_REPO_DIR:-$HOME/nextspace-j-apt}
REMOTE=https://github.com/wainohito/nextspace-j-apt.git
URL=https://wainohito.github.io/nextspace-j-apt/

if [ ! -d "$REPO_DIR/.git" ]; then
  git clone -q "$REMOTE" "$REPO_DIR" 2>/dev/null || {
    mkdir -p "$REPO_DIR"
    git -C "$REPO_DIR" init -q -b main
    git -C "$REPO_DIR" remote add origin "$REMOTE"
  }
fi

"$HERE/make-repo.sh" "$REPO_DIR" "$@"

cd "$REPO_DIR"
touch .nojekyll   # GitHub Pages: serve the files as they are
cat > README.md <<EOF
# NEXTSPACE-J apt repository

Packages of [NEXTSPACE-J](https://github.com/wainohito/nextspace-j), the
Japanese fork of the NEXTSPACE desktop, for Debian 12 "bookworm" (i386)
and Debian 13 "trixie" (amd64).

## 使い方

\`\`\`
wget -qO- ${URL}nextspace-j-archive-key.asc | sudo gpg --dearmor -o /usr/share/keyrings/nextspace-j-archive-keyring.gpg
. /etc/os-release
printf 'Types: deb\nURIs: ${URL}\nSuites: %s\nComponents: main\nSigned-By: /usr/share/keyrings/nextspace-j-archive-keyring.gpg\n' "\$VERSION_CODENAME" | sudo tee /etc/apt/sources.list.d/nextspace-j.sources
sudo apt update
sudo apt install nextspace-j-desktop
\`\`\`

インストール後の更新は \`sudo apt update && sudo apt upgrade\` です
(nextspace-j-ja がこのリポジトリの設定を入れます)。

Signing key: \`$(gpg --with-colons --fingerprint "${NEXTSPACE_J_KEY:-36EB10F693EF98C9DEB4C1E557D700E6A05D8FAF}" | awk -F: '/^fpr/{print $10; exit}')\`
EOF

git add -A
git checkout -q --orphan publish
git commit -q -m "NEXTSPACE-J packages $(date +%F)"
git branch -D main >/dev/null 2>&1 || true
git branch -m main
git push -q -f origin main
echo "Published: $URL"
