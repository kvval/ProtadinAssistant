# Protadin Assistant 1.0.6

- **Pre-pull check.** On a ready check or when you enter a dungeon, one chat line tells what's missing: Aura, Blessing, Righteous Fury or Food. Nothing missing - nothing said.
- **No blinking when nothing can be fixed.** The buff row hides while you're dead, on a flight path or in a vehicle.
- **New commands.** `/protadin help` lists all commands. `/protadin forget` clears the learned priority.
- **Copyable debug.** `/protadin debug` opens a window you can copy from, with all buffs on you included.
- **Camp Benefits works in any client language.** The addon remembers its spell ID once it sees the buff.
- **Learned priority survives a language switch.** It's stored by spell ID now.
- **Easy to turn off.** The first priority change after login ends with a link to the options.

# Protadin Assistant 1.0.5

- The option is now called "Chat message when a buff fades", same wording as the chat messages.
- The changelog now keeps all previous versions.

# Protadin Assistant 1.0.4

- **Priority adapts by itself.** After a fight, once 25 new choices are in, the addon applies the order it learned from your play and tells in one chat line what changed, like "priority [Seal of Fury] <-> [Judgement]". You can turn it off ("Adapt automatically"). The old once-a-day message is gone.
- **Smarter learning.** Pressing exactly what "Suggest next" shows doesn't count, so the addon learns from you, not from itself. Old habits fade over time. A few lucky casts can't move a spell to the top anymore.
- **Situational spells stay where you put them.** Spells that are usable only now and then (Exorcism, Hammer of Wrath) are detected automatically and keep their place in your list.
- **Seal is part of the priority.** "Seal" is a line in "Rotation, by prio" (first by default). When no seal is up it's suggested like any other spell, with your most used seal. The separate small blinking seal icon is gone.
- **No mana - no suggestion.** Spells you can't pay for right now are skipped.
- **One icon, not two.** A spell that comes off cooldown turns into the "Suggest next" icon smoothly, no pop and no jump in size. The "Suggest next" icon is a bit bigger.
- **Spell links in chat.** Spells in addon messages are clickable links.

# Protadin Assistant 1.0.3

- Spells that are almost ready now grow smoothly during the last 1.5 s, and their border slowly turns gold. No more jump in size.
- The "Suggest next" icon is 20% bigger and has a pulsing glow, so it's easier to notice.
- Well Fed and Well-Rested icons are switched on or off at every login: on if you have XP food / the Cozy Sleeping Bag in your bags, off if you don't. If you switch one of them by hand in the options, the addon leaves it alone.
- New installs: the buff row sits on the right, under the minimap. The timeline is shown out of combat too, so you can see where it is (switch it to "Only during combat" in the options). One short welcome message in chat on the first login.

# Protadin Assistant 1.0.0

First stable release for WoW Forever.

- **Self-buff tracker:** aura, your own blessing, Righteous Fury, minimap tracking, Well Fed, Well-Rested (Cozy Sleeping Bag) and Camp Benefits. A buff that fades or the wrong one being active makes its icon blink and puts one message in chat. Click an icon to fix it: cast the buff, eat your XP food (the one you have the fewest of), use the sleeping bag or a campfire kit.
- **Cooldown timeline:** a 10-second track for your rotation, with countdowns and a seal tracker. It times cooldowns itself, because the client hides them in combat.
- **Suggest next:** a gold icon showing the best spell to cast now, picked by your priority list. Spells that don't fit the target (Exorcism on a beast, Hammer of Wrath above 20%) are skipped.
- **Priority from your play:** learns which spell you pick when several are ready, offers that order, and tells you in chat when your play style changes (at most once a day).
- **Minimap button** (LibDBIcon), an options panel, an alignment grid for moving frames, and an interface in 10 languages. Works with any client language.
