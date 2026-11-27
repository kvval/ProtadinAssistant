#!/usr/bin/env bash
# Copy the addon (only the files the game needs) into the AddOns folder.
set -euo pipefail
cd "$(dirname "$0")/.."
DEST="${WOW_ADDONS:-/mnt/c/WarCraft/World of Warcraft/_forever_/Interface/AddOns}/ProtadinAssistant"
mkdir -p "$DEST"
cp ./*.toc LICENSE CHANGELOG.md "$DEST/"
cp -r Modules Locales Libs "$DEST/"
# remove files left from the old flat layout (before 1.0.4); the game no longer loads them
rm -f "$DEST"/Core.lua "$DEST"/Data.lua "$DEST"/Buffs.lua "$DEST"/Timeline.lua "$DEST"/Options.lua "$DEST"/Minimap.lua "$DEST"/Locales.lua
echo "installed into $DEST ($(grep -m1 '^## Version' ProtadinAssistant.toc))"
