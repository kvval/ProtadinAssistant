# Protadin Assistant

Small addon for Protection Paladins in WoW Forever. It keeps an eye on your buffs and your rotation, so you can just tank.

Two small frames on the screen. That's it.

## What it does

1. **Buffs.** Aura, your blessing, Righteous Fury, tracking, Well Fed, Well-Rested and Camp Benefits, all in one row. If something faded or the wrong aura is up, the icon blinks and you get one line in chat.
2. **One click to fix.** Click the icon and it recasts the buff, eats your XP food (the stack you have the least of) or puts down the sleeping bag / campfire kit.
3. **Cooldown timeline.** Shows 10 seconds ahead. Your rotation spells and your seal slide to "now" with a countdown.
4. **What to press.** A gold icon shows the best spell right now, by your priority. It skips spells that won't work, like Exorcism on a beast or Hammer of Wrath above 20%.
5. **Learns your style.** It looks at what you press when several spells are ready and adjusts your priority after fights. One short chat line tells what changed, like "Holy Shield <-> Judgement". Rare spells like Exorcism keep the place you gave them. Don't want it - turn it off in the options.

## Nothing extra

Works out of the box. It picks up your current aura, blessing and tracking by itself, so usually there's nothing to set up at all.

Few options, all simple - anything can be changed in a couple of clicks. No frameworks, no other addons needed.

## Why it works on Forever

The Forever client hides cooldowns from addons in combat. Protadin Assistant learns your real cooldowns out of combat (talents included) and counts them itself.

## How to start

1. Install, log in on your paladin, play.
2. To move the frames: type `/protadin unlock` and drag them. They snap to a grid and to the screen center. Then `/protadin lock`.
3. Options: `/protadin`, or right-click the minimap button.

## Commands

| Command | What it does |
|---|---|
| `/protadin` | open the options |
| `/protadin lock` | lock the frames |
| `/protadin unlock` | unlock the frames to move them (a grid appears) |
| `/protadin reset` | put the frames back to their default places |
| `/protadin auras` | list the buffs on you (handy for bug reports) |
| `/protadin debug` | diagnostic info (handy for bug reports) |

`/pda` is a short alias for `/protadin`.

The minimap button works with ElvUI, minimap button collectors and broker bars. Hover it to see what each click does. You can hide it in the options.

## Languages

It works with any client language. Interface: English, Русский, Deutsch, Français, Español, Português (BR), Italiano, 한국어, 简体中文, 繁體中文.

Native speakers - corrections are welcome.

---

Found a bug or have an idea? Write in the comments. Thanks!

Embedded libraries: LibStub, CallbackHandler-1.0, LibDataBroker-1.1, LibDBIcon-1.0 (each one under its own license).
