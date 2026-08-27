# v13 Preserved Feature Contract

This document defines what must feel unchanged in combat even though v13 is a
ground-up rebuild.

## Micro Unit Frames

- MUFs remain compact clickable squares, not health bars.
- The existing visual language remains recognizable: priority-one red,
  priority-two blue, additional configured cure colors, inactive/absent states
  and the player marker.
- Affliction fills, range/failure tints and cooldown shades occupy only the
  original inner MUF square (16x16 inside a 20x20 MUF; 12x12 for pet MUFs).
  They never cover the two-pixel outer border or spill into grid spacing.
- Fresh profiles use Group / roster order, matching Blizzard's `player`,
  `party1`-`party4`, or raid roster sequence; the player remains identified by
  `P`.
- The order control also offers traditional Decursive Priority order and an
  optional DandersFrames mirror. DandersFrames mode uses only its published
  frame lookup, layout/header APIs, and `OnFramesSorted` callback; if unavailable,
  the effective order safely falls back to Group / roster.
- Party and Raid can use independent pixel sizes; both default to 30 pixels.
- Horizontal and vertical spacing are independent unless the user explicitly
  links them. Fresh profiles default to linked 2-pixel spacing.
- With the optional status light disabled, spacing returns to the original
  Decursive spacing. Enabling the light reserves only the space it needs above
  each MUF.
- MUFs remain movable through their established handle, clamp to the screen,
  save their position independently of UI scale and can be locked.
- Layout, roster and structural changes are deferred during combat.
- Existing secure left/right/middle and modifier click behavior is retained.

## MUF hover tooltip

- MUF hover tooltips remain enabled by default.
- PvP still disables addon-owned center-screen text and chat alerts by default;
  that behavior is independent of the hover tooltip.
- Unit/help text may use accessible public unit and binding information.
- Aura-specific tooltip presentation belongs to Blizzard's managed AuraButton.
  Decursive never reads, copies, parses, compares or logs its protected lines.
- Native aura-identity tooltips are enabled only in dungeon and raid contexts.
  PvP retains safe public unit/help information and deliberately does not create
  the native aura-identity carrier.
- If Blizzard cannot provide an aura tooltip, Decursive shows no inferred aura
  details and keeps the MUF/cure interaction operational.

## Status light

The optional light is one quarter of the MUF size and is not clickable.

- Green: confirmed successful cure, three seconds.
- Yellow: out of cure range, persistent only in an instanced group context.
- Red: confirmed failure, three seconds.
- Gray: dead or offline, persistent.
- Hidden: no actionable status.

Yellow never appears in Open World mode. Disabling the light restores the
original tight grid spacing. An unavailable, unchecked or protected range
result is neutral and never produces yellow.

## Dispel text alert

- The live text is `DISPEL` by default.
- New profiles have the alert enabled except PvP, where addon-owned text alerts
  are disabled by default.
- Timed mode defaults to exactly 2.0 seconds and supports a user-selected
  duration.
- The configured font size, color, position and duration apply equally to the
  settings preview and the live alert.
- The Decursive-owned preview/fallback banner applies that style even while an
  instance restriction prevents mutation of Blizzard-managed AuraSlot labels.
- The alert anchor is movable outside combat and persists across sessions.
- Live protected display uses Blizzard-owned bindings. No timer reads protected
  aura state.
- Repeated refreshes of the same active affliction do not extend a timed alert.

## Dispel sound alert

- New profiles have sound enabled with the existing female `Dispel` voice as
  the default.
- For an exact registered public spell ID, Blizzard's `Added` trigger plays the
  selected sound when the aura first appears on an armed unit token.
- A continuously active or stacking affliction stays silent. Stack/dose changes
  are not new clean-to-dispellable transitions.
- Addon-owned public fallbacks share a configurable debounce that defaults to
  exactly 2.0 seconds. Blizzard native playback exposes no callback through
  which Decursive can apply that debounce across units.
- The Test Sound control bypasses the addon-owned fallback debounce.
- Channel and selected sound are profile settings.
- Exact public spell IDs use Blizzard native sound registration. Unknown secret
  auras remain visual-only rather than generating unreliable repeated audio.
- Native sound registrations are created only while neither combat lockdown nor
  an addon restriction is active. Stable party tokens are reserved before
  follower-dungeon restrictions begin; deferred roster/spec/manual-ID changes
  retain all working handles and reconcile once both boundaries are clear.
- Registry status is healthy only when every desired sound/channel key is
  armed and no stale handle or add/remove failure remains. Removal failures are
  retried at most three times per lifecycle request and stay visible as
  degraded status if cleanup cannot complete.
- Raid registration uses canonical player/raid tokens. Manual IDs cover those
  members; database IDs on non-player raid members are limited to entries whose
  public content name matches the active instance. The player keeps the full
  eligible database pool.
- Content-name scoping is an interim enUS-compatible boundary. Remote raid
  built-ins are not considered generally covered until stable instance-ID
  metadata or localized-name testing replaces that assumption.
- A reload that begins while Blizzard's addon restriction is already active
  cannot legally recreate native handles. Registration stays deferred, no
  protected API is called, and exact-ID live audio may be unavailable until the
  restriction ends and reconciliation succeeds.

## Cooldown overlay

- Cooldown presentation belongs to Decursive and does not depend on the aura
  provider.
- After a successful friendly dispel, the clicked/cleansed MUF clears
  immediately.
- The faded black cooldown shade and optional number appear on other MUFs that
  still need the same available dispel priority.
- No radial swipe, edge flash or bling is used.
- Overlay darkness, countdown visibility and profile behavior are configurable.
- The overlay is independent of the MUF's current affliction fill.
- The shade and countdown remain clipped to the same inner square as the
  affliction color, preserving the original MUF border at every scale.

## Profiles and environments

Named user profiles and environment behavior are separate concepts.

Automatic environments:

- Open World
- Dungeon / Follower Dungeon
- Mythic+
- Raid
- PvP

Named profiles support create, copy, reset, delete, manual selection,
import/export and migration. Environment settings are overrides inside the
active named profile.

Defaults with special meaning:

- Open World range indication is off.
- PvP addon-owned text and chat alerts are off.
- Dispel text, sound and cooldown overlay are on in the other environments.

## Reliability acceptance criteria

- A full client launch reconstructs the saved MUF layout after player/roster
  readiness settles and never requires `/reload` to make the squares appear.
- A transient solo snapshot at login cannot strand an already-grouped
  character in the auto-hidden state; Party/Raid size is reconciled with the
  final roster context.
- A specialization change rebuilds cure capabilities and roster assignments
  without requiring `/reload`.
- Entering or leaving an instance rebuilds provider registrations and MUFs
  without requiring `/reload`.
- A 40-player roster does not create a burst of unbounded timer callbacks.
- Settings changed in combat are either safe presentation changes or clearly
  marked pending until combat ends.
- Test controls and live events call the same public renderer/sound functions.
- Diagnostics distinguish unavailable, unregistered, deferred and operational
  states without inspecting aura contents.
