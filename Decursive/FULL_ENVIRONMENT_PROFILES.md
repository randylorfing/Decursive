# Full Environment Profiles

Decursive profile schema 4 gives every logical profile five complete settings
variants: Open World, Party / Dungeon, Mythic+, Raid, and PvP.

Every profile-backed setting is stored independently in each variant. This
includes MUF geometry, layout, colors, pet handling, alerts, visibility,
cooldowns, automatic/manual cure-binding policy, stable manual action mappings,
legacy click priorities, and the optional Decursive macro key. The active
AceDB profile is always the effective runtime variant or the explicit
out-of-combat edit preview, so mature and V13 settings pages use the same table
without a setting allow-list.

## Resolution

The logical profile is resolved first:

1. Current specialization assignment, when enabled
2. Character assignment
3. Account default
4. Protected Default profile

The environment is resolved second. A manual override wins. Automatic mode
uses PvP or arena, Raid, active Mythic+, Party / Dungeon, then Open World
precedence.

Environment and specialization transitions switch the full AceDB variant
outside combat. A transition detected during combat is queued and applied once
after `PLAYER_REGEN_ENABLED`.

## Editing and preview

Opening the V13 settings window enters an explicit edit preview. The persistent
header shows the logical profile, edited environment, and actual runtime
environment on every page. The header context is clickable and cycles the edit
environment without leaving the current page. Choosing an edit environment switches the complete
AceDB profile outside combat, so all V13 and legacy-routed controls edit that
variant. Closing settings restores the automatically or manually resolved
runtime variant. Editing and profile mutations are locked during combat.

The Environment Profiles page can copy one complete variant into another or
reset one variant to its shipped preset. The Decursive Profiles page performs
logical create, copy, reset, delete, import, and export across all five variants
transactionally.

## Migration and storage growth

Schema 3 and older catalogs retain stable logical IDs, display names, ordering,
offline character assignments, and LibDualSpec mappings. Migration never moves
or deletes the original AceDB profile table. It creates each full variant from
the original complete profile, then overlays the corresponding legacy nested
environment block. Legacy global click priorities and macro binding are copied
into every first-generation variant without modifying the global originals.
Stock legacy mouse assignments migrate to Simple Two-Button automatic mode.
Customized global or profile assignments migrate to Manual Cure Bindings with
their priority gestures retained until the corresponding stable spell/item
action identity is discovered for a specialization.

Migration is idempotent. Missing variants are repaired individually, and the
migration is marked complete only after all catalog records and variant tables
validate. Data written by a future schema is read-only.

Full variants intentionally increase SavedVariables profile storage to roughly
five times the former per-profile size. The exact increase depends on table
defaults and user customization. The 50-profile limit counts logical profiles,
not hidden AceDB variant keys.

## Scope audit

The following are intentionally not environment variants because they are not
AceDB profile scope:

- `global`: diagnostics, version state, learned protected-aura IDs, bleed
  discovery cache, and scan scheduling/performance controls
- `class`: cure order and custom spell definitions shared by the class or
  specialization
- `locale`: localized bleed-effect keywords
- logical-manager metadata: stable IDs, ordering, assignments, activation mode,
  and the remembered edit environment

Import/export never overwrites those scopes. Format 2 labels its payload as a
complete logical profile or a single environment variant; the V13 Profiles page
uses the complete logical contract.

See [README.md](README.md), [CHANGELOG.md](CHANGELOG.md), and
[Dcr_ProfileManager.lua](Dcr_ProfileManager.lua).
