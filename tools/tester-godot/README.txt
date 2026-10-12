LAST LANTERN - test version {VERSION} (Godot, Windows)
==================================================

Thank you for agreeing to try the game!

Last Lantern is an action roguelike: you descend into the Well with a lantern,
cross randomly generated rooms and face a warden at the end.

This is the new version of the game, rebuilt with the Godot engine. For now
it only contains the first depth, the Crypts, up to the first warden: after
defeating it and taking the trapdoor the "End of the demo" screen appears.
A run takes about 10-15 minutes.


STARTING THE GAME
-----------------

  1. Extract the whole zip into a folder (right click > "Extract all").
     Do not run it from inside the zip.
  2. Open the folder and double-click "Last Lantern.exe".
  3. The game is not digitally signed, so Windows may show
     "Windows protected your PC". Click "More info" and then
     "Run anyway".

Requires 64-bit Windows 10 or 11 with a graphics card that supports Vulkan
(almost all of those from the last ten years).

Fullscreen: F11 or Alt+Enter (also from the Options menu).


CONTROLS
--------

  W A S D ............ move
  Mouse .............. aim (or the arrow keys)
  Left click ......... shoot (or hold the arrow keys)
  Space / Shift ...... dash, you take no damage while dashing
  Right click / F .... Flare: wave of fire, uses oil
  1 2 3 4 ............ use consumables
  E .................. interact (chests, relics, merchant, trapdoor)
  Tab / M ............ map
  Esc / P ............ pause, equipment, stats

  The gamepad works: left stick to move, right stick to aim and shoot,
  A dash, B Flare, X interact, d-pad for consumables.


WHAT WE WANT TO KNOW
--------------------

  - Does the game start? Does it run smoothly? On what computer?
  - Difficulty: where you died, whether it felt frustrating or too easy.
  - If you also played the previous version: whether movement, shooting,
    light and sounds feel the same or different, and how.
  - Anything odd: stuck enemies, doors that do not open, cut-off text,
    annoying sounds, blank screens.

Fill in the FEEDBACK_FORM.txt file and send it back, even if only in part.


HOW TO REPORT A PROBLEM
-----------------------

  - Take a screenshot with Win+Shift+S.
  - Note the game "seed": it is shown in the pause menu (Esc) at the bottom
    left and on the end-of-run screen. With the seed we can recreate the
    same map.
  - If a red bar appears at the bottom saying "Error", take a photo of it:
    it is the most valuable report you can send us.
  - The game writes a log you can attach. Paste this path into the File
    Explorer address bar:
      %APPDATA%\Last Lantern Godot\logs
    and attach the godot.log file.


SAVES
-----

The game automatically saves statistics, unlocked lanterns and options
(not the run in progress), in:
  %APPDATA%\Last Lantern Godot
To start from scratch delete that folder. Saves from the previous version
are kept separate and are not touched.
