# Protadin Assistant - project notes

Addon for Protection Paladins in **World of Warcraft: Forever**. Author on CurseForge: Lori Quaid. License: MIT.
Current version: **1.0.3**, published on CurseForge and GitHub Releases on 2026-11-27 (first release through GitHub Actions).

Links: [CurseForge](https://www.curseforge.com/wow/addons/protadin-assistant) (project 1826638) · [GitHub](https://github.com/kvval/ProtadinAssistant)

## Where things are

| What | Where |
|---|---|
| Source code | `/mnt/d/VC/paladon/` - git repo, the root is the addon: `ProtadinAssistant.toc`, `Modules/`, `Locales/`, `Libs/` |
| Installed copy (game) | `C:\WarCraft\World of Warcraft\_forever_\Interface\AddOns\ProtadinAssistant\` - a copy, not a link; run `tools/install.sh` after every change |
| Release zips | built by GitHub Actions on a tag; `dist/` holds old local builds only (not in git) |
| CurseForge page text | `docs/curseforge-description.md` (pasted by hand, the packager doesn't update it) |
| Changelog for CurseForge | `CHANGELOG.md` (used by the packager) |
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

## What the addon does (1.0.3)

**Buff tracker** (secure, clickable buttons): Aura, Blessing (own only), Righteous Fury, Tracking, Well Fed, Well-Rested, Camp Benefits.
- A fade or the wrong buff makes the icon blink red and puts one chat line ("X has faded" / "X is up, expected Y").
- A click recasts the buff, eats the XP food with the smallest count in the bags, or uses the sleeping bag / campfire kit.
- On first run it takes the aura, blessing and tracking already active.
- Well Fed / Well-Rested are switched on or off at every login by what's in the bags, unless the player switched them by hand. Camp Benefits is always shown.
- Default place: right side, under the minimap.

**Cooldown timeline:** a 10 s track, countdowns, ready spells pop and hide, overlapping icons turn translucent. The **seal** is an entry of the rotation list ("Seal", internal key `__seal`, first by default): while a seal is up it travels the track with its time left; with no seal up it counts as "ready" and takes part in Suggest next and learning like any spell. (Until 1.0.3 it was a separate checkbox with a blinking icon at "now".) New installs see it always; "Only during combat" is an option (the welcome message points to it).
- **Suggest next:** gold icon, 20% bigger, pulsing glow = first ready, usable, in-range spell by priority.
- **Highlight upcoming:** spells ready within 1.5 s grow smoothly to the "Suggest next" size, the border fades to gold.
- **Rotation, by prio:** one list of numbered drop-downs (position = priority; "- none -" removes a spell; "+ add a spell" adds one).

**Priority from your play:** records pairwise choices (cast A while B was also ready). After 20 choices it offers an order (Apply / Forget). Details: casts that just follow the "Suggest next" hint are not learned (else the order confirms itself); every new choice ages old ones (half-life 500 choices); a pair counts only with ≥5 weighted comparisons and a winner whose Wilson lower bound (90%) is above 50%, so a few lucky casts (e.g. Exorcism 6:4) can't decide the order. Situational spells - castable in under half of the moments they are off cooldown (≥10 weighted observations, `learn.avail`), e.g. Exorcism, Hammer of Wrath - are left out of learning and keep the place the player gave them; shown in [brackets] in the suggested order. "Adapt automatically" (default on): after a fight, once 25 new choices are in, the learned order is applied and one chat line lists only the swaps ("priority Holy Shield <-> Judgement."). The old once-a-day "suggests a new priority" notice is gone.

**Other:**
- Minimap button (embedded LibDBIcon): LMB applies the learned priority, RMB opens options, Shift+LMB locks / unlocks, Shift+RMB resets positions, Ctrl+LMB lists auras, Ctrl+RMB prints debug.
- Options panel with three bordered sections: General, Buff tracker, Cooldown timeline.
- Frames are locked by default. While they are unlocked, an 8 px grid is shown and frames snap to it and to the screen centre.
- Multilingual: spells by ID (`Modules/Data.lua`), the interface in 10 languages (`Locales/Locales.lua`, key = English text).
- Slash commands: `/protadin` (`/pda`) `lock | unlock | reset | auras | debug`.
- One-time welcome message on the very first login.

## Saved data

In memory the addon uses spell names (client language). On disk (`ProtadinAssistantDB`, `storeVersion = 2`) everything spell-related is keyed by spell ID of rank 1: priority list, enabled spells, learned cooldowns, learning data (wins, avail, seals) and the chosen aura / blessing / tracking. `ns.LoadStored` converts IDs to names at login, `ns.SaveStored` back at logout (`PLAYER_LOGOUT`). Learned data survives a client language change. Non-paladin logins don't convert, so they leave the data untouched. Old name-keyed data (before 1.0.6) is converted on the first logout.

## Code layout

| File | Role |
|---|---|
| `Libs/` | LibStub, CallbackHandler-1.0, LibDataBroker-1.1, LibDBIcon-1.0 (copied from DBM-Core / Masque) |
| `Locales/Locales.lua` | UI strings, `KEYS` list plus one table per locale |
| `Modules/Core.lua` | defaults, SavedVariables, helpers (spellbook, auras, cooldowns, range), movers, grid, slash commands |
| `Modules/Data.lua` | spell / item IDs, localized names, classifiers, XP food detection |
| `Modules/Buffs.lua` | buff tracker |
| `Modules/Timeline.lua` | timeline, suggest next, learned priority |
| `Modules/Options.lua` | options panel |
| `Modules/Minimap.lua` | minimap button |

## How we check changes (no game access from here)

1. `luac5.1 -p Modules/*.lua Locales/*.lua` checks the syntax. `luac5.1 -p -l` lists globals and catches accidental `SETGLOBAL`.
2. A mock WoW harness (`tools/harness.lua`, see `tools/README.md`) loads the whole addon in `.toc` order and runs the options, timeline, buffs and minimap clicks.
3. A locale check confirms that every `L[...]` used in the code is in `KEYS` and that every locale has all keys with matching `%s` / `%d`.
4. Targeted model tests: priority swaps, learned priority (simulated fights), notice throttling, loading screens, food pick, grid snapping.
5. Then `tools/install.sh` puts it into the game for an in-game check.

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
- **1.0.3:** a Well Fed / Well-Rested slot switched by hand in the options is never switched automatically again (foodManual / bagManual). Camp Benefits stays always visible (other players' campfires count too). First release built and uploaded by GitHub Actions.
- **After 1.0.3 (not released yet):** repository tidied up - code in `Modules/` and `Locales/`, notes in `docs/`. Learned priority: hint-following casts ignored, half-life 500 choices, Wilson confidence threshold (Exorcism no longer jumps to the top on a handful of casts). Situational spells detected automatically and kept in place. "Adapt automatically" replaces the daily notice. Seal became a normal rotation entry (no separate blinking icon, "Track Seal" option removed). Seal popularity: every seal cast is counted (half-life 100 casts, `learn.seals`); Suggest next shows the most used seal's icon; the options show "Seals you use: … %". Chat messages show spells as clickable links (`ns.SpellLink`).

## Releasing (GitHub + CurseForge)

Repository: https://github.com/kvval/ProtadinAssistant. The repository root is the addon; `tools/`, notes and texts are left out of the zip by `.pkgmeta`, `dist/` is not in git at all.

1. Bump `## Version:` in `ProtadinAssistant.toc`.
2. Update `CHANGELOG.md` - the packager uploads it as the release changelog.
3. Commit and push to `main`.
4. Only when the author says "выкладывай": tag and push the tag, e.g. `git tag -a v1.0.4 -m "Protadin Assistant 1.0.4" && git push origin v1.0.4`.
5. GitHub Actions (`.github/workflows/release.yml`) runs the BigWigs packager: it builds the zip and uploads it to CurseForge (project 1826638, from `X-Curse-Project-ID` in the toc) and to GitHub Releases.

Needs the repository secret `CURSEFORGE` (a CurseForge API token, passed to the packager as CF_API_KEY, added by the author in GitHub: Settings → Secrets and variables → Actions).
Plain commits to `main` publish nothing. No alpha builds (the author doesn't want them). The CurseForge page description is not touched by the packager: paste `docs/curseforge-description.md` by hand when it changes.

To check what CurseForge really shows: `curl https://api.cfwidget.com/wow/addons/protadin-assistant` (JSON with files and description). The curseforge.com pages block scripts (403), and page fetchers may return stale copies.

GitHub repo settings worth having (author does them in the browser): About with description, website and topics; Wikis/Projects off; Issues on; PRs squash-only with auto-delete of head branches; no branch protection that requires PRs (pushes go straight to `main`). Only the owner can push or tag; outsiders can only fork, open PRs and issues.

## Open items

- [ ] In game: check 1.0.1-1.0.3 visuals (smooth growth, glowing "Suggest next") and the tidied layout after `/reload`.
- [ ] Run a dungeon and check there are no Lua errors (the 0.3.1 aura-restriction fix is untested in a real instance).
- [ ] Try clicks in game: minimap button, food, campfire kit.
- [ ] Get the **Camp Benefits** spell ID (`/protadin auras` at a camp). Until then the camp icon only works on English clients.
- [ ] Check "X has faded" on a natural expiry in normal play.
- [ ] CurseForge: delete / archive 0.3.0 and 0.3.1 if they are still there.
- [ ] Optional: GitHub About/topics and feature toggles (see Releasing); update `actions/checkout` to a Node 24 version when the deprecation warning starts to matter.
- Ideas, not planned: the same addon for other classes (warrior tank and shaman fit best).

## Working agreements

- Design is discussed first; code is written only after an explicit go-ahead.
- UI texts are short and clear for someone who just installed the addon. Show a mock-up or table before big UI changes.
- Public texts (CurseForge) are written in the author's own voice: direct, plain, hyphen dashes, no marketing gloss.
- Don't promise in public texts what hasn't been verified in game.
