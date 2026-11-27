#!/bin/sh
# Build and install the extra applications (and the PDFKit framework they
# need) into the LOCAL domain (/Applications, /Library).
# Usage: ./build.sh            (asks for sudo when installing)
#        DESTDIR=/path ./build.sh   install into a staging directory (packages;
#                                   the frameworks must already be installed
#                                   on the system to build the applications)
set -e
cd "$(dirname "$0")"
. /Developer/Makefiles/GNUstep.sh
export CC=${CC:-clang} CXX=${CXX:-clang++}

# make install into the system (sudo) or into $DESTDIR
install_local() {
  if [ -n "$DESTDIR" ]; then
    make install GNUSTEP_INSTALLATION_DOMAIN=LOCAL DESTDIR="$DESTDIR"
  else
    sudo -E sh -c ". /Developer/Makefiles/GNUstep.sh; make install GNUSTEP_INSTALLATION_DOMAIN=LOCAL"
    sudo ldconfig
  fi
}

# TerminalKit (from gs-terminal; needed by CloudManager, NotMon, SystemManager)
cd Frameworks/TerminalKit
make
install_local
cd ../..

# PDFKit (needed by DocumentViewer)
cd Frameworks/PDFKit
[ -f GNUmakefile ] || ./configure
make
install_local
cd ../..

make
install_local

# Wrappers around non-GNUstep applications (need WrapperFactory's
# /Library/bin/GSWrapper_Launcher, installed above)
for app in Wrappers/*.app; do
  if [ -n "$DESTDIR" ]; then
    mkdir -p "$DESTDIR/Applications"
    cp -a "$app" "$DESTDIR/Applications/"
    continue
  fi
  # Replace, don't merge: files moved inside the wrapper (e.g. Launcher.gorm
  # into English.lproj) must not survive from an older install.
  sudo rm -rf "/Applications/$(basename "$app")"
  sudo cp -a "$app" /Applications/
done

# Window Maker dockapps as /Applications/Dockapps/*.app
[ -n "$NO_DOCKAPPS" ] || Dockapps/build.sh   # NO_DOCKAPPS=1: packaged separately
