# Zhaohu's Decursive (rebuild)

Private rebuild of Zhaohu's Decursive for WoW Retail 12.1.

## Slice 1

In-game AceConfig options menu only. No MUF squares, no click-to-cure runtime, no minimap.

- One addon folder: `Decursive`
- SavedVariables: `DecursiveRebuildDB` (does not read `DecursiveDB`)
- Five complete environments per logical profile: Open World, Dungeon, Mythic+, Raid, PvP
- Account / character / spec assignment with resolver: spec (if enabled and mapped) else character else account else Default
- Environment switching is manual in this slice
- Slash: `/dcr`  also listed under Esc > Options > AddOns

Live release repo `randylorfing/Decursive` is not this tree.
