# NEXTSPACE 日本語環境 for Debian 12 (bookworm) i386 (x86 32 ビット)

このブランチ (`japanese`) の NEXTSPACE を、Debian 12 の i386 (32 ビット x86) 版に依存パッケージから
まとめてビルド・インストールするためのスクリプトです。

## 使い方

Debian 12 i386 を最小構成 (デスクトップ環境なし) でインストールし、sudo グループの
一般ユーザーでログインして実行します。

- インストーラのソフトウェアの選択は「SSH サーバ」と「標準システムユーティリティ」
  だけにします (デスクトップ環境・GNOME などは外す)。
- インストーラで root のパスワードを空にすると、最初のユーザーが sudo を使えます。
  root のパスワードを設定した場合は、先に次を実行してください。
  ```
  su -
  apt install sudo
  usermod -aG sudo <ユーザー名>
  exit
  ```
  (一度ログアウトして入り直すと sudo が使えます)

```
sudo apt install git
git clone https://github.com/wainohito/nextspace-j.git nextspace
cd nextspace/Packaging/Debian12_x86
./install.sh
```

途中で sudo のパスワードを聞かれます。実行の記録は `~/nextspace-install.log` に残ります
(途中で止まったときの原因調べに使います)。NEXTSPACE にログインできて不要になったら
`rm ~/nextspace-install.log` で削除してください。終わったら再起動すると NEXTSPACE の
ログイン画面 (Login.app) が出ます。

段階を指定して実行することもできます。

```
./install.sh --list            # 段階の一覧
./install.sh extra user        # 指定した段階だけ
./install.sh --from nextspace  # その段階から最後まで
```

| 段階 | 内容 |
|---|---|
| deps | Debian 版 GNUstep を入れない apt 設定、ビルド・実行に必要なパッケージ、Dock アプリ (dockapp) のパッケージ、セキュリティ更新の自動適用 |
| core | libdispatch, CoreFoundation, libobjc2, gnustep-make, libwraster, libs-base, libs-gui (日本語訳・インライン入力パッチ込み), libs-back |
| nextspace | Frameworks と NEXTSPACE のアプリ (Login, Workspace, Preferences など) |
| extra | Applications/Extra: gs-desktop 由来のアプリ、WebBrowser、Firefox/Chromium の .app、Dock アプリ (`/Applications/Dockapps`) |
| system | root 用の NEXTSPACE 初期設定 (Login.app 用)、フォントの自動登録 (nextspace-fonts と apt フック)、環境設定からのタイムゾーン変更 (sudoers)、systemd の停止待ち時間 15 秒、fcitx5 用の環境変数 |
| user | 実行したユーザーのホーム: NEXTSPACE の初期設定、日本語 UI・フォント (スムージング、ウインドウタイトルなど WM の日本語フォント)、Dock に Firefox・Chromium・WebBrowser・トレイ、インライン入力、fcitx5 の XIM 設定、トレイ (wmsystemtray/pasystray) の自動起動 |

core と nextspace は `Packaging/Sources` の各スクリプト (0〜9) を順番に呼び出す
だけなので、部品ごとの作り直しは従来どおりそれらを直接実行できます。

## この環境に含まれるもの

- 日本語化: Workspace (ウインドウマネージャのメニュー含む), Preferences, Terminal,
  TextEdit, Review, OpenUp, TimeMon, GNUstep 本体, Applications/Extra のアプリ
  (訳語は `Localization/Japanese/*.json`)
- fcitx5 + Mozc のインライン入力 (GNUstep アプリでも変換中の文字を入力欄に表示)
- Dock の入力モード・音量表示 (wmsystemtray + pasystray)
- 不具合修正: libwraster の TIFF 読み込み (Workspace が落ちる), Terminal の全角文字幅,
  スクロールバーの描画跡, 全画面ウインドウの上にメニューが残る, dockapp 起動時の
  Workspace クラッシュ ほか

## フォントの追加

NEXTSPACE の描画 (art バックエンド) は fontconfig ではなく `.nfont` パッケージだけを
読みます。`nextspace-fonts` が fontconfig に登録されたフォント (TrueType/OpenType)
から `~/Library/Fonts/<ファミリー> (auto).nfont` を自動で作るので、apt や
`~/.local/share/fonts` で入れたフォントもそのまま使えます。ログインのたびと apt の
実行後に更新されます (起動中のアプリには、アプリを起動し直すと反映)。すぐに反映
したいときは `nextspace-fonts -v` を実行してください。

## apt での更新について

NEXTSPACE は `/usr/NextSpace`, `/Library`, `/Applications` などに入り、apt の管理外
なので、apt の更新で上書きされることはありません。Debian 版の GNUstep が依存関係で
入るとライブラリが衝突するため、`/etc/apt/preferences.d/nextspace` で導入を禁止して
います (deps 段階で設定)。

Firefox (firefox-esr) と Chromium は Debian のパッケージをそのまま使い、
`/Applications` の Firefox.app / Chromium.app はそれを起動するだけです。Debian は両ブラウザ
の新しいセキュリティリリースを bookworm-security で随時配布するので、deps 段階で
unattended-upgrades を入れ、`/etc/apt/apt.conf.d/20auto-upgrades` で毎日自動適用します。

## 元に戻すとき

`Packaging/Sources/nextspace_uninstall.sh` を参照してください。この手順で追加した
ファイル: `/etc/apt/preferences.d/nextspace`, `/etc/apt/apt.conf.d/20auto-upgrades`, `/etc/sudoers.d/nextspace-timezone`, `/etc/systemd/{system,user}.conf.d/nextspace-timeout.conf`, `/usr/local/bin/nextspace-fonts`, `/etc/apt/apt.conf.d/99nextspace-fonts`, `~/Library/Fonts/* (auto).nfont`,
`/etc/environment` の fcitx 用の行, `~/.local/bin/nextspace-autostart`,
`~/.local/bin/nextspace-logout`, `~/.config/fcitx5/conf/xim.conf`。
