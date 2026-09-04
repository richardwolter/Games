#!/usr/bin/env bash
# Stamp the build, export it for the web, and zip it for itch.io.
#
# The stamp has to be written BEFORE the export or the .pck carries the previous
# one, which is worse than carrying none — a playtester would be told they are on
# a build they are not on. That ordering is the only reason this is a script
# rather than two commands in the terminal.
#
# Usage:  tools/build_web.sh
set -euo pipefail

cd "$(dirname "$0")/.."
GODOT="${GODOT:-/c/Users/Administrador/Desktop/Godot_v4.7.1-stable_win64.exe}"
STAMP="$(date +'%Y-%m-%d %H%M')"

# Rewrite just the constant, leaving the file's documentation alone.
sed -i "s|^const STAMP := \".*\"$|const STAMP := \"${STAMP}\"|" scripts/build_info.gd
echo "stamped: ${STAMP}"

# Godot will not create the destination folder, only write into it — so this has
# to be a wipe-and-recreate, not a wipe.
rm -rf build/web build/StraitAcross_web.zip
mkdir -p build/web
"$GODOT" --headless --path . --export-release "Web" build/web/index.html

# Godot re-imports the icons it just wrote into build/, since build/ sits inside
# the project. Those .import files must not reach itch.io.
rm -f build/web/*.import

powershell -NoProfile -Command "Compress-Archive -Path 'build/web/*' -DestinationPath 'build/StraitAcross_web.zip' -Force"
echo "packaged: build/StraitAcross_web.zip"
