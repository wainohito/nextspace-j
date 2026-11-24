# Extra applications

Applications ported from [GNUstep Desktop (gs-desktop)](https://github.com/onflapp/gs-desktop)
(imported from commit b49e422, 2025-10-12). Each application keeps its own
license files; gs-desktop itself is MIT licensed.

Build and install (installs into `/Applications`):

    . /Developer/Makefiles/GNUstep.sh
    make && sudo -E make install

Runtime dependencies (Debian 13): vlc-bin vlc-plugin-base vlc-plugin-video-output
(Player), scrot slop ffmpeg (ScreenShot), sane-utils (ScanImage), avahi-utils
(NetHood), recollcmd poppler-utils unrtf (Librarian).
