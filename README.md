# NEXTSPACE 日本語版 (Debian 13)

[NEXTSPACE](https://github.com/trunkmaster/nextspace) は、Linux 上で
[NeXTSTEP](https://ja.wikipedia.org/wiki/NEXTSTEP) の見た目と操作感を再現する
デスクトップ環境です。このリポジトリはその個人用フォークで、**日本語で快適に使える
こと**と **Debian 13 (trixie) への導入**を目的に機能を追加しています。

本家の説明 (英語) は [README.en.md](README.en.md) にあります。

![NEXTSPACE](Documentation/NEXTSPACE_Screenshot.png)

## このフォークで追加したもの

- **日本語化**: Workspace (ウインドウマネージャのメニューを含む)、Preferences、
  Terminal、TextEdit、Review、OpenUp、TimeMon、GNUstep 本体、追加アプリ。
  環境設定の「言語」で Japanese を選べます。
- **日本語のインライン入力**: fcitx5 + Mozc で、変換中の文字を入力欄の中に表示します
  (GNUstep アプリ、Terminal とも)。変換候補も入力位置に出ます。
- **Dock の入力モード・音量表示**: wmsystemtray + pasystray。クリックで入力モードを
  切り替えられます。
- **追加アプリ** (`Applications/Extra`): [GNUstep Desktop](https://github.com/onflapp/gs-desktop)
  のアプリを移植し、日本語化しました。住所録、付箋、電卓、辞書、PDF ビューア、
  音楽・動画プレーヤー、スクリーンショット、ドローなどです。
- **Dock アプリ** (`/Applications/Dockapps`): Window Maker の dockapp (時計、CPU・
  メモリ・ネットワークの表示、ミキサーなど 44 個) を .app にしてあります。Dock に
  ドラッグして置き、ログイン時の自動起動は Workspace の環境設定の Dock で設定します。
  終了はメニューの「終了」か、リサイクラーへのドラッグ (Dock からも外れます) です。
- **WebBrowser.app**: NeXT 風のウインドウで Chromium を使うブラウザ。
  Firefox.app と Chromium.app も `/Applications` から起動できます。
- **不具合修正**: TIFF 読み込みで Workspace が落ちる問題、Terminal の全角文字幅、
  全画面ウインドウの上にメニューが残る問題など。

## インストール

方法は 3 通りあります。どれも Debian 13 (amd64) と Debian 12 (i386, 32 ビット x86) に
対応しています。

### 1. インストーラ ISO (おすすめ)

Debian と NEXTSPACE-J をまとめてインストールする ISO です。
[Releases](https://github.com/wainohito/nextspace-j/releases) から、使う PC に
合わせてダウンロードし、USB メモリや DVD に書き込んで (仮想マシンならそのまま)
起動します。

- `nextspace-j-YYYYMMDD-amd64.iso`: Debian 13、64 ビット PC
- `nextspace-j-YYYYMMDD-i386.iso`: Debian 12、32 ビット PC

インストーラは日本語で始まり、言語・キーボード・タイムゾーンは日本向けに設定済み
です。ネットワーク・ホスト名・ユーザー・ディスクの分け方はいつもどおり聞かれます。
Debian のデスクトップ環境の代わりに NEXTSPACE-J が入り、再起動するとログイン画面が
出ます。初めてログインしたときに日本語の環境 (フォント、Dock、Mozc の入力) が整います。
ネットワークにつながっていれば Debian のミラー (ftp.jp.debian.org) とセキュリティ
更新も設定されます。ISO だけでもインストールは完了します。

### 2. apt でインストール

Debian 13 amd64 / Debian 12 i386 をデスクトップ環境なしでインストール済みなら、
[apt リポジトリ](https://wainohito.github.io/nextspace-j-apt/) から入れられます。

```
wget -qO- https://wainohito.github.io/nextspace-j-apt/nextspace-j-archive-key.asc | sudo gpg --dearmor -o /usr/share/keyrings/nextspace-j-archive-keyring.gpg
. /etc/os-release
printf 'Types: deb\nURIs: https://wainohito.github.io/nextspace-j-apt/\nSuites: %s\nComponents: main\nSigned-By: /usr/share/keyrings/nextspace-j-archive-keyring.gpg\n' "$VERSION_CODENAME" | sudo tee /etc/apt/sources.list.d/nextspace-j.sources
sudo apt update
sudo apt install nextspace-j-desktop
```

ISO と apt のどちらで入れた場合も、更新は `sudo apt update && sudo apt upgrade` です。

### 3. ソースからビルド (install.sh)

ソースからビルドしてインストールします (30 分〜1 時間)。Debian をデスクトップ
環境なし (CLI のみ) でインストールし、sudo を使える一般ユーザーで次を実行します。

```
sudo apt install git
git clone https://github.com/wainohito/nextspace-j.git nextspace
cd nextspace/Packaging/Debian13
./install.sh
```

Debian 12 i386 では `Packaging/Debian13` の代わりに `Packaging/Debian12_x86` で
`./install.sh` を実行します。インストール後の更新は `git pull` してから
`./install.sh --update` です (設定はそのまま残ります)。詳しくは
[Packaging/Debian13/README.md](Packaging/Debian13/README.md)
([Debian 12 i386 版](Packaging/Debian12_x86/README.md)) を見てください。

パッケージと ISO の作り方は [Packaging/deb/README.md](Packaging/deb/README.md) に
あります。

ISO と install.sh は、まっさらな Debian 13 amd64 と Debian 12 i386 (仮想マシン) への
インストールで、ログインと日本語の環境まで確認しています (パッケージは Debian 13 に
ローカルの deb を `apt install` して確認)。

## ブランチ

- `japanese` (既定): このフォークの変更をすべて含むブランチ
- `master`: 本家 [trunkmaster/nextspace](https://github.com/trunkmaster/nextspace) と同じ内容

## ライセンス

本家 NEXTSPACE と同じです ([LICENSE](LICENSE))。`Applications/Extra` の追加アプリの
ライセンスは [Applications/Extra/README.md](Applications/Extra/README.md) を見てください。
