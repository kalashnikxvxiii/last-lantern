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
- [ ] The 23 enemies of the five depths (each depth has its own biome look); elite champions with a colored outline
- [ ] Fungal Caves, Sunken Foundry, Flooded Abyss, Heart of the Well: floors, walls, decorations, music

## Progression
- [x] Level-ups: perk choice in a safe room, reroll with R
- [x] Perks, relics and curses applied (stats panel in the pause menu)
- [x] The Bone Warden: two phases, patterns, death, trapdoor
- [ ] Mother Mycelium, The Forger, The Voice of the Abyss (beams, wall of shots, teleport), The Light Devourer (three phases, drain, dark pulse)
- [ ] Descending through all five depths; depth 6 and beyond (Infinite Abyss) with the cycle of biomes and growing difficulty
- [ ] Ardor levels 1-5 after a victory
- [ ] Victory screen with the summary, Ardor unlocked, Infinite Abyss after the last warden
- [x] Pilgrim's Lantern unlocked after the warden
- [ ] Death, game over with "Killed by", abandoning from the pause menu

## Saving and options
- [ ] Music and effects volume, shake, damage numbers, fullscreen (also F11 and Alt+Enter)
- [ ] Options tabs: Q/TAB, PageUp/PageDown, LB/RB, the mouse and the tab row all switch tab
- [ ] Display tab: window mode (also exclusive), resolution only in a window, VSync, FPS limit, pixel-perfect scaling, all kept after a restart
- [ ] Picture tab: brightness, contrast and saturation on the game and the HUD, CRT filter on every screen, FPS counter
- [ ] Quality (Low, Medium, High, Ultra): sets bloom, shadows, ambient occlusion and particles together; a hand-made mix shows Custom; first boot picks High on a dedicated card, Medium on an integrated one
- [ ] Bloom: Off, Low, Medium, High in game and on the title; Off gives the original picture; the HUD and the in-game panels never glow
- [ ] Shadows (Off, Low, High): rocks, walls and barrels cast soft shadows from the lantern and the braziers, also after a barrel or rock breaks; Off gives the original lighting
- [ ] Ambient occlusion: the floor darkens next to walls and rocks
- [ ] Particles (Off, Low, High): ambient motes of each biome (crypt dust, fungal spores, forge embers and ash, abyss bubbles, violet motes in the heart), sparks from fire, crits, explosions and flares; Off removes both
- [ ] Color grading: each depth has its own subtle tint; Off gives the original colors
- [ ] Screen effects: shockwaves and explosions bend the picture along their front, chromatic aberration on shakes and hits; Off removes both
- [ ] Archive updated between sessions (close and reopen)
- [ ] Auto-pause when the window loses focus

## Audio
- [ ] Title music and the music of each depth, intensity rising in combat and at the boss
- [ ] All sound effects present and recognizable
