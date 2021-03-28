
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
- Implemented clientprefs, so you don’t have to turn distbug off/on all the time.
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
