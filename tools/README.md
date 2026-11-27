# Test tools (no game needed)

Run from the addon folder: `cd /mnt/d/VC/paladon/ProtadinAssistant`

- `luac5.1 -p *.lua` - syntax
- `lua5.1 ../tools/harness.lua . enUS` (or `ruRU`) - whole addon on a mocked WoW API, must end with `HARNESS OK`
- locale check:
  `grep -h -o 'L\["[^"]*"\]' Core.lua Buffs.lua Timeline.lua Options.lua Data.lua Minimap.lua | sed -E 's/^L\["(.*)"\]$/\1/' | sort -u > /tmp/used_keys.txt && lua5.1 ../tools/loccheck2.lua . /tmp/used_keys.txt`
- model tests: `learn_test.lua`, `notice_test.lua`, `loading_test.lua` (needs harness env, run like harness), `food_test.lua` (same), `snap_test.lua`, `list_test.lua`, `range_test.lua`, `restrict_test.lua` - each takes the addon dir as the first argument.
