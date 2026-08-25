# Zhaohu's Decursive v11 Rebuild

## Build

**11.0.0 — Production Release**

The 11.0.0 production build promotes the alpha.23 native AuraSlot rendering fix and the complete v11 feature set to stable release. Native Blizzard API detection is the only dispel-detection provider.

v11 has one user-facing configuration system. The old AceConfig window is no longer registered or exposed. The proven v10.43 behavior engine remains underneath while backend modules are replaced incrementally, but every setting is presented through the v11 interface.

## Design rules

1. **One UI.** `/decursive`, `/dcr`, `/zd`, the options key binding, and the quick-access gesture all open the same v11 window (loaded on demand via `Decursive_Options`).
2. **No feature removal.** Existing configuration behavior remains available through native v11 controls or the v11 option renderer.
3. **WoW 12.1 managed auras only.** No v11 module reintroduces legacy aura enumeration as a detection strategy.
4. **Secure actions stay secure.** MUF casting attributes are only rebuilt outside combat.
5. **Profiles and environments are different concepts.** AceDB profiles are user setups; Open World, Dungeon/Follower, Mythic+, Raid and PvP are behavior blocks inside each user profile.
6. **The v10.43 ZIP remains the behavioral reference.** v11 can be compared against it throughout the backend rewrite.
7. **Lean combat path.** Settings UI, Ace option tree, and Test Mode live in LoadOnDemand `Decursive_Options`. SavedVariables stay on the main `Decursive` addon only.

## Global settings search

Alpha 8 adds a global search field to the v11 header. It searches page names, native v11 controls, and the mature Decursive option model. Results show the destination page and setting context; clicking a result opens the correct v11 page. Search never reads protected aura data and does not alter combat behavior.

## v11 settings pages

- Dashboard
- General
- Micro Unit Frames
- Curing
- Cooldowns & Range
- Spells & Bindings
- Affliction Filters
- Live List
- Messages
- Macro
- Profiles & Modes
- Import / Export
- Priority & Skip
- Detection
- 12.1 Status
- Diagnostics
- About

The General, MUF, Curing, Affliction Filters, Live List, Messages, Macro and About pages render the mature Decursive option model inside the modern window. Spells & Bindings is now a purpose-built native v11 page with dedicated cure-assignment, secure mouse-binding and custom spell/item controls. AceConfigDialog, AceConfigCmd, AceConfigRegistry, and AceGUI are no longer loaded; v11 uses its own lightweight refresh hook.

## Native Blizzard provider

Native mode asks Blizzard's 12.1 managed AuraContainer API the protected questions directly:

- one priority-filtered managed AuraSlot per configured cure priority for detection;
- one static priority-filtered managed carrier per priority for remaining-target cooldown overlays;
- one static priority-filtered managed carrier per priority for post-cure verification;
- range from the actual configured friendly cure spell through `C_Spell.IsSpellInRange()`, falling back to `UnitInRange()` when Blizzard provides no spell-range result.

Protected/secret aura presence and range booleans are never inspected in Lua. Managed AuraSlots drive the display, and secret range booleans are passed directly into Blizzard boolean-aware texture APIs. Visible state contract: Gray ready, Yellow out of range, Red failed/not-cleared for 3 seconds, Green cleared for 3 seconds, with Yellow always taking priority.

Decursive retains its own roster ordering and environment behavior profiles (Open World / Dungeon / Mythic+ / Raid / PvP).

## Native list management

Priority and Skip lists are managed directly in v11. Users can add the current target, move entries up/down/to the top/to the bottom, remove entries and clear a list without opening the old standalone list windows. The old XML frames remain hidden only because some backend list routines still reference them internally.

## Features retained

See CHANGELOG.md for the full historical release notes. Current product boundary: Decursive is native Blizzard-managed 12.1 detection only.
