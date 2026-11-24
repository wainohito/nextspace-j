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
- **WebBrowser.app**: NeXT 風のウインドウで Chromium を使うブラウザ。
  Firefox.app と Chromium.app も `/Applications` から起動できます。
- **不具合修正**: TIFF 読み込みで Workspace が落ちる問題、Terminal の全角文字幅、
  全画面ウインドウの上にメニューが残る問題など。

## インストール

Debian 13 をデスクトップ環境なし (CLI のみ) でインストールし、sudo を使える一般
ユーザーで次を実行します。

```
sudo apt install git
git clone https://github.com/wainohito/nextspace-j.git nextspace
cd nextspace/Packaging/Debian13
./install.sh
```

依存パッケージのインストールから、ビルド、日本語の初期設定までを1本のスクリプトで
行います。詳しい手順と、各段階の内容は
[Packaging/Debian13/README.md](Packaging/Debian13/README.md) を見てください。

> **注意**: まっさらな Debian 13 での通しのテストはまだ済んでいません。

## ブランチ

- `japanese` (既定): このフォークの変更をすべて含むブランチ
- `master`: 本家 [trunkmaster/nextspace](https://github.com/trunkmaster/nextspace) と同じ内容

## ライセンス

本家 NEXTSPACE と同じです ([LICENSE](LICENSE))。`Applications/Extra` の追加アプリの
ライセンスは [Applications/Extra/README.md](Applications/Extra/README.md) を見てください。
