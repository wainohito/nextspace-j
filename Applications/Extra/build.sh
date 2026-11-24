#!/bin/sh
# Build and install the extra applications (and the PDFKit framework they
# need) into the LOCAL domain (/Applications, /Library).
# Usage: ./build.sh            (asks for sudo when installing)
set -e
cd "$(dirname "$0")"
. /Developer/Makefiles/GNUstep.sh
export CC=${CC:-clang} CXX=${CXX:-clang++}

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
