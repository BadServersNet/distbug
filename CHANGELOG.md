
**v2.0.0 Changelog**

26.10.2022

- Code fully rewritten, as it's a port of my gcljs plugin from CS 1.6.
- Added hud strafe graph (!distbughudgraph).
- Added strafe graph to console output (!distbugstrafegraph, on by default).
- Added more jump types (ladderjumps, longjump-adjacent jumps, jumps with perfs).
- Renamed deviation to veer.
- Added jump beam and jump veer beam (!distbugbeam, !distbugveerbeam).
- Added advanced chat toggle (!distbugadvchat), to cut down on chat spam. Before, distbug would print 3 lines to chat, now !distbugadvchat usually only prints 2, and off prints 1 for reduced spam.
- Added jump direction to console output (except ladderjumps).
- Added Land Edge to console output (how far from the landing block edge you were when landing).
- Efficiency is now only based on mouse movement and is represented by percentages (100% is perfect efficiency, more, or less than that is bad).
- Tweaked distance bug fix for probably the 6th time.

Go to the [wiki page](https://bitbucket.org/GameChaos/distbug/wiki/Home) to read more about the new features!

**v1.2.2 Changelog**

18.01.2022

- Added "Jumpoff Angle".

Example: `... | OL: 15 | DA: 2 | Jumpoff Angle: -39.5�]`
This is the yaw of the view angle of when the player jumps, relative to the angle of the airpath.
Airpath angle is the angle that a line from the jumpoff position of the jump to the landing position points towards.
This jump was done with right pre and it shows that I was looking -39.5 degrees to the left of the direction of the airpath when I jumped.

**v1.2.1 Changelog**

28.03.2021

- Made distbug more accurate 2: electric boogaloo.
- Fixed incorrect air distance on failstats.

**v1.2.0 Changelog**

24.10.2020

Additions:

- Added a strafe efficiency stat.
- Added back printing stats to spectators.

Example: `-0.82 ( 0.59)` The first number is the average strafe efficiency, the second is peak efficiency. The closer to 0 the better. 0 is perfect efficiency. Negative values mean that you're strafing too slowly, positive means too fast.

**v1.1.0 Changelog**

27.05.2020

Additions:

- Added a Prestrafe and Max stat.
- Added a version command: `sm_distbugversion`

Fixes and changes:

- Rewrote everything.
- Changed "Air" distance stat to show the airpath straightness. 1.0 is completely straight, more than 1.0 is bad.

**v1.02 Changelog**

04.09.2019

Additions:

- Added air distance which measures the distance you would get with perfect airpath.
- Added average gain per strafe stat.
- Implemented clientprefs, so you don�t have to turn distbug off/on all the time.
- Added airpath deviation stat.
- Implemented late loading.

Fixes and changes:

- Fixed failstat distance being wrong.
- Fixed incorrect DA and OL variables being used for failstats.
- Cleaned up some crap.
- Optimised tracehulls.
- Changed airtime from % to ticks.
- Some chat formatting tweaks.

**v1.01 Changelog**

- Fixed error log spam
- Fixed bug with over 31 strafes.

**v1.0 Changelog**

- Fixed w release showing badly.
- Fixed incorrect sync.
- Lots of under the hood changes, lots.
- More stuff that I've completely forgotten.
