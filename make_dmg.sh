#!/bin/bash
# Crée build/Phare.dmg (avec raccourci vers Applications) et sa somme SHA-256.
set -euo pipefail
cd "$(dirname "$0")"

[ -d build/Phare.app ] || ./build_app.sh
STAGE="$(mktemp -d)"
cp -R build/Phare.app "$STAGE/"
ln -s /Applications "$STAGE/Applications"
rm -f build/Phare.dmg
hdiutil create -volname "Phare" -srcfolder "$STAGE" -ov -format UDZO build/Phare.dmg >/dev/null
rm -rf "$STAGE"
( cd build && shasum -a 256 Phare.dmg | tee Phare.dmg.sha256 )
echo "OK : build/Phare.dmg"
