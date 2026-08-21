# Zhaohu's Decursive v11 Rebuild

## Build

**11.0.0 — Production Release**

The 11.0.0 production build promotes the alpha.23 native AuraSlot rendering fix and the complete v11 feature set to stable release. Native Blizzard API detection is the default and does not require DandersFrames. DandersFrames remains available as an optional integration/provider and is not removed or disabled by the production build.

v11 has one user-facing configuration system. The old AceConfig window is no longer registered or exposed. The proven v10.43 behavior engine remains underneath while backend modules are replaced incrementally, but every setting is presented through the v11 interface.

## Design rules

1. **One UI.** `/decursive`, `/dcr`, `/zd`, the options key binding, and the quick-access gesture all open the same v11 window.
2. **No feature removal.** Existing configuration behavior remains available through native v11 controls or the v11 option renderer.
3. **WoW 12.1 managed auras only.** No v11 module reintroduces legacy aura enumeration as a detection strategy.
4. **Secure actions stay secure.** MUF casting attributes are only rebuilt outside combat.
5. **Profiles and environments are different concepts.** AceDB profiles are user setups; Open World, Dungeon/Follower, Mythic+, Raid and PvP are behavior blocks inside each user profile.
6. **The v10.43 ZIP remains the behavioral reference.** v11 can be compared against it throughout the backend rewrite.

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
- Integrations
- 12.1 Status
- Diagnostics
- About

The General, MUF, Curing, Affliction Filters, Live List, Messages, Macro and About pages render the mature Decursive option model inside the modern window. Spells & Bindings is now a purpose-built native v11 page with dedicated cure-assignment, secure mouse-binding and custom spell/item controls. AceConfigDialog, AceConfigCmd, AceConfigRegistry, and AceGUI are no longer loaded; v11 uses its own lightweight refresh hook.



## Native Blizzard provider parity (Alpha 22)

DandersFrames is no longer required to receive the full v11 cure-feedback experience. Native mode now asks Blizzard's 12.1 managed AuraContainer API the same protected questions directly:

- one priority-filtered managed AuraSlot per configured cure priority for detection;
- one static priority-filtered managed carrier per priority for remaining-target cooldown overlays;
- one static priority-filtered managed carrier per priority for post-cure verification;
- range from the actual configured friendly cure spell through `C_Spell.IsSpellInRange()`, falling back to `UnitInRange()` when Blizzard provides no spell-range result.

Protected/secret aura presence and range booleans are never inspected in Lua. Managed AuraSlots drive the display, and secret range booleans are passed directly into Blizzard boolean-aware texture APIs. This gives native mode the same visible state contract as DandersFrames mode: Gray ready, Yellow out of range, Red failed/not-cleared for 3 seconds, Green cleared for 3 seconds, with Yellow always taking priority.

The only provider-specific behavior that cannot be identical without DandersFrames is DandersFrames' own custom frame ordering/profile context. Native mode therefore retains Decursive's roster ordering and environment behavior profiles.

## Automatic DandersFrames detection provider

v11.0.4 makes provider selection automatic and session-latched. If DandersFrames is enabled and its public AuraContainer API is available at startup, it is selected automatically; otherwise Decursive uses the native Blizzard-managed provider.

- **Disabled:** Zhaohu's Decursive uses its existing Blizzard-managed AuraContainer detection path.
- **DandersFrames available:** DandersFrames' public `AuraContainer` factory is the sole protected dispel-detection carrier. Decursive does not build or consult its native detector in that session.
- DandersFrames is used only to let Blizzard's protected aura engine decide whether a unit matches Decursive's configured dispel types/cure priority.
- Decursive still owns MUFs, spell selection, secure mouse bindings/clicks, priorities, cooldowns, range behavior, profiles and environment modes.
- DandersFrames frame styling, sorting, layout, click-casting and profile settings are not consumed.
- If DandersFrames is not installed, disabled, or its public provider API is unavailable at startup, Decursive selects the native Blizzard-managed provider instead.

The integration never reads protected aura names, dispel strings, visibility, duration or stacks back into Lua. DandersFrames' Blizzard-managed filter/slot state is used as the decision carrier.

## Native list management

Priority and Skip lists are managed directly in v11. Users can add the current target, move entries up/down/to the top/to the bottom, remove entries and clear a list without opening the old standalone list windows. The old XML frames remain hidden only because some backend list routines still reference them internally.

## Features retained

- Blizzard-managed 12.1 aura detection
- Secure Micro Unit Frames
- All healer/class/spec dispel capability logic
- Magic, Poison, Disease, Curse, Charm and bleed/custom handling
- Left/right/middle/Button4/Button5 + modifier bindings
- Custom spells, items and user macros
- Priority list and skip list
- Role/group ordering
- Priority colors and borders
- Cooldown overlays and countdowns
- Out-of-range appearance
- Secondary-affliction indication
- Raid, Mythic+, Dungeon/Follower, PvP and Open World behavior blocks
- AceDB profiles, AceDBOptions and LibDualSpec
- AceSerializer import/export
- Existing diagnostic and gameplay slash commands
- Live List behavior

## Primary commands

- `/decursive` — v11 settings
- `/dcr` — v11 settings
- `/zd` — v11 settings

There is no `/dcrclassic` command in Alpha 7.

## Next backend targets

1. Split the managed 12.1 aura engine into a dedicated Detection module.
2. Replace the legacy MUF renderer/layout implementation while preserving secure click attributes.
3. Move custom-spell/binding behavior out of the legacy option monolith into dedicated v11 modules.
4. Replace the legacy Live List implementation with a modern optional status panel while preserving feature parity.


## Alpha 14 UI architecture

Alpha 14 is the first full information-architecture pass across every v11 page. The window is resizable and uses grouped navigation. Deep option trees are no longer rendered as one continuous page: MUFs, Bleeds and Affliction Filters have dedicated subsections, while Cooldowns and Range/Visibility are separate pages. Line-of-sight feedback is event-driven from Decursive's own failed cleanse and remains independent of DandersFrames detection.
