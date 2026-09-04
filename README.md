# Distbug

Distbug is a SourceMod plugin for Counter-Strike: Global Offensive that fixes the long-jump distance bug and reports detailed jump and strafe statistics.

## Features

- Measures long jumps, weird jumps, ladder jumps, bunnyhops, and crouched bunnyhops.
- Reports distance, edge, prestrafe, maximum speed, synchronization, airtime, overlap, dead air, veer, and strafe efficiency.
- Provides chat, console, HUD graph, jump beam, and veer beam output.
- Saves each player's display preferences with SourceMod client preferences.

## Installation

Download the latest release archive and extract it into the game server's `csgo` directory. The archive places the compiled plugin in `addons/sourcemod/plugins` and the source and bundled includes in `addons/sourcemod/scripting`.

SourceMod creates `cfg/sourcemod/distbugfix.cfg` after the plugin first loads. Use that file to adjust the supported distance ranges for each jump type.

## Commands

| Command | Description |
| --- | --- |
| `sm_distbug` | Toggle Distbug. |
| `sm_distbugversion` | Print the installed version. |
| `sm_distbugbeam` | Toggle the jump beam. |
| `sm_distbugveerbeam` | Toggle the veer beam. |
| `sm_distbughudgraph` | Toggle the HUD strafe graph. |
| `sm_strafestats` | Toggle detailed strafe statistics. |
| `sm_distbugstrafegraph` | Toggle the console strafe graph. |
| `sm_distbugadvchat` | Toggle advanced chat statistics. |
| `sm_distbughelp` | Print the command list to the console. |

## Building

Compile `distbugfix.sp` with SourceMod 1.11 and add `include` to the compiler's include search path. All non-SourceMod includes required to build the plugin are bundled in this repository.

## Releases

Version tags follow Semantic Versioning. See [CHANGELOG.md](CHANGELOG.md) for the original release notes.

## License

This project is licensed under the GNU General Public License v3.0. See [LICENSE](LICENSE).
