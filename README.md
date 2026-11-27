# Protadin Assistant

Small addon for Protection Paladins in WoW Forever. It keeps an eye on your buffs and your rotation, so you can just tank.

Download: https://www.curseforge.com/projects/1826638

## What's here

The repository root is the addon itself (`ProtadinAssistant.toc`, the `.lua` files, `Libs/`). Besides that:

- `tools/` - local tests that run the addon on a mocked WoW API (Lua 5.1), and `install.sh` to copy the addon into the game
- `PROJECT.md` - notes: how it works, client quirks, history
- `curseforge-description.md` - the CurseForge page text

These are not included in the released zip (see `.pkgmeta`).

## Releases

A tag like `v1.0.4` builds the addon and uploads it to CurseForge via GitHub Actions.

License: MIT.
