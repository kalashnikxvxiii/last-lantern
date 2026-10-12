# Playtest checklist (Godot version)

To run side by side with the JS version (`index.html`). Mark each item ✅ or note the difference you found.

Items already checked were verified during development with automated tests (`tools/test.sh`) or with screenshots compared against the JS version. The others need to be played with keyboard, mouse, gamepad and audio, and checked by hand.

## Controls
- [ ] WASD, aim with the mouse, shoot by holding the left button
- [ ] Arrow keys to aim and shoot
- [ ] Space and Shift to dash; dash charges under the feet
- [ ] Flare with right click and F; "Not enough oil"
- [ ] Consumables 1–4; E to interact; Tab/M map; Esc/P pause
- [ ] Gamepad: sticks, A, B, X, Y, LB, RB, RT, d-pad, Start, Back
- [ ] Switching mouse ↔ gamepad mid-run (aim and key icons)

## Feel
- [ ] Movement and dash speed identical
- [x] Fire rate, projectile speed and range identical
- [ ] Corner sliding at doors
- [ ] Hitstop, shake, flash on hits taken and on crits

## Light and oil
- [ ] Light radius shrinking with the oil
- [ ] Darker room without oil in combat, DARK label
- [ ] Cleared rooms brighter
- [ ] Braziers, coins and projectiles casting light; red eyes in the dark

## Rooms and content
- [x] Starting room with the tutorial on the floor
- [x] Normal rooms with one or two waves, doors closing and reopening
- [x] Treasure: two relics, only one can be taken
- [ ] Merchant: prices, lines, purchases, "Bag full", "You are already at full strength"
- [x] Shrines: blood, fortune, fountain, idol
- [x] Secret room opened with a bomb (cracks in the wall)
- [ ] Cracked rocks, exploding barrels, urns, spikes
- [ ] Rat, bat, skeleton, skull, ghoul; elite champions with a colored outline

## Progression
- [x] Level-ups: perk choice in a safe room, reroll with R
- [x] Perks, relics and curses applied (stats panel in the pause menu)
- [x] The Bone Warden: two phases, patterns, death, trapdoor
- [ ] End of the demo with the summary
- [x] Pilgrim's Lantern unlocked after the warden
- [ ] Death, game over with "Killed by", abandoning from the pause menu

## Saving and options
- [ ] Music and effects volume, shake, damage numbers, fullscreen (also F11 and Alt+Enter)
- [ ] Archive updated between sessions (close and reopen)
- [ ] Auto-pause when the window loses focus

## Audio
- [ ] Title and Crypt music, intensity rising in combat and at the boss
- [ ] All sound effects present and recognizable
