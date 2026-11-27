# NEXTSPACE-J のパッケージ、apt リポジトリ、インストーラ ISO の作り方

Debian 12 i386 用と Debian 13 amd64 用を、それぞれの Debian の上で作ります。

## 1. パッケージ (build-debs.sh)

ビルドする Debian に、同じコミットの NEXTSPACE-J のライブラリが入っている必要が
あります (install.sh でインストールした環境か、パッケージを入れてから
`install.sh deps` でビルド用パッケージを足した環境)。そのユーザーで:

```
Packaging/deb/build-debs.sh --clean ~/debs-out
```

`nextspace-j-core`, `nextspace-j`, `nextspace-j-ja`, `nextspace-j-extra`,
`nextspace-j-dockapps`, `nextspace-j-desktop` (全部と Firefox・Chromium) ができます。
バージョンはコミットの日時とハッシュに `~deb12` / `~deb13` を付けたものです。
途中で止まったときは `--clean` なしで実行すると、終わった部分を飛ばして続けます。

## 2. apt リポジトリ (make-repo.sh, publish-repo.sh)

```
Packaging/deb/publish-repo.sh DEB12_DIR/*.deb DEB13_DIR/*.deb
```

署名 (NEXTSPACE-J Archive Signing Key, `nextspace-j-archive-key.asc`) をして
https://github.com/wainohito/nextspace-j-apt に push し、GitHub Pages
(https://wainohito.github.io/nextspace-j-apt/) で公開します。秘密鍵は作業する
PC の `~/.gnupg` にあります (控えは別に保管)。リポジトリは履歴を持たず、
パッケージごとに新しい 2 版だけを残します。

`nextspace-j-ja` が `/etc/apt/sources.list.d/nextspace-j.sources` と公開鍵を入れるので、
インストールした環境は `apt upgrade` で更新できます。

## 3. インストーラ ISO (../iso/build-iso.sh)

simple-cdd (`sudo apt install simple-cdd`) で、Debian のミラーとパッケージから作ります
(どの Debian / アーキテクチャの PC でも作れます。数 GB の作業領域を使います)。

```
Packaging/iso/build-iso.sh trixie   DEB13_DIR ~/nextspace-iso   # nextspace-j-YYYYMMDD-amd64.iso
Packaging/iso/build-iso.sh bookworm DEB12_DIR ~/nextspace-iso   # nextspace-j-YYYYMMDD-i386.iso
```

インストーラの設定は `Packaging/iso/profiles/` にあります (`default.preseed`: 日本語・
日本のミラー・Debian のタスクなし、`nextspace-j.packages`: nextspace-j-desktop、
`default.downloads`: インストーラ自身が使うパッケージ)。
