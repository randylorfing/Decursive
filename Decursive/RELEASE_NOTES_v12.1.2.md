# Zhaohu's Decursive v12.1.2

Version 13 introduces a completely redesigned command-center settings
experience while preserving Decursive's compact secure Micro Unit Frames and
fast click-to-cure workflow.

## Project provenance and license

- The project remains licensed under GNU GPLv3-or-later.
- Project metadata credits John Wellesz and Randy Lorfing and routes current
  bug reports to Randy.
- The in-game About page preserves Patrick Bohnet's original contribution,
  John Wellesz's stewardship from 2006 through 2026, and Randy Lorfing's WoW
  12.1 compatibility and Zhaohu's Decursive maintenance work.
- The fork uses its own `ZhaohuDcrVersion` version-announcement channel, so it
  does not exchange release dates or newer-version alerts with original
  Decursive installations.
- Release ZIPs are generated from the Git source by the BigWigs packager; a
  packaged ZIP is never used to replace the source tree.

## Highlights

- One graphite/cyan settings window opened by `/dcr`, `/decursive`, `/zd`, the
  options keybind, Blizzard Settings and the established list shortcuts.
- No legacy beta/RC notice window interrupting login.
- Focused Overview, MUFs, Cure, Alerts and Profiles pages plus a searchable
  **All Settings** workspace containing the complete established catalog.
- Audited every deferred menu callback so command-bar pages, All Settings
  categories/routes, tabs, list actions, mouse bindings and custom-spell cards
  act on the exact control clicked; rejected changes now show a footer error.
- Preserved MUF appearance, movement, locking, party/raid layouts, secure cure
  bindings, class border and pet sizing.
- Added Group / roster (new default), Decursive Priority, and DandersFrames MUF
  ordering choices with combat-safe deferred reordering.
- New and reset profiles default to 30-pixel Party and Raid MUFs with linked
  horizontal and vertical spacing set to 2 pixels.
- Restored original Decursive spacing and grid rules in party, raid, battleground,
  and arena: linked spacing follows Horizontal, independent Vertical spacing
  updates live, and Units per line is never overridden by the activity type.
- Affliction, range, failure and cooldown visuals remain inside the original
  inner MUF square so the two-pixel class border stays visible.
- Live and test DISPEL text use the same style, position and duration path.
- Fixed restricted-instance previews/fallback alerts ignoring their saved font
  size and color.
- Rebuilt the All Settings MUF tab body as one responsive scroll surface, so
  tabs change visible content and the scrollbar no longer covers size buttons.
- Native WoW 12.1 aura sound registration, selectable sound/channel, public
  fallback debounce and detailed `/zdsound` diagnostics.
- Native sound registration now uses the same chat-lockdown permission boundary
  as DBM and includes DBM-verified current-content friendly-dispel aura IDs.
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
application should play again. The bundled list includes the current DBM module
entries explicitly classified as friendly dispels; unknown fully protected
spell IDs can still remain visual-only until Decursive learns or is given the
exact ID. Public fallback sounds use the configured two-second debounce.

## Upgrade

Exit World of Warcraft and replace both the `Decursive` and
`Decursive_Options` folders. Delete or move the old folders first instead of
copying over them, which prevents stale files from older builds. The
`DecursiveDB` SavedVariables file is not part of the addon package and is
preserved.
