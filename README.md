# Zhaohu's Decursive (ZDecursive)

ZDecursive is an independently maintained rebuild of Zhaohu's Decursive for
WoW Retail 12.1. The `v13.1.1-Alpha` line is packaged as one installable addon
folder and is prepared for publication from the `zdecursive` branch of
`randylorfing/Decursive`.

## Current slice

Priority and skip lists with slash commands (`/dcrpr`, `/dcrsk` and the alpha `add`/`show`/`clear` aliases). Skip-list units are never shown on MUFs or the live list. Priority order applies when MUF order is Decursive priority. Lists persist in `DecursiveRebuildDB` on the AceDB profile (not per environment).

- One addon folder: `ZDecursive`
- Interface: `120100`
- SavedVariables: `DecursiveRebuildDB` for settings and `ZDecursiveDiagnosticsDB` for bounded, sanitized diagnostics (does not read `DecursiveDB`)
- Six complete, independent packs per logical profile: Open World, Dungeon, Mythic+, Raid, PvP, and Solo
- Account / character / spec assignment with resolver: spec (if enabled and mapped) else character else account else Default
- Multiple mode routes only the five detected contexts; Solo mode always applies the Solo pack while detection remains diagnostic
- Actionable friendly cure types are Magic, Curse, Poison, and Disease; Enrage, Bleed, and legacy Charm flags are ignored
- Slash: `/dcr` also listed under Esc > Options > AddOns

AUTO click mode assigns up to three cures in priority order to the first free
gestures: Left, Right, Ctrl+Left, Ctrl+Right, then Shift+Left. Configured Target,
Focus, and Assist actions reserve their unmodified buttons. With the default
mouse settings, cures remain on Left, Right, and Ctrl+Left. The click-status
display shows the resolved assignments. Middle Target and Ctrl+Middle Focus
remain fixed.

MANUAL mode shows Left, Right, Button 4, and Button 5 spell menus even in Simple
view. Choose a known cure spell or a Target, Focus, or Assist action for each
button. Choosing a spell moves its saved assignment to that button and replaces
the button's previous assignment. An explicit Button 5 spell takes precedence
over the automatic PvP bandage. Automatic cure restores assignment from the
remaining cures; Button 5 also permits the bandage fallback. Changes belong to
the editing environment and become active when that environment is applied.

## Licensing and attribution

ZDecursive remains free software under the
[GNU General Public License version 3 or later](LICENSE). It is based on
Decursive, maintained by John Wellesz from 2006 through 2026, and preserves the
upstream attribution chain. The ZDecursive rebuild and its 2026 maintenance are
by Randy Lorfing. Bundled libraries retain their own license and public-domain
notices.
