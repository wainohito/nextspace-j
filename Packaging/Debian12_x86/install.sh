#!/bin/bash
# NEXTSPACE (japanese branch) for Debian 12 i386: one-step build & install.
# See README.md here and Packaging/Sources/extra/install-japanese.sh.
#   ./install.sh                 run all stages
#   ./install.sh extra user      run only the given stages
#   ./install.sh --from extra    run from a stage to the end
#   ./install.sh --list          list stages
export NS_DEBIAN=12 NS_ARCH=i386
exec "$(dirname "$0")/../Sources/extra/install-japanese.sh" "$@"
