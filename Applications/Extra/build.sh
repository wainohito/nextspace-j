#!/bin/sh
# Build and install the extra applications (and the PDFKit framework they
# need) into the LOCAL domain (/Applications, /Library).
# Usage: ./build.sh            (asks for sudo when installing)
set -e
cd "$(dirname "$0")"
. /Developer/Makefiles/GNUstep.sh
export CC=${CC:-clang} CXX=${CXX:-clang++}

# TerminalKit (from gs-terminal; needed by CloudManager, NotMon, SystemManager)
cd Frameworks/TerminalKit
make
sudo -E sh -c ". /Developer/Makefiles/GNUstep.sh; make install GNUSTEP_INSTALLATION_DOMAIN=LOCAL"
sudo ldconfig
cd ../..

# PDFKit (needed by DocumentViewer)
cd Frameworks/PDFKit
[ -f GNUmakefile ] || ./configure
make
sudo -E sh -c ". /Developer/Makefiles/GNUstep.sh; make install GNUSTEP_INSTALLATION_DOMAIN=LOCAL"
sudo ldconfig
cd ../..

make
sudo -E sh -c ". /Developer/Makefiles/GNUstep.sh; make install GNUSTEP_INSTALLATION_DOMAIN=LOCAL"
sudo ldconfig

# Wrappers around non-GNUstep applications (need WrapperFactory's
# /Library/bin/GSWrapper_Launcher, installed above)
for app in Wrappers/*.app; do
  # Replace, don't merge: files moved inside the wrapper (e.g. Launcher.gorm
  # into English.lproj) must not survive from an older install.
  sudo rm -rf "/Applications/$(basename "$app")"
  sudo cp -a "$app" /Applications/
done

# Window Maker dockapps as /Applications/Dockapps/*.app
Dockapps/build.sh
