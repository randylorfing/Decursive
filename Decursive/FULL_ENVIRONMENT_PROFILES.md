# Full Environment Profiles

Profile schema 6 treats a **Decursive Profile** as a named container. Each
container owns exactly five complete **Environment Profiles**: Open World,
Party / Dungeon, Mythic+, Raid, and PvP. Selecting an Environment Profile
switches the whole Decursive configuration; it is not a visual preset or a
small override block.

Every reasonably environment-dependent user setting belongs to the selected
Environment Profile. That includes MUF units, pet handling, visibility, layout,
colors, priority and skip lists, alerts, range and line-of-sight feedback,
cooldowns, cure order, specialization-specific priorities, custom spells and
actions, automatic/manual click policy, mouse mappings, macro behavior, bleed
rules, and profile performance tuning. The active AceDB profile is always the
runtime Environment Profile or the explicit out-of-combat settings preview, so
V13 and compatibility-routed controls read and write the same complete table.

## Resolution

Decursive resolves the container first:

1. Current specialization assignment, when enabled
2. Character assignment
3. Account-wide default Decursive Profile
4. Protected Default profile

It then resolves the Environment Profile. A manual activation choice wins.
Automatic activation uses PvP or arena, Raid, active Mythic+, Party / Dungeon,
then Open World precedence. Environment and specialization transitions switch
the complete AceDB profile outside combat; an in-combat transition is queued
until `PLAYER_REGEN_ENABLED`.

The account-wide default is selection metadata only. It chooses a Decursive
Profile when no character or specialization assignment applies; it does not
store or merge gameplay settings.

## Editing

The Profiles page separates container administration from environment editing:

- **Decursive Profiles** creates, copies, renames, resets, deletes, imports, and
  exports the named container and all five Environment Profiles.
- **Environment Profiles** shows all five configurations at once. Select one,
  then use **Edit Selected Environment Profile**, **Copy Into Selected**, or the
  confirmed **Reset Selected to Defaults** action.

Edit opens **Environment Profile Overview**. The left task tree then exposes
MUF Setup, Cures & Mouse Bindings, Alerts & Feedback, and Advanced & Diagnostics
inside that selected Environment Profile. The persistent context bar always
labels **Decursive Profile**, **Editing Environment Profile**, and
**Active Environment Profile**. Closing settings restores the resolved runtime
environment. Structural profile changes and preview switching are locked in
combat.

## Schema-6 reset and repair

Schema 6 is an intentional clean break. On the first startup with nil,
malformed, or schema-2/4/5 data, Decursive clears the entire `DecursiveDB`
table in place before AceDB loads. No old profile, class/spec cure order,
custom action, environment variant, assignment, color, binding, MUF/layout,
alert, global/character/realm value, profile key, LibDualSpec namespace,
manager marker, cache, or alias is retained. Decursive creates one protected
Default profile with five fresh complete Environment Profiles and records only
the schema-6 reset marker and current manager metadata. Users must reconfigure.

Subsequent schema-6 startup preserves valid Environment Profile tables and
repairs only missing or malformed structure. It does not replace valid values
or collapse divergence between environments. A schema newer than 6 is detected
before AceDB/default materialization. In that case Decursive shows one popup,
disables configuration and runtime registration, and performs no SavedVariables
writes. Full variants intentionally increase storage; the 50-profile limit
counts Decursive Profile containers, not hidden AceDB storage keys.

## Non-environment scope rationale

Only data that should never change with gameplay context remains outside an
Environment Profile:

- **Logical-manager metadata:** stable IDs, display names, deterministic order,
  account/character/specialization assignments, activation mode, remembered edit
  selection, the schema/reset marker, and resolver compatibility state.
- **Locale:** localized bleed-effect keywords, because language selection is a
  client installation property rather than encounter configuration.
- **Diagnostics and version state:** debug/error reports, build expiration and
  update notices, because they describe the addon installation.
- **Caches and static capability state:** learned protected-aura IDs, runtime
  resolver caches, counters, and shipped spell/dispel capability tables. They
  are derived data, not user-authored gameplay configuration.

There are no active user-facing cure, custom-action, layout, alert, visibility,
cooldown, pet, priority, or binding settings in shared global/class scope.

## Copy, reset, and transfer

Environment copy and reset replace exactly one complete Environment Profile.
Container copy and reset operate across all five transactionally. Format-2
import/export supports either one Environment Profile or the entire Decursive
Profile. Class/spec cure settings are included; runtime callbacks are removed
before serialization. Assignments, locale, diagnostics, version state, and
caches are not imported.

Affliction priority colors remain in each variant's existing `MF_colors`
table. The canonical editor at **MUF Setup > Layout & Appearance > Colors** is
generated from the variant's assigned targeted cure actions, so changing a
gesture does not create or move color data. Environment copy, reset, and
single/complete import-export therefore carry the colors without a parallel
schema or shared global fallback.

See [README.md](README.md), [CHANGELOG.md](CHANGELOG.md), and
[Dcr_ProfileManager.lua](Dcr_ProfileManager.lua).
