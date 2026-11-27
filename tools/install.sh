#!/usr/bin/env bash
# Copy the addon (only the files the game needs) into the AddOns folder.
set -euo pipefail
cd "$(dirname "$0")/.."
DEST="${WOW_ADDONS:-/mnt/c/WarCraft/World of Warcraft/_forever_/Interface/AddOns}/ProtadinAssistant"
mkdir -p "$DEST"
cp ./*.toc ./*.lua LICENSE CHANGELOG.md "$DEST/"
cp -r Libs "$DEST/"
echo "installed into $DEST ($(grep -m1 '^## Version' ProtadinAssistant.toc))"
