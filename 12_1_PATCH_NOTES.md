
## v10.40 - Behavior Profiles

- Expanded environment profiles from visual presets into behavior profiles.
- Added per-profile Detection Policy: Strict Managed or Managed + Legacy when safe.
- Added per-profile secondary-affliction enable/pulse controls.
- Added per-profile shared same-priority cooldown control.
- Added per-profile immediate cleansed-target exclusion behavior.
- Added per-profile environment/profile transition chat toggle.
- Added behavior details to the WoW 12.1 Status page.
- Unsafe protected-aura reads remain unavailable by design.

## v10.37 - PvP Mode Transition Chat Messages

- Added a Decursive chat/status message when the effective WoW 12.1 PvP protected-aura mode changes.
- Entering restricted PvP mode prints: `Decursive: PvP protected-aura mode ENABLED`.
- Leaving restricted PvP mode prints: `Decursive: PvP protected-aura mode DISABLED`.
- Messages are only emitted when the effective state changes, preventing repeated zone/event spam.
- Uses Decursive's existing `Println()` output path so existing chat/custom-frame output preferences are respected.
- Changing the PvP protected-aura setting also announces the transition only when it changes the effective mode.

---

## v10.33 - Yellow Out-of-Range Default

## v10.36 - PvP Restricted Aura Mode

- Added configurable **PvP protected-aura mode** with:
  - Automatic (Battlegrounds / Arenas)
  - Always On
  - Always Off
- Automatic mode uses WoW's instance type (`pvp` / `arena`) rather than guessing from protected aura values.
- In restricted PvP mode, legacy Decursive debuff coloring is suppressed on MUFs.
- Blizzard-managed strict priority AuraContainers become the sole live affliction-color authority.
- Prevents protected/legacy aura state from falling back to false Priority #1/red coloring.
- Exact protected aura details are not read by addon Lua.
- PvP tooltip reports `PvP protected aura mode (managed priority)` instead of interpreting legacy aura details.
- Entering or leaving PvP refreshes MUF visual state automatically.

---

- Default out-of-range overlay color changed to yellow.
- The menu color picker remains configurable.
- Resetting the range color now restores yellow.
- Existing saved custom colors are preserved.

---

## v10.27 - Cleanse Clear + Same-Priority Cooldown Sharing

- Changed cleanse behavior so the MUF that was successfully cleansed no longer keeps a faded cooldown square.
- The clicked/cleansed MUF is explicitly excluded from live cooldown overlays; its Blizzard-managed priority color is allowed to disappear naturally with the removed aura.
- Added one invisible Blizzard-managed `AuraSlot` gate per curing priority and per MUF.
- Each gate uses `candidateFilters.includeDispelTypes` so Blizzard performs the protected dispel-type matching internally.
- Added separate Decursive-owned shared cooldown overlays for Priority 1, Priority 2, and Priority 3.
- When a curing spell enters cooldown, other MUFs that still match the same curing priority can show the same faded priority color and white countdown timer.
- Different-priority MUFs and clean MUFs remain unaffected.
- The compatibility layer never branches on protected aura data. A gate's managed `IsShown()` result is passed only through the engine-level `SetAlphaFromBoolean()` path when accessible.
- Managed gate reads are wrapped silently; if Blizzard denies access in a restricted context, the shared overlay safely remains hidden instead of producing another forbidden-object error.
- Dynamic shade/timer objects remain parented only to Decursive-owned frames. No `Show`, `Hide`, `SetAlpha`, or cooldown mutation is performed on Blizzard-managed AuraButtons after initialization.

---

## v10.24 - Shared Priority Cooldowns

- Added priority-specific Blizzard managed aura gates using `candidateFilters.includeDispelTypes`.
- When a cure spell enters cooldown, the cooldown tint/timer is mirrored to every currently afflicted MUF whose active dispel type maps to that same Decursive curing priority.
- MUFs afflicted by another curing priority are left unchanged.
- Clean MUFs do not display the shared cooldown.
- Blizzard continues to own protected aura matching/visibility; Decursive does not read protected aura type values.
- Cooldown shade/timer widgets remain ordinary addon-owned children and are not registered as managed display elements.

## v10.19 - Cooldown on all afflicted MUFs

- Changed live cooldown scope from the clicked MUF only to every MUF that Blizzard is currently marking as dispellable.
- Live cooldown widgets are now created inside managed aura slot #1 during Blizzard's safe initialization callback.
- Decursive does not read or branch on the protected aura/button shown state. Blizzard's own managed button visibility gates the timer to afflicted units.
- Clean/unaffected MUFs do not display the cooldown timer.
- While the dispel is cooling down, each afflicted MUF keeps its own managed priority color and is darkened/faded with a white countdown number.
- Preserved the two-affliction visual model: first affliction owns the inner square; a rare second simultaneous affliction uses one pulsing border.
- Removed the clicked-square-only live cooldown overlay path; addon-owned overlays remain for diagnostic testing only.
- Preserved empty-click cooldown reconciliation and secret-value safety.

---

## v10.18 - Two-layer simultaneous-affliction model

- Managed AuraContainer display reduced from three aura slots to two.
- Slot 1 always renders as the inner square using Blizzard's dispel-type color mapping.
- Slot 2 renders as the single pulsing secondary border.
- No third simultaneous aura visual and no second outer border are created.
- A lone Priority #2 or Priority #3 affliction still renders in the inner square; border presence now strictly means a second simultaneous dispellable aura exists.


## v10.17 - Blizzard-managed priority dispel visuals

- Replaced the neutral pre-click dispellable indicator with Blizzard-managed dispel-type presentation.
- Uses `CustomAuraButton:AddDispelTypeTexture()` with `customDispelColorCurve`; Blizzard evaluates the protected aura dispel type internally.
- Decursive does not read or branch on protected `auraData.dispelName`.
- Priority #1 dispels drive the inner-square fill using Decursive's Priority #1 color.
- Priority #2 dispels drive the first pulsing border using Decursive's Priority #2 color.
- Priority #3 dispels drive the second outer pulsing border using Decursive's Priority #3 color.
- Nonmatching priority layers are transparent through Blizzard-evaluated color curves.
- Priority curves are regenerated when Decursive refreshes its curing-spell configuration after specialization/talent/spell changes.
- Existing post-click faded-priority cooldown state and per-MUF timer remain addon-owned and separate from protected aura objects.

## v10.15 - Neutral protected-aura pre-click alert

- Changed the Blizzard-managed pre-click dispellable fill from Priority #1 red to a neutral gray.
- WoW 12.1 may hide the exact protected aura dispel type, so Decursive no longer guesses a curing priority before the player clicks.
- After a cure binding is clicked, the addon-owned cooldown state still uses that binding's actual Priority #1/#2/#3 color.
- Example: a Curse assigned to Priority #2/right-click now transitions to the faded Priority #2 color during cooldown instead of being pre-labeled as Priority #1 red.

---

## v10.14 - Reliable empty-click cleanup
- Fixed a race where a faded priority tint could remain after clicking a clean MUF.
- A returned cooldown DurationObject is no longer assumed to mean an active cooldown.
- When Blizzard exposes a non-secret remaining duration of zero, the per-MUF tint/timer state is cleared immediately.
- Added additional short reconciliation passes after a cure click.
- Secret/protected duration values are never inspected or used for branching.

## v10.13 - Priority Cooldown State Machine / Lingering Tint Fix

- Reworked cure-click priority detection to use the actual Decursive mouse-button assignment that was clicked.
- Priority #1, #2, and #3 now all transition to the same cooldown presentation: a faded version of that priority color in the inner square with the numeric timer centered on top.
- Priority #2 and Priority #3 alert borders stop pulsing as soon as that priority enters cooldown.
- Priority #2/#3 cooldowns now use the inner-square countdown widget instead of separate hidden border cooldown widgets.
- Added repeated post-cast cooldown/charge reconciliation to clear temporary faded colors after an empty/failed dispel click.
- Cooldown completion force-clears the per-MUF active-priority marker, inner tint, and timer.
- Kept the existing per-square diagnostic rendering and taint-safe Blizzard managed-aura separation.

## v10.9 - Dark Active Cooldown State

- Changed the Priority #1 active cooldown fill from the priority alert color to a neutral dark/charcoal shade.
- The dark fill is applied only to the MUF whose Priority #1 cooldown is actively counting down.
- The numeric cooldown timer remains visible above the darkened square.
- Priority #2 and Priority #3 borders continue to use their configured Decursive priority colors.
- The existing cooldown overlay opacity option now controls how strongly the active MUF is darkened.
- Updated the selected-MUF and all-MUF visual tests to preview the same dark countdown state used during live play.
- Updated compatibility status reporting to v10.9.


## v10.8 - Live Per-Square Trigger Fix

- Live cooldown timers now activate only on the Decursive MUF that actually launched the successful cure.
- Added a taint-safe MUF `PostClick` tracker; the secure cure action is unchanged.
- `UNIT_SPELLCAST_SUCCEEDED` still confirms the real cure spell before any cooldown visual is armed.
- Priority #1 remains the inner square/timer, Priority #2 the first border, and Priority #3 the outer border.
- Restored the managed AuraContainer's initial visible state once at creation so Blizzard-managed dispellable indicators can render, while avoiding later `Show()`/`Hide()` calls on managed objects.
- Diagnostic selected-square and all-square tests are unchanged.
- Updated compatibility status version reporting to v10.8.



## v10.4 - MUF Overlay Sync and Test Controls

- Changed cooldown overlay positioning to use Decursive's own MUF layout coordinates instead of reading geometry from secure MUF frames.
- Added a selectable **MUF square to test** control.
- Added **Test selected MUF square** for one-at-a-time verification.
- Added **Test ALL MUF squares** to preview every visible square simultaneously.
- Individual and all-square tests preview Priority #1 inner/timer and Priority #2 border for 8 seconds.
- Test mode remains visual-only and does not inspect protected aura data or cast spells.
# v10 Cooldown Border Display

The stable primary friendly-dispel cooldown can now be displayed as **Overlay + Timer**, **Border + Timer**, or **Border Only**. Border color, opacity, and thickness are configurable from the original Decursive options. The border is a separate compatibility-layer border and does not replace Decursive's original MUF class/status border.

## v9.1 cooldown architecture correction

The experimental per-cure-type MUF overlays from v9 were removed. Under WoW 12.1, the managed aura system can safely expose that a unit is dispellable, but the addon cannot reliably associate a protected/secret aura on that unit with Magic, Poison, Disease, Curse, or Bleed in Lua. The MUF therefore uses the stable primary-friendly-dispel cooldown overlay, while the managed aura container remains responsible for unit dispellability.

## v7 - Menu Organization

- Moved Mouse Bindings to **Custom Spells → Mouse Bindings**.
- Binding functionality and saved assignments are unchanged.

# Decursive 12.1 compatibility patch (preview v1)

This build starts from the clean Decursive 2.8.2-2-g4a1865f source and preserves the original UI, options, curing order, mouse bindings, priority/skip lists, and secure click macros.

## Changed for WoW 12.1

- Removed the intentional 12.1 self-disable.
- Re-enabled the original Decursive slash commands/options UI.
- Guarded secret `UNIT_AURA` tables and `UnitIsCharmed()` results before Lua branches/iteration.
- Kept the legacy raw debuff scanner disabled on 12.1.
- Added a Blizzard-managed `AuraContainer` using `HARMFUL|RAID_PLAYER_DISPELLABLE` for each original MUF.
- The managed aura button owns the visual alert, so addon Lua never asks whether a protected aura exists.
- Original secure click macros remain underneath the managed visual layer.

## Current 12.1 limitation

The original Decursive engine cannot reliably read the exact protected aura name/type/stack/duration during combat. Features that depend on those raw values (for example exact per-debuff-name filtering or the classic Live List's full aura details) are not restored by this first compatibility patch.

The goal of subsequent patches is to restore each original feature only where Blizzard provides a compliant managed/display API.

## Patched v2
- Removed the repeated `There is nothing to cure!` chat message. In WoW 12.1 the legacy Decursive cache can be empty even when the Blizzard-managed dispel indicator is valid, so this message is misleading and noisy.


## v3 - Dispel Cooldown Overlay

- Added a WoW 12.1-safe dispel cooldown overlay to the original Decursive Micro Unit Frames.
- Uses Blizzard's `C_Spell.GetSpellCooldownDuration(..., true)` duration object directly.
- Uses Blizzard's `Cooldown` widget for the countdown display.
- Radial swipe, edge, and bling animations are disabled.
- Shows a faded black veil plus the numeric cooldown countdown.
- Tracks the actual configured/last-cast Decursive curing spell so it is not Monk-specific.
- Leaves the original Decursive curing, bindings, options, and MUF code intact.


## v4 - Cooldown Overlay Option
- Added a **Dispel cooldown overlay** toggle under **Micro Unit Frame Settings → Display Options**.
- The option is enabled by default.
- Disabling it immediately hides the 12.1 cooldown veil/countdown.
- The preference is stored in the normal Decursive profile.
- The setting cannot be changed during combat, consistent with other MUF configuration controls.

## v5 - MUF sizing controls

- Added an explicit **MUF square size (pixels)** slider under **Micro Unit Frame Settings -> Display Options**.
- Supported range: **10-80 px**.
- Added **Reset MUF size (20 px)**.
- The new pixel-size control stays synchronized with Decursive's original percentage-based MUF scale setting.
- Size changes are blocked during combat, matching Decursive's secure-frame behavior.


## v6 - Automatic dispel cooldown spell detection

- Reworked the cooldown overlay resolver to use Decursive's live `FoundSpells`, `CuringSpells`, and `CuringSpellsPrio` tables instead of relying on a fixed class-specific cooldown target.
- The tracked cooldown spell now follows the character's currently available friendly dispel spells, specialization, talent-enhanced dispels, and enabled Decursive curing priorities.
- Enemy dispels such as Purge/Spellsteal/Consume Magic and charm-only utilities are excluded from the friendly-dispel cooldown resolver.
- When a class has multiple friendly cleanses, Decursive's own `Better` ranking is preferred, then friendly dispel coverage, then the user's curing priority. This keeps a normal targeted cleanse preferred over a secondary long-cooldown utility where Decursive ranks it better.
- The resolver refreshes after specialization, spellbook, talent, and Decursive reconfiguration changes.
- Added `D:Get121CooldownDispelSpell()` as a small diagnostic helper that reports only the selected public spell identity; it never reads protected aura details.
- Updated the cooldown option description to explain automatic spell/spec/talent detection.
## v8 status and test tools

The options now include a **12.1 Status** page with the detected friendly dispel, active compatibility backend, MUF/container counts, and cooldown-overlay settings. A visual-only MUF test is available for configuration and troubleshooting. Cooldown overlay darkness and countdown-number visibility are configurable. None of these tools reads protected aura details.


## v10.3 - Taint hardening
- Removed addon-owned fields from Blizzard managed aura buttons.
- Removed manual Show/Hide calls on Blizzard managed AuraContainer frames.
- Managed AuraContainers are now parented to the original MUF so visibility follows the MUF automatically.
- Cooldown overlays are addon-owned and positioned by copying MUF container-relative coordinates instead of anchoring to secure MUFs.
- This isolates the compatibility visuals from Blizzard protected frame dependency chains and addresses unrelated protected-call taint such as Guild Control `IsUserOAuthed()` failures.


## v10.7 - Priority border stack

- Priority #1 remains the inner MUF square and timer.
- Priority #2 now owns the primary MUF alert border; cooldown alerts no longer use class color.
- Added a second outer border for Priority #3 using Decursive's configured Priority #3 color.
- Priority #2 and Priority #3 borders can pulse independently.
- Added Priority #3 border enable, opacity, thickness, and pulse settings.
- Updated single-square and all-square visual tests to preview all three priority layers.

## v10.11 - Priority-colored cooldown fill
- Rebuilt the inner cooldown tint so it follows the active Decursive curing priority color.
- Priority #1 cooldowns use a faded Priority #1 color inside the square.
- Priority #2 cooldowns use a faded Priority #2 color inside the square while Border #1 retains the full Priority #2 color.
- Priority #3 cooldowns use a faded Priority #3 color inside the square while Border #2 retains the full Priority #3 color.
- Removed the neutral black/charcoal inner cooldown fill.
- The existing opacity control now adjusts the faded priority-color tint.


## v10.21 - Managed Aura Pool Ordering Fix
- Fixed Blizzard AuraContainer pooled-frame ordering so priority textures are attached to the AuraButtons that actually become live slot #1 and slot #2.
- Priority colors now use Decursive's native `D.Status.dsCurve` when available.
- No change to secure cure-click behavior.


## v10.30 - Protected Aura Status Color

- Changed the WoW 12.1 protected-aura tooltip status from yellow to a distinct purple/magenta color.
- New status color: `#CC66FF`.
- Keeps `Aura state protected (WoW 12.1)` visually separate from the legacy yellow Normal/status text and Decursive priority colors.
- No changes to managed priority detection, curing, or cooldown behavior.

## v10.29 - Protected Aura Tooltip Fix

- Fixed misleading `Normal` MUF tooltip text on WoW 12.1 when the legacy scanner cannot see Blizzard-managed protected aura state.
- On WoW 12.1, legacy `NORMAL` status is displayed as `Aura state protected (WoW 12.1)` instead.
- Does not inspect protected aura details and does not modify the managed priority-color or cooldown paths.

## v10.32 - Configurable Out-of-Range Dimming
- Added an addon-owned out-of-range MUF dim layer.
- Keeps the active priority hue visible while making out-of-range units visibly darker.
- New Display Options allow enabling/disabling the feature, selecting the dim amount, choosing the overlay tint, and resetting to the recommended black/60% default.
- No Blizzard-managed aura object is modified by the range layer.


## v10.35 - Strict Priority Filtering

- Tightened the WoW 12.1 managed-aura display so protected auras cannot fall back to Priority #1 merely because they are dispellable.
- Added an engine-side `candidateFilters.includeDispelTypes` allow-list containing only dispel types currently mapped by Decursive to configured friendly cure priorities.
- Removed the managed priority texture's fallback to the older shared `D.Status.dsCurve`; the managed display now uses the 12.1 compatibility curve built directly from current cure mappings.
- If a protected aura does not match a configured Decursive cure type, no priority color is shown.
- No legacy aura scanning or protected aura reads were added.

## v10.38 - Environment Profiles

Decursive now separates WoW 12.1 behavior into Raid, Mythic+, PvP, and Open World profiles. Automatic mode selects the profile from Blizzard instance information and active Challenge Mode state. Each environment stores its own range and cooldown presentation settings. PvP remains the strict managed-aura mode.


## v10.39 - Dungeon Environment Profile

Added **Dungeon** as a fifth environment alongside Raid, Mythic+, PvP, and Open World. Follower, Normal, Heroic, Timewalking, and Mythic-0 party instances use Dungeon automatically, while active Challenge Mode instances continue to use Mythic+. Dungeon has its own saved range/cooldown presentation settings and can also be selected manually.
