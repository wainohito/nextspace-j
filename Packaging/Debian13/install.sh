#!/bin/bash
# NEXTSPACE (japanese branch) for Debian 13: one-step build & install.
# See README.md here and Packaging/Sources/extra/install-japanese.sh.
#   ./install.sh                 run all stages
#   ./install.sh --update        after "git pull": update, keeping the settings
#   ./install.sh extra user      run only the given stages
#   ./install.sh --from extra    run from a stage to the end
#   ./install.sh --list          list stages
export NS_DEBIAN=13 NS_ARCH=
exec "$(dirname "$0")/../Sources/extra/install-japanese.sh" "$@"
