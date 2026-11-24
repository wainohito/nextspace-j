# Extra applications

Applications ported from [GNUstep Desktop (gs-desktop)](https://github.com/onflapp/gs-desktop)
(imported from commit b49e422, 2025-10-12). Each application keeps its own
license files; gs-desktop itself is MIT licensed.

Build and install (PDFKit framework first, then the apps, into `/Applications`):

    ./build.sh

DocumentViewer is built PDF-only; HTML viewing needs the WebKit framework
from gs-webbrowser (`make html=yes`).

Runtime dependencies (Debian 13): vlc-bin vlc-plugin-base vlc-plugin-video-output
(Player), scrot slop ffmpeg (ScreenShot), sane-utils (ScanImage), avahi-utils
(NetHood), recollcmd poppler-utils unrtf (Librarian), freerdp3-x11 (RemoteView).
Build dependencies: libfreetype-dev (PDFKit), libsdl2-dev libvncserver-dev (RemoteView).
