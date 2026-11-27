# Protadin Assistant

Small addon for Protection Paladins in WoW Forever. It keeps an eye on your buffs and your rotation, so you can just tank.

Two small frames on the screen. That's it.

## What it does

1. **Buffs.** Aura, your blessing, Righteous Fury, tracking, Well Fed, Well-Rested and Camp Benefits, all in one row. If something faded or the wrong aura is up, the icon blinks and you get one line in chat.
2. **One click to fix.** Click the icon and it recasts the buff, eats your XP food (the stack you have the least of) or puts down the sleeping bag / campfire kit.
3. **Cooldown timeline.** Shows 10 seconds ahead. Your rotation spells and your seal slide to "now" with a countdown.
4. **What to press.** A gold icon shows the best spell right now, by your priority. It skips spells that won't work, like Exorcism on a beast or Hammer of Wrath above 20%.
5. **Learns your style.** It looks at what you press when several spells are ready and suggests your own priority. Apply it with one click or ignore it. Nothing changes by itself.

## Nothing extra

Works out of the box. It picks up your current aura, blessing and tracking by itself, so usually there's nothing to set up at all.

Few options, all simple - anything can be changed in a couple of clicks. No frameworks, no other addons needed.

## Why it works on Forever

The Forever client hides cooldowns from addons in combat. Protadin Assistant learns your real cooldowns out of combat (talents included) and counts them itself.

## How to start

1. Install, log in on your paladin, play.
2. To move the frames: Shift + left-click the minimap button and drag them. They snap to a grid and to the screen center. Shift + left-click again to lock them.
3. Options: right-click the minimap button, or type `/protadin`.

## Minimap button

| Click | Action |
|---|---|
| Left-click | apply the priority learned from your play |
| Right-click | options |
| Shift + left-click | lock / unlock frames |
| Shift + right-click | reset positions |
| Ctrl + left-click | list buffs on you |
| Ctrl + right-click | debug info |

It works with ElvUI, minimap button collectors and broker bars. You can hide it in the options.

## Languages

It works with any client language. Interface: English, Русский, Deutsch, Français, Español, Português (BR), Italiano, 한국어, 简体中文, 繁體中文.

Native speakers - corrections are welcome.

---

Found a bug or have an idea? Write in the comments. Thanks!

Embedded libraries: LibStub, CallbackHandler-1.0, LibDataBroker-1.1, LibDBIcon-1.0 (each one under its own license).
