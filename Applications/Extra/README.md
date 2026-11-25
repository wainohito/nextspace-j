# Extra applications

Applications ported from [GNUstep Desktop (gs-desktop)](https://github.com/onflapp/gs-desktop)
(imported from commit b49e422, 2025-10-12). Each application keeps its own
license files; gs-desktop itself is MIT licensed.

Frameworks/TerminalKit comes from [gs-terminal](https://github.com/onflapp/gs-terminal)
(7d54839, MIT); East Asian wide characters are drawn two cells wide.

Build and install (TerminalKit and PDFKit frameworks first, then the apps, into `/Applications`):

    ./build.sh

DocumentViewer is built PDF-only; HTML viewing needs the WebKit framework
from gs-webbrowser (`make html=yes`).

Runtime dependencies (Debian 13): vlc-bin vlc-plugin-base vlc-plugin-video-output
(Player), scrot slop ffmpeg (ScreenShot), sane-utils (ScanImage), avahi-utils
(NetHood), recollcmd poppler-utils unrtf (Librarian), freerdp3-x11 (RemoteView), rclone (CloudManager).
Build dependencies: libfreetype-dev (PDFKit), libsdl2-dev libvncserver-dev (RemoteView).

## Wrappers

`Wrappers/Firefox.app` and `Wrappers/Chromium.app` (from gs-desktop's
extra-apps, adapted to use the browsers' normal profiles and key settings)
make Firefox and Chromium launchable from /Applications and the Dock, with a
GNUstep menu and an "Open URL" service. They are plain bundles that run
`/Library/bin/GSWrapper_Launcher` (WrapperFactory); build.sh copies them.

Dock: put the .app (not the browser window's own icon) into the Dock; an
icon docked from a running Chromium window records Debian's internal
command line and fails to launch. The browsers' own appicons (a second icon
at the bottom-left corner) are hidden with `NoAppIcon = YES` for the classes
Chromium, Firefox-esr and Firefox in
~/Library/Preferences/.NextSpace/WMWindowAttributes.plist, set by
`Packaging/Sources/extra/wm-setup.py` (install.sh user stage).

## WebBrowser

From [gs-webbrowser](https://github.com/onflapp/gs-webbrowser) (ddf2808, MIT):
a GNUstep browser window (NeXT style toolbar, menus, services) with an
embedded Chromium page.  The original Chrome App bridge no longer works
(current Chromium denies the `<webview>` element), so
`Resources/webview/cdpbridge.py` replaces it: it speaks the same line protocol
to WebBrowser.app and drives Chromium (`--app` windows, own profile in
~/Library/WebBrowser) through the Chrome DevTools Protocol, using only the
Python standard library.  The page windows start off screen with WM class
`WebBrowserView` until they are reparented, so they don't flash on screen;
`Packaging/Sources/extra/wm-setup.py` gives that class no appicon
in WMWindowAttributes.plist.  Set a home page in Preferences (or
`defaults write WebBrowser AppHomeURL <url>`) to open a window at launch.
