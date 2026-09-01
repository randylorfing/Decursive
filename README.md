# Zhaohu's Decursive (rebuild)

Private rebuild of Zhaohu's Decursive for WoW Retail 12.1.

## Current slice

Priority and skip lists with slash commands (`/dcrpr`, `/dcrsk` and the alpha `add`/`show`/`clear` aliases). Skip-list units are never shown on MUFs or the live list. Priority order applies when MUF order is Decursive priority. Lists persist in `DecursiveRebuildDB` on the AceDB profile (not per environment).

- One addon folder: `Decursive`
- SavedVariables: `DecursiveRebuildDB` (does not read `DecursiveDB`)
- Five complete environments per logical profile: Open World, Dungeon, Mythic+, Raid, PvP
- Account / character / spec assignment with resolver: spec (if enabled and mapped) else character else account else Default
- Environment switching is manual
- Slash: `/dcr` also listed under Esc > Options > AddOns

Live release repo `randylorfing/Decursive` is not this tree.
