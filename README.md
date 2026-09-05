# Zhaohu's Decursive (ZDecursive)

ZDecursive is an independently maintained rebuild of Zhaohu's Decursive for
WoW Retail 12.1. Production release **v13.1.2** provides clickable Micro Unit
Frames (MUFs), native aura presentation, configurable cure actions, environment
profiles, and diagnostics. Source and releases are maintained at
[`randylorfing/Decursive`](https://github.com/randylorfing/Decursive).

## Installation and setup

**Upgrading from the older two-folder Zhaohu's Decursive build:** the addon now
installs as `ZDecursive`, replacing this project's `Decursive` and
`Decursive_Options` folders. Exit WoW completely before switching. After the
CurseForge update, check `Interface/AddOns`; if that old copy's two folders
remain, remove them before launching WoW. Do not run both builds together.
For a manual installation, remove that old copy before extracting this release.
Keep your `WTF` folder and any settings backups. Folder cleanup does not import
settings: this rebuild uses `DecursiveRebuildDB`, so legacy `DecursiveDB`
profiles are not migrated. Existing **ZDecursive** settings are retained.

CurseForge project ID remains **1659159**. Automatic cleanup across folder-name
changes has not been verified; the upgrade instructions above also cover
manually installed or locally modified copies.

If the rebuild detects this project's old addon running alongside it, it opens
a copyable upgrade warning outside combat. The warning does not disable addons,
delete files, or change saved settings.

- One addon folder: `ZDecursive`
- Interface: `120100`
- SavedVariables: `DecursiveRebuildDB` for settings and `ZDecursiveDiagnosticsDB` for bounded, sanitized diagnostics (does not read `DecursiveDB`)

Extract the release into the Retail `Interface/AddOns` directory so that the TOC
is at `Interface/AddOns/ZDecursive/ZDecursive.toc`, then restart the client or
use `/reload` after an update. Open settings with `/dcr`, `/zd`, or
`/zdecursive`, or through Esc > Options > AddOns.

The redesigned menu groups settings into **Frames, Roster, Actions, Colors,
Alerts, Supplies, and Advanced**, with Status, Decursive Profiles, and
Diagnostics alongside them. Settings have descriptions, search, and a frame
layout preview. The header distinguishes the environment being edited from
the environment currently applied. Options and protected configuration changes
are guarded during combat.

## Profiles, frames, and actions

- Each logical profile contains six environment packs: Open World, Dungeon, Mythic+, Raid, PvP, and Solo. Multiple mode follows the detected environment; Solo mode applies the Solo pack. Account, character, and optional specialization assignments select the logical profile. Shared orientation and priority/skip lists remain profile-wide.
- AUTO assigns available cures in priority order. MANUAL and explicit mouse/modifier assignments let you choose cures, utility actions, or a selected bandage. Optional keyboard mouseover casting has its own controls. Editing an inactive environment takes effect when that environment is applied.
- Native friendly dispel presentation covers Magic, Curse, Poison, and Disease. Aura tooltips use Blizzard's native display interfaces, with improvements to poison hover behavior and cooldown readiness/recovery.
- Automatic roster order follows DandersFrames when available and falls back to group order. Explicit Group, Decursive priority, or DandersFrames choices remain selected per environment. Priority and skip lists are available through `/dcrpr` and `/dcrsk`; skipped units are excluded from MUFs and the live list.
- Party and raid frame sizes remain configurable. Pet MUFs use **80% of player-frame size** and share the group scale, matching the original Decursive proportion.

## Alerts and supplies

- A confirmed out-of-range dispel attempt can show **OUT OF RANGE**. The message uses the configured alert appearance, expands or wraps to fit, and follows the text and failure-sound controls. Soul Link battle-rez warnings are attributed separately from living-target dispel attempts.
- **Colors > Range** controls whole-MUF dimming. Out-of-range frames default to **50% brightness**, including affliction colors, borders, icons, status lights, and cooldown numbers. Unknown range keeps normal brightness. One brightness control applies to afflicted and unafflicted frames; the underlying unafflicted range color remains configurable.
- Countdown numbers are enabled by default, with cooldown overlay darkness at **0**. Landing DISPEL text, successful-dispel text, Soul Link warnings, and sounds have their own controls.
- **Supplies** lists carried bandages, including tailoring ranks, with counts, item tooltips, selection, and click assignment. Automatic selection uses usable item level and item ID; a specific selection stays selected when empty. Blizzard determines item eligibility and PvP restrictions when you click.
- An optional low-stock reminder is **off by default**, has a configurable threshold, and appears outside combat. Soul Link fallback and its battle-rez warning have separate settings.

## Performance and troubleshooting

This release reduces repeated layout, secure-binding, and visual updates,
combines related event bursts, and reuses roster information within each engine
update. Failed profile or environment applications retain recovery state and
use bounded retries. These changes reduce redundant work without promising a
particular FPS improvement.

Use `/zdiag` for the copyable diagnostics report. Automatic aura-event tracing
is enabled by default per environment and can be toggled in Advanced or paused
with `/zdiag auraoff`. Ordinary runtime notices append to the bounded report
without opening it over gameplay.

Optional performance captures are available in Diagnostics or through
`/zdperf 15` and `/zdperf 30`. Start outside combat; a capture may continue
during combat. Use `/zdperf stop` to finish early and `/zdperf report` to copy
the result. Capture is off by default and reports timed addon-owned functions,
including the build version, rather than total addon CPU or FPS.

## Licensing and attribution

ZDecursive remains free software under the
[GNU General Public License version 3 or later](LICENSE). It is based on
Decursive, maintained by John Wellesz from 2006 through 2026, and preserves the
upstream attribution chain. The ZDecursive rebuild and its 2026 maintenance are
by Randy Lorfing. Bundled libraries retain their own license and public-domain
notices.
