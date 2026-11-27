<!-- Summary (project settings): Self-learning ability timeline and buff watcher for Protection Paladins. -->
# Protadin Assistant

Protadin Assistant is an addon for Protection Paladins in WoW Forever. It shows your rotation on a timeline, tells you what to press next and learns your priority from the way you play. A second small frame watches your buffs.

Bugs and ideas: [GitHub issues](https://github.com/kvval/ProtadinAssistant/issues) or the comments here.

## Ability timeline

- **10 seconds ahead.** Your rotation spells and your seal slide to "now" with a countdown. Spells that are almost ready grow and turn gold.
- **What to press.** A gold icon shows the best spell right now, by your priority. Your seal is part of it. It skips what won't work: Exorcism on a beast, Hammer of Wrath above 20%, anything you have no mana for.
- **Learns your priority.** It looks at what you press when several spells are ready and adjusts the order after fights. One chat line says what changed, like "priority [Seal of Fury] <-> [Judgement]". Rare spells like Exorcism keep the place you gave them. You can turn this off.

## Buff watcher

- **One row:** aura, your blessing, Righteous Fury, tracking, Well Fed, Well-Rested, Camp Benefits.
- **Something faded or the wrong aura is up** - the icon blinks and you get one line in chat.
- **One click to fix.** Click the icon and it recasts the buff, eats your XP food (the stack you have the least of) or puts down the sleeping bag / campfire kit.

## Nothing extra

Works out of the box: it picks up your current aura, blessing and tracking by itself. Few options, all simple. No frameworks, no other addons needed.

## Why it works on Forever

The Forever client hides cooldowns from addons in combat. Protadin Assistant learns your real cooldowns out of combat (talents included) and counts them itself.

## Getting started

1. Install, log in on your paladin, play.
2. To move the frames: `/protadin unlock`, drag them (they snap to a grid and to the screen center), then `/protadin lock`.
3. Options: `/protadin` or right-click the minimap button.

## Commands

| Command | What it does |
|---|---|
| `/protadin` | open the options |
| `/protadin lock` | lock the frames |
| `/protadin unlock` | unlock the frames to move them |
| `/protadin reset` | put the frames back to their default places |

`/pda` is a short alias for `/protadin`. The minimap button works with ElvUI, button collectors and broker bars, and can be hidden.

## Troubleshooting

- **The frames are gone** - `/protadin reset`.
- **The suggested spell can't be used** - please post `/protadin debug` output in an issue.
- **The learned priority went wrong** - Options → Forget, and it starts learning again.

## Languages

Works with any client language. Interface: English, Русский, Deutsch, Français, Español, Português (BR), Italiano, 한국어, 简体中文, 繁體中文. Native speakers - corrections are welcome.

---

Embedded libraries: LibStub, CallbackHandler-1.0, LibDataBroker-1.1, LibDBIcon-1.0 (each one under its own license).
