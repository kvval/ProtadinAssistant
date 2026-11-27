<!-- Summary (project settings): Self-learning ability timeline and buff watcher for Protection Paladins. -->
# Protadin Assistant

Self-learning ability timeline and buff watcher for Protection Paladins.
Works out of the box. No other addons needed.

## Ability timeline

- Your rotation and Seal on a 10-second timeline.
- Next spell, based on YOUR play style.
- Skips what you can't cast: wrong target, no mana, Hammer of Wrath above 20%.
- Learns as you fight. Changes show up in chat.

## Buff watcher

- Aura, Blessing, Righteous Fury, Tracking, Food, Sleeping Bag, Campfire - in one row.
- Warns you when a buff is missing or the wrong one is up.
- One click puts it back.

## Why it works on Forever

The client hides cooldowns from addons in combat. The addon learns them out of combat and counts them itself.

## Commands

| Command | What it does |
|---|---|
| `/protadin` | options |
| `/protadin lock` / `unlock` | lock / move the frames |
| `/protadin reset` | frames back to default places |

`/pda` works too. Right-click the minimap button for options.

## Troubleshooting

- Frames gone - `/protadin reset`.
- Wrong suggestion - post `/protadin debug` output in the comments.
- Learned priority went wrong - Options → Forget.

## Languages

Any client language. Interface in 10 languages; native speakers' corrections are welcome.

---

Embedded libraries: LibStub, CallbackHandler-1.0, LibDataBroker-1.1, LibDBIcon-1.0 (each under its own license).
