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
