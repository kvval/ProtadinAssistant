# Protadin Assistant - project notes

Addon for Protection Paladins in **World of Warcraft: Forever**. Author on CurseForge: Lori Quaid. License: MIT.
Current version: **1.0.3** (2026-11-27).

## Where things are

| What | Where |
|---|---|
| Source code | `/mnt/d/VC/paladon/ProtadinAssistant/` |
| Installed copy (game) | `C:\WarCraft\World of Warcraft\_forever_\Interface\AddOns\ProtadinAssistant\` - a copy, not a link; re-copy after every change |
| Release zips | `/mnt/d/VC/paladon/dist/` (latest: `ProtadinAssistant-1.0.3.zip`, must include `Libs/`) |
| CurseForge page text | `/mnt/d/VC/paladon/curseforge-description.md` |
| Changelog for CurseForge | `ProtadinAssistant/CHANGELOG.md` (used by the packager) |
| In-game Lua errors | `_forever_\Logs\General.log`, lines with `[E][Lua]` (written on exit / reload) |
| Saved settings | `_forever_\WTF\Account\<ACCOUNT>\SavedVariables\ProtadinAssistant.lua` |

Test character: Lori-Quaid (Protection paladin, English client).

## The client (WoW Forever)

- Official Blizzard product `wowf`, client 1.60.1, **Interface 16001**.
- Classic-like 1.x gameplay on the modern **Midnight (12.x) engine**: C_Spell, C_UnitAuras, Settings API, secret values.
- Forever-specific content: own dungeons, Seal of Fury, Swift Judgement, Holy Strike as a rotation spell, camping (Basic Campfire Kit, Camp Benefits), Cozy Sleeping Bag (Well-Rested), cooked food gives Well Fed with +5% kill XP for 15 min.
- On Forever, Judgement does **not** consume the seal; a seal lasts 30 s.

### Engine quirks we hit (important for any change)

1. **Cooldowns are secret in combat.** `C_Spell.GetSpellCooldown` returns secret values. Cast events (`UNIT_SPELLCAST_SUCCEEDED`) are readable, so the addon times cooldowns itself and learns real durations out of combat.
2. **Auras in instances:** `C_UnitAuras.GetAuraDataByIndex` throws an error ("Auras cannot be accessed when secret while tainted"). Check `C_Secrets.ShouldAurasBeSecret()` first and wrap the call in `pcall`. Drops can still be seen via `UNIT_AURA` `removedAuraInstanceIDs`.
3. **Loading screens and login / reload:** the client briefly reports empty buff and tracking lists. The buff module ignores scans while loading and for 3 s after entering the world.
4. **Target checks:** `C_Spell.IsSpellUsable` says "usable" for Exorcism on a beast. `C_Spell.IsSpellInRange` returns `nil` both for an invalid target and for spells without range. Rule: `nil` plus a spell that has range means an invalid target.
5. **Lua gotcha:** `tostring(f())` errors when `f` returns nothing - wrap it as `tostring((f()))`.

## What the addon does (1.0.0)

**Buff tracker** (secure, clickable buttons): Aura, Blessing (own only), Righteous Fury, Tracking, Well Fed, Well-Rested, Camp Benefits.
- A fade or the wrong buff makes the icon blink red and puts one chat line ("X has faded" / "X is up, expected Y").
- A click recasts the buff, eats the XP food with the smallest count in the bags, or uses the sleeping bag / campfire kit.
- On first run it takes the aura, blessing and tracking already active.

**Cooldown timeline:** a 10 s track, countdowns, a seal tracker (blinks at "now" when no seal), ready spells pop and hide, overlapping icons turn translucent. Shown only in combat by default.
- **Suggest next:** gold icon = first ready, usable, in-range spell by priority.
- **Highlight upcoming:** spells ready within 1.5 s grow.
- **Rotation, by prio:** one list of numbered drop-downs (position = priority; "- none -" removes a spell; "+ add a spell" adds one).

**Priority from your play:** records pairwise choices (cast A while B was also ready). After 20 choices it offers an order (Apply / Forget). A chat notice is sent when the order changes noticeably: at most once a day, never twice for the same order, and it can be turned off ("Announce play style change").

**Other:**
- Minimap button (embedded LibDBIcon): LMB applies the learned priority, RMB opens options, Shift+LMB locks / unlocks, Shift+RMB resets positions, Ctrl+LMB lists auras, Ctrl+RMB prints debug.
- Options panel with three bordered sections: General, Buff tracker, Cooldown timeline.
- Frames are locked by default. While they are unlocked, an 8 px grid is shown and frames snap to it and to the screen centre.
- Multilingual: spells by ID (`Data.lua`), the interface in 10 languages (`Locales.lua`, key = English text).
- Slash commands: `/protadin` (`/pda`) `lock | unlock | reset | auras | debug`.

## Code layout

| File | Role |
|---|---|
| `Libs/` | LibStub, CallbackHandler-1.0, LibDataBroker-1.1, LibDBIcon-1.0 (copied from DBM-Core / Masque) |
| `Locales.lua` | UI strings, `KEYS` list plus one table per locale |
| `Core.lua` | defaults, SavedVariables, helpers (spellbook, auras, cooldowns, range), movers, grid, slash commands |
| `Data.lua` | spell / item IDs, localized names, classifiers, XP food detection |
| `Buffs.lua` | buff tracker |
| `Timeline.lua` | timeline, suggest next, learned priority |
| `Options.lua` | options panel |
| `Minimap.lua` | minimap button |

## How we check changes (no game access from here)

1. `luac5.1 -p *.lua` checks the syntax. `luac5.1 -p -l` lists globals and catches accidental `SETGLOBAL`.
2. A mock WoW harness (`tools/harness.lua`, see `tools/README.md`) loads the whole addon in `.toc` order and runs the options, timeline, buffs and minimap clicks.
3. A locale check confirms that every `L[...]` used in the code is in `KEYS` and that every locale has all keys with matching `%s` / `%d`.
4. Targeted model tests: priority swaps, learned priority (simulated fights), notice throttling, loading screens, food pick, grid snapping.
5. Then copy to the game, bump the version and build the zip.

## History (short)

- **0.1-0.2:** buff tracker plus timeline. In-game test showed cooldowns are secret in combat, so own timers were added.
- **0.3:** multilingual by spell IDs; fix for aura errors in dungeons.
- **0.4:** Suggest next, Highlight upcoming, priority list (arrows, then drop-downs, then one merged list); Exorcism / target-type fix.
- **0.5:** options panel redesign (stacked bordered sections, newcomer-friendly labels, "Only during combat").
- **0.6:** priority learned from play, daily chat notice and its toggle; loading-screen false alarms fixed.
- **0.7:** clickable XP food, chat messages reworded, grid snapping, frames locked by default.
- **0.8:** minimap button (LibDBIcon).
- **1.0.0:** release. CurseForge page rewritten in the author's voice.
- **1.0.1:** upcoming spells grow smoothly (0-1.5 s, up to 120%) with a border fading to gold; "Suggest next" icon is 20% bigger with a pulsing gold glow; the ready pop matches the grown size.
- **1.0.2:** first-run experience: buff tracker defaults to the right side under the minimap; Well Fed / Well-Rested are switched on or off at every login depending on XP food / sleeping bag in the bags; timeline shown always for new installs; one-time welcome + tip about "Only during combat".
- **1.0.3:** a Well Fed / Well-Rested slot switched by hand in the options is never switched automatically again (foodManual / bagManual). Camp Benefits stays always visible (other players' campfires count too).

## Open items

- [ ] Run a dungeon on 1.0.0 and check there are no Lua errors (the 0.3.1 aura-restriction fix is untested in a real instance).
- [ ] Try clicks in game: minimap button, food, campfire kit.
- [ ] Get the **Camp Benefits** spell ID (`/protadin auras` at a camp). Until then the camp icon only works on English clients.
- [ ] Check "X has faded" on a natural expiry in normal play.
- [ ] CurseForge: delete / archive 0.3.0 and 0.3.1 (they were under review), upload 1.0.0 as Release, paste the new description and changelog.
- [x] Old zips in `dist/` cleaned (2026-11-24), only 1.0.0 kept.

## Working agreements

- Design is discussed first; code is written only after an explicit go-ahead.
- UI texts are short and clear for someone who just installed the addon. Show a mock-up or table before big UI changes.
- Public texts (CurseForge) are written in the author's own voice: direct, plain, hyphen dashes, no marketing gloss.
- Don't promise in public texts what hasn't been verified in game.
