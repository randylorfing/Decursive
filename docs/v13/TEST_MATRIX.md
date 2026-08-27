# v13 Test Matrix

Every release candidate must pass source validation, packaged-artifact
validation and in-game testing. A successful options preview is never accepted
as proof that the live combat path works.

## Automated validation

- Lua lint/syntax validation for core and LoadOnDemand options.
- Canonical `@debug@`/`@end-debug@` source directives are permitted; the
  credential-free package is parsed after the packager rewrites them, and no
  directive or malformed long-comment delimiter may remain in the ZIP.
- No duplicated long-string delimiters in source or packaged Lua.
- Every TOC file reference exists with exact casing.
- XML parses successfully.
- Packaged ZIP contains sibling `Decursive` and `Decursive_Options` folders.
- Packaged TOCs contain the intended version and Interface value.
- No raw packager tokens remain in the ZIP.
- Every runtime Lua file parses, not only the v13 directory.
- Every XML file parses.
- The v13 shell installs itself as primary and `/dcrv13` is absent.
- Every legacy settings route resolves inside the v13 All Settings workspace.
- v13 protected-aura calls occur only in the approved platform adapter.
- v13 contains no legacy aura enumeration path.

## In-game matrix

Test at minimum with one representative capable specialization for every dispel
type and confirm a non-dispelling specialization fails closed.

| Context | Group sizes | Required checks |
|---|---:|---|
| Open World | 1, 2-5 | MUFs, clicks, no yellow range light, text/sound defaults |
| Follower Dungeon | 5 | zone entry, NPC roster, spec change, MUF recovery |
| Normal/Heroic/M0 | 5 | live dispel, range, failure, cooldown fan-out |
| Mythic+ | 5 | secret aura safety, live text duration, native sound, reload while key is active |
| Raid | 10, 20, 30, 40 | layout, sizing, bounded creation, roster churn |
| Battleground | variable | PvP text/chat defaults off, secure clicks remain valid |
| Arena | 2, 3 | PvP mode, roster transitions, no protected reads |

## MUF acceptance

- Existing placement migrates without a visible jump at the same UI scale.
- Lock/unlock and drag handle match the established behavior.
- Party and Raid pixel sizes change the actual live MUFs.
- A fresh/reset profile starts at Party 30 px, Raid 30 px, and linked 2 px
  horizontal/vertical spacing.
- Horizontal and vertical spacing independently change the correct axis.
- Linked spacing applies one value to both axes.
- Units per line remains authoritative in party, raid, battleground and arena;
  environment changes never auto-reflow the grid.
- Status light off restores original spacing.
- Status light on reserves only its required vertical space.
- The selected order mode, player marker and pet sizing remain correct.
- A fresh profile uses Group / roster order in a five-player party and in a
  raid; changing the setting to Decursive Priority restores priority-list and
  current-group sorting.
- With DandersFrames installed, DandersFrames order follows its visible
  party/raid layout after an `OnFramesSorted` callback. Without DandersFrames,
  selecting that mode falls back to Group / roster without an error.
- In **All Settings > Visuals & Alerts > Micro Unit Frames**, all four tabs
  reveal their controls immediately. Resize the window to its shortest allowed
  height and confirm one scrollbar remains usable and never overlaps either
  Party/Raid size `+` button.
- Native debuff-identity tooltips work in dungeon/raid combat through
  Blizzard's managed AuraButton, without addon-side inspection of protected
  tooltip or aura values.
- PvP creates no native debuff-identity carrier; safe public unit/help tooltip
  behavior remains available.
- Disabling MUF hover tooltips suppresses the tooltip presentation.
- Zoning, joining/leaving group and spec changes do not require `/reload`.
- Fully exit the WoW client, relaunch it and log into a character whose group
  roster is already active. MUFs appear without `/reload`, use the correct
  Party/Raid size and recover from any transient solo auto-hide decision.
- Repeat the full-client launch while genuinely solo with “hide while solo”
  selected, then join or start a dungeon. MUFs stay hidden while solo and
  appear when the party roster becomes public without `/reload`.
- If either cold-client case fails, do not reload first. Run `/zdmuf` and record
  every line, whether the character was solo/party/raid, and whether the MUF
  movement handle was visible. Then `/reload` and report whether it recovered.

## Alert acceptance

- Test and live dispel text use the same size, color, anchor and duration.
- In a follower dungeon, set the text to 54 px and red, then press the preview:
  the fallback banner is visibly red and uses the same 54 px font despite the
  active addon restriction.
- Timed text disappears at 2.0 seconds with the default setting in and out of
  combat.
- A three-second selection disappears at 3.0 seconds in and out of combat.
- Refreshing the same affliction does not restart the timer.
- PvP text remains off by default.
- Test Sound always plays when sound playback is available.
- A registered exact-ID aura fires on Blizzard's `Added` transition.
- Persistent afflictions and `ApplicationsIncreased` stack/dose changes do not
  repeat the sound.
- A successful cure in combat never rebuilds the native aura-sound registry or
  emits `ADDON_ACTION_BLOCKED`.
- No `ADDON_ACTION_BLOCKED` or `ADDON_ACTION_FORBIDDEN` event occurs during a
  cure, shared-cooldown update, tooltip hover, roster change or restriction
  transition.
- When combat is the only blocker, roster/spec/manual-ID registry changes apply
  once after `PLAYER_REGEN_ENABLED`. If an addon restriction remains active,
  they stay deferred until its deactivation edge.
- A registry refresh requested during an active encounter/Mythic+/PvP
  restriction remains deferred until the restriction is inactive.
- Outside a raid, `/zdsound` reports desired tokens
  `player,party1,party2,party3,party4`; exact coverage must equal desired
  coverage before entering a follower dungeon. An exact shortfall is degraded,
  even when the same number of older active handles still exists.
- Sound/channel replacement adds the new keys before removing the old keys.
  Removal failure retains visible stale handles, retries no more than three
  times, and never invokes a native mutation while combat/restriction is active.
- In a raid, `/zdsound` reports only canonical `player`/`raidN` tokens. Manual
  IDs span those members; non-player built-ins are limited to public entries
  matching the active instance context.
- Repeat raid content matching on a non-enUS client. Until localized names or
  stable instance-ID metadata are verified, remote built-in raid coverage must
  fail closed rather than register the full database.
- `/reload` while an encounter/Mythic+/PvP restriction is already active emits
  no blocked/forbidden action. `/zdsound` remains deferred and exact-ID live
  audio may be unavailable until restriction deactivation permits a reconcile.
- Addon-owned public fallback alerts share the default two-second debounce.
  Native Blizzard sounds may overlap for simultaneous affected MUFs because the
  native API provides no playback callback to Decursive.
- Verify in game that a fully cleared aura can later produce another native
  `Added` sound.
- In Altar of Fangs, Paralyzing Shots (`1294569`) produces one sound when its
  aura is added; its continuing applications up to 10 stacks stay silent. After
  the aura is fully removed, verify in game that a later new cast produces a
  new `Added` sound. This clean-removal/reapplication check is a release gate,
  not behavior proven by the static registry harness.

## Cooldown acceptance

- Successful cure immediately clears the clicked MUF overlay.
- Other matching afflicted MUFs show the overlay for the real spell cooldown.
- Countdown numbers respect the environment setting.
- Darkness matches the same value shown in settings and Test Center.
- Overlay remains independent of affliction fill and status light.
- No overlay is stranded after roster, zone, death or specialization changes.

## Restricted-state transitions

- Reload during an active Mythic+ key: MUFs and native aura containers rebuild;
  restricted sound registrations remain deferred without errors.
- Enter and leave combat while a challenge/encounter restriction remains
  active: secure MUF work flushes after combat without waiting for the whole
  instance restriction to end.
- Activate and deactivate PvP restrictions: no text/chat alerts are emitted and
  no protected aura value is logged or serialized.
- Leaving the world in combat does not call macro deletion or hide a protected
  MUF container.
- Running `/dcrreset`, changing MUF size or toggling MUF visibility in combat
  defers safely and applies after combat.
- If the options companion has not loaded yet, opening settings in combat gives
  a clear retry-after-combat message and performs no LoadOnDemand mutation.

## Release gate

1. In-game tester explicitly confirms the candidate, including both cold-client
   MUF startup cases and the removed/reapplied native-sound case above.
2. Commit is merged to `master` only after review.
3. Pull-request/source validation completes successfully.
4. A new, never-reused `v12.1.1` tag is created from a commit contained in
   `master`; ordinary branch pushes cannot publish.
5. The release workflow's credential-free package build and archive validation
   pass before the publish job begins.
6. The actual published ZIP is downloaded and inspected.
7. GitHub and CurseForge artifacts are confirmed to contain the same intended
   build.
