# Zhaohu's Decursive v12.1.4-alpha.4

## Breaking: profile schema 6 resets all existing Decursive settings

- The first schema-6 startup intentionally removes all older Decursive
  SavedVariables and creates one protected Default Decursive Profile with five
  fresh Environment Profiles. Existing profiles, assignments, cure order,
  custom actions, bindings, MUF settings, colors, alerts, and compatibility
  namespaces do not carry forward. Reconfiguration is required.
- Later schema-6 startups preserve valid divergent environment data and repair
  only missing structure. Data written by a newer schema is detected before
  AceDB initialization; Decursive disables itself and leaves that data
  unchanged.

## Profile-first settings with five complete environments

- Every Decursive Profile now owns complete Open World, Party/Dungeon, Mythic+,
  Raid, and PvP configurations. Class- and specialization-specific cure order,
  custom actions, bindings, bleed settings, MUF behavior, alerts, visibility,
  performance settings, and other gameplay options follow the selected
  environment.
- Replaced the previous top command bar and catch-all workspace with a single
  task-oriented navigation tree. The persistent context bar distinguishes the
  Decursive Profile, the Environment Profile being edited, and the active
  runtime Environment Profile.
- Added explicit Edit, Copy From, and confirmed Reset to Defaults operations for
  each environment. Complete-profile and single-environment import/export
  preserve environment-owned settings while excluding runtime state.

## Cure bindings and affliction-priority colors

- Automatic and manual cure actions now resolve against the selected
  Environment Profile, including environment-owned class and specialization
  priorities.
- Added an Affliction Priority Colors editor that lists the assigned targeted
  cure, its gesture, covered dispel types, and color. Colors belong to cure
  priority slots rather than mouse gestures, so remapping a gesture does not
  move the action color.
- Native priority fills, secondary borders, and cooldown shades synchronize to
  the saved environment palette only at an accessible out-of-combat boundary.
  Blizzard remains the live protected-aura authority.

## Persistence hardening and verified runtime fixes

- Bounded profile imports before and after deserialization, rejecting malformed,
  truncated, oversized, excessively deep, cyclic, shared, multi-root, and
  unsupported-format payloads without partially changing Environment Profiles.
- Moved previously account-wide startup, MUF refresh, fallback scan, and bleed
  configuration into complete Environment Profiles and corrected their runtime
  readers and option handlers.
- Added regression coverage for destructive schema reset, schema-6 divergent
  reloads, future-schema immutability, profile transactions, environment
  routing, cure bindings, native priority visuals, and serialized ProfileIO
  rejection and rollback.

Debuff-type MUF coloring is not part of this release. MUF colors continue to
represent cure-action priority.
