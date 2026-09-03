# Zhaohu's Decursive (ZDecursive)

ZDecursive is an independently maintained rebuild of Zhaohu's Decursive for
WoW Retail 12.1. The `v13.1.0-alpha` line is packaged as one installable addon
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

## Licensing and attribution

ZDecursive remains free software under the
[GNU General Public License version 3 or later](LICENSE). It is based on
Decursive, maintained by John Wellesz from 2006 through 2026, and preserves the
upstream attribution chain. The ZDecursive rebuild and its 2026 maintenance are
by Randy Lorfing. Bundled libraries retain their own license and public-domain
notices.
