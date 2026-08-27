# Zhaohu's Decursive v12.1.1

This release introduces a completely redesigned command-center settings
experience while preserving Decursive's compact secure Micro Unit Frames and
fast click-to-cure workflow.

## Highlights

- One graphite/cyan settings window opened by `/dcr`, `/decursive`, `/zd`, the
  options keybind, Blizzard Settings and the established list shortcuts.
- No legacy beta/RC notice window interrupting login.
- Focused Overview, MUFs, Cure, Alerts and Profiles pages plus a searchable
  **All Settings** workspace containing the complete established catalog.
- Preserved MUF appearance, movement, locking, party/raid layouts, secure cure
  bindings, class border and pet sizing.
- Affliction, range, failure and cooldown visuals remain inside the original
  inner MUF square so the two-pixel class border stays visible.
- Live and test DISPEL text use the same style, position and duration path.
- Native WoW 12.1 aura sound registration, selectable sound/channel, public
  fallback debounce and detailed `/zdsound` diagnostics.
- Cooldown shading and countdowns fan out across affected MUFs after a cure.
- Native dungeon/raid aura tooltips with PvP-safe unit/help tooltip behavior.

## Reliability and WoW 12.1 safety

- Protected sound registration, macro/binding changes, secure frame mutations
  and AuraContainer lifecycle work are stopped at their actual combat or addon
  restriction boundaries; `pcall` is never treated as permission.
- Legacy aura enumeration and combat-log inspection fail closed before reading
  protected data on WoW 12.1.
- Secret values are rejected before comparison, formatting, indexing or
  persistence.
- Cold-client roster recovery reconciles saved visibility, actual secure parent
  state and newly assigned MUF children without requiring `/reload`.
- `/zdmuf` reports safe public startup state if a roster display fails.

## Sound behavior

Blizzard's native sound API requires an exact spell ID. A registered aura plays
on the `Added` transition. Continuing stack/application increases deliberately
do not repeat the sound; after the aura is fully removed, a later new
application should play again. Unknown fully protected spell IDs can remain
visual-only until Decursive learns or is given the exact ID. Public fallback
sounds use the configured two-second debounce.

## Upgrade

Exit World of Warcraft and replace both the `Decursive` and
`Decursive_Options` folders. Delete or move the old folders first instead of
copying over them, which prevents stale files from older builds. The
`DecursiveDB` SavedVariables file is not part of the addon package and is
preserved.
