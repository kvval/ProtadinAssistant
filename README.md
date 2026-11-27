# Protadin Assistant

Small addon for Protection Paladins in WoW Forever. It keeps an eye on your buffs and your rotation, so you can just tank.

Download: https://www.curseforge.com/projects/1826638

## What's here

The repository root is the addon itself:

- `ProtadinAssistant.toc` - the addon description and load order
- `Modules/` - the code
- `Locales/` - interface translations
- `Libs/` - embedded libraries

Not part of the released zip (see `.pkgmeta`):

- `docs/` - project notes (`PROJECT.md`) and the CurseForge page text
- `tools/` - local tests on a mocked WoW API (Lua 5.1) and `install.sh` to copy the addon into the game

## Releases

A tag like `v1.0.4` builds the addon and uploads it to CurseForge via GitHub Actions.

License: MIT.
