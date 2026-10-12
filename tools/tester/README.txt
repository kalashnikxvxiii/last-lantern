LAST LANTERN - test version {VERSION}
==================================================

Thank you for agreeing to try the game!

Last Lantern is an action roguelike: you descend into the Well with a lantern,
cross five randomly generated depths and face a warden at the end of each one.
When you die you start over, but you unlock new lanterns.
A full run takes about 30-45 minutes.


STARTING THE GAME
-----------------

Windows
  1. Extract the whole zip into a folder (right click > "Extract all").
     Do not run it from inside the zip.
  2. Open the folder and double-click "Last Lantern.exe".
  3. The game is not digitally signed, so Windows may show
     "Windows protected your PC". Click "More info" and then
     "Run anyway".

Linux
  1. Extract the archive:   tar -xzf LastLantern-*-Linux.tar.gz
  2. Enter the folder and start it:   ./start.sh
  3. Optional: ./install-shortcut.sh adds the game to the applications
     menu.

Browser version (any system)
  Open "Last Lantern.html" with Firefox, Chrome or Edge. Useful if the
  desktop version does not start. Progress is saved in the browser.

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
  - Whether it was clear what to do: oil, Flare, perks, keys, bombs.
  - Anything odd: stuck enemies, doors that do not open, cut-off text,
    annoying sounds, blank screens.
  - What you liked most and what you liked least.

Fill in the FEEDBACK_FORM.txt file and send it back, even if only in part.


HOW TO REPORT A PROBLEM
-----------------------

  - Take a screenshot (on Windows: Win+Shift+S; on Linux: Print Screen).
  - Note the game "seed": it is shown in the pause menu (Esc) at the bottom
    left and on the end-of-run screen. With the seed we can recreate the
    same map.
  - If a red bar appears saying "Error", take a photo of it: it is the most
    valuable report you can send us.
  - The desktop version writes errors to a file you can attach:
      Windows:  %APPDATA%\Last Lantern\error-log.txt
                (paste the path into the File Explorer address bar)
      Linux:    ~/.config/Last Lantern/error-log.txt


SAVES
-----

The game automatically saves statistics, unlocked lanterns and options
(not the run in progress). To start from scratch delete the folder:
  Windows:  %APPDATA%\Last Lantern
  Linux:    ~/.config/Last Lantern


KNOWN ISSUES
------------

  - On Linux, if ./start.sh opens no window, try the browser version and
    tell us which distribution you use.
  - On some laptops with two graphics cards the game may start on the
    integrated one: that is fine, it is lightweight.
