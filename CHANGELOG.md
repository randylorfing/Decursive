# Zhaohu-Decursive Changelog

## v11.0.42

## Licensing/attribution cleanup pass
- Per a follow-up from John Wellesz, re-verified the whole tree for GPL attribution correctness: no leftover `"DecursiveVersion"` AceComm prefix, no stale 2006-2025 copyright years, correct dual-attribution on every original file Randy Lorfing modified.
- Found and fixed a gap the earlier attribution pass missed: 12 dispel-database expansion files (`Database/Dispels/*.lua`), `Database/DispelDB_Core.lua`, and `Dcr_ProfileIO.lua` (all solely written by Randy Lorfing) had no license header at all. Added the same GPL header used by the other solely-Randy files.
- Also found `embeds.xml` and `Localization/load.xml` -- original files Randy Lorfing has modified -- had never carried a copyright header to begin with. Added the standard dual-attribution header (John Wellesz's original copyright plus Randy Lorfing's maintenance line), matching every other original file in the project.

## v11.0.40

## Fix: sound-refresh taint error, and native detection/cooldown taint spam (root-caused)
- Fixed a recurring `[ADDON_ACTION_BLOCKED]` error on `RefreshProtectedAuraSounds`, reported independently from PvP arena, Mythic+, and a third session -- all high-frequency dispel-click content. Root cause: it ran synchronously inside the `UNIT_SPELLCAST_SUCCEEDED` handler, immediately after the player's own dispel cast landed via the secure click-cast macro, a context that can still carry taint into the same execution frame. `C_UnitAuras.AddAuraSound` needs a genuinely untainted caller; `pcall` can't suppress `ADDON_ACTION_BLOCKED` since it isn't a catchable Lua error. Fixed by deferring the call one frame (`C_Timer.After(0, ...)`) so it always runs after the click's execution has fully unwound.
- Fixed the native (non-DandersFrames) detection/cooldown-gate/cure-verification code producing a burst of "forbidden object" taint errors on every MUF creation. The actual bug: positioning (`ClearAllPoints`/`SetAllPoints`) on each Blizzard-returned `AddAuraSlot()` button was done in plain addon code *after* `AddAuraSlot()` returned. Blizzard's own API docs confirm addons manually anchoring AuraSlots is the sanctioned, intended use -- the problem was *where* the anchor call ran, not *that* it ran. Cross-checked against DandersFrames' own public source: they do this same positioning *inside* Blizzard's `initializeFrame` callback (invoked via `securecallfunction`, a materially different execution context than plain addon code). Moved positioning into `initializeFrame` for all three affected carriers; confirmed via live PvP/raid testing that the priority-color squares, cooldown-gate overlay, and cure-verification indicator all still render correctly.
- The debuff-identity hover tooltip's real native-tooltip-in-PvP enhancement (from a similar positioning attempt) is shelved for now: it correlated with the priority-color squares failing to render, and reverting it restored them. The tooltip still works as it did before this release (name label, cast-inference fallback in PvP; real native tooltip in raid/dungeon) -- getting the actual debuff read to work in PvP too is a separate follow-up.
- Renamed the internal build codename from `square-sound25-root-decursive` to `Zhaohu-Decursive` everywhere it appeared (changelog header, `Decursive.toc`'s `X-Zhaohu-Build` field, and the sound-diagnostics print in `Decursive.lua`).

## v11.0.39

## Hotfix: broken addon init in v11.0.38
- The v11.0.38 AceComm prefix rename (`"ZhaohuDecursiveVersion"`) was 22 characters, over AceComm's hard 16-character limit. `RegisterComm` threw during `OnInitialize`, which halted that function before `D.eventFrame` could be created, which in turn crashed `OnEnable` and left the addon only partially initialized.
- Shortened the prefix to `"ZhaohuDcrVersion"` (16 characters) in `DCR_init.lua` and `Dcr_Events.lua`. Confirmed fixed via live in-game testing.

## v11.0.38

## PvP parity, licensing/attribution fixes, and version-announce channel fix
- PvP's visual profile (out-of-range dim, cooldown overlay opacity/numbers, pulse, etc.) now exactly matches the DUNGEON preset instead of having its own separately-tuned values -- arena/battleground teams are party-sized content, not raid-sized, so there was no reason for a distinct profile.
- The debuff-identity hover-tooltip and unit-name label, already extended to raids in v11.0.37, now also work in PvP (`pvp`/`arena` instance types).
- Per direct guidance from John Wellesz (original Decursive author):
  - Renamed the AceComm version-announce prefix `"DecursiveVersion"` to `"ZhaohuDecursiveVersion"` (`Dcr_Events.lua`, `DCR_init.lua`). The two forks now diverge in release dates and version numbers, so sharing one announce channel was generating false "new version available" alerts for both projects' users.
  - Corrected John Wellesz's copyright year (2006-2025 -> 2006-2026) across every file carrying his header.
  - Added Randy Lorfing's attribution alongside John's in the original files actually modified for WoW 12.1 compatibility.
  - Files created solely by Randy Lorfing (`Dcr_12_1.lua`, `Dcr_12_1_Utils.lua`, `Dcr_12_1_SoulLink.lua`, `Dcr_12_1_DebuffIdentity.lua`) now carry only his copyright, per John's explicit instruction.

## v11.0.37

## Fix: taint crashes in the debuff-identity tooltip; extended to raids
- Positioning the native identity-tooltip aura slot against Decursive's own secure frame during MUF creation could throw "Attempt to access forbidden object from code tainted by an AddOn" (confirmed via BugGrabber), happening inside MUF construction itself and potentially leaving that MUF's setup incomplete.
- The feature now builds its own fully isolated `AuraContainer`, instead of sharing the one core affliction detection depends on -- after a live report that detection stopped working entirely in the same session as an earlier, narrower crash fix.
- Fixed a second taint crash in the `AddAuraSlot` `initializeFrame` callback, which runs outside the `pcall` protecting the call that registers it.
- The hover-tooltip and unit-name label were originally scoped to dungeons only; extended to also work in raids.

## v11.0.36

## Fix: dispel reliability, split dispel/battle-rez macros, MUF repopulation on revive
- Fixed a severe scoping bug: a variable used by the click-outcome tracker was declared after its first use, silently crashing Decursive's own success/failure/cooldown-arming logic on every single cast outcome -- including successful ones. The real spell cast wasn't affected (WoW's secure macro engine handles that independently), but Decursive's own confirmation feedback and cooldown display were dying on every cast.
- The dispel macro now excludes dead targets (`nodead`) instead of wastefully attempting (and failing) a cure cast on a corpse.
- `/stopcasting` reordered to the top of the macro -- it could previously cancel a battle-rez cast the same click had just started, since Rebirth has a real (non-instant) cast time.
- Battle-rez is now guaranteed on right-click for classes with only one registered cure spell (e.g. single-cure Mistweaver), without affecting classes that already use right-click for a second real cure spell.
- `PLAYER_ALIVE` and `PLAYER_REGEN_ENABLED` now trigger MUF repopulation after a death/revive cycle -- neither did before, leaving squares missing until a manual `/reload` in some cases.
- Renamed "Soul Link" references to "battle rez" throughout user-facing text.
- Removed the interrupt/debuff-landed encounter-alert feature (pilot scope cut).
- Added role-based priority list sorting (Tank/Healer/DPS) alongside existing per-player priority entries, a movable on-screen alert anchor, and an alert diagnostic log (`/dcralertdiag`) for troubleshooting.

## v11.0.35

## New: battle-rez / Emergency Soul Link on dead allies
- Clicking a dead ally's MUF square now attempts a battle-rez instead of the (otherwise useless against a corpse) cure-spell click. Tries your own known battle-rez spell first (Rebirth, Raise Ally, or Intercession -- detected automatically per class, normal cast range, no item needed), then falls back to Emergency Soul Link (Midnight Engineering item, 5-yard range) if you don't have one. Both draw from the same shared Combat Resurrection charge pool, so this is "try the free option, then the item" -- either line is a harmless no-op via WoW's own handling when unavailable/on cooldown/unknown. Soulstone is intentionally excluded -- it's a pre-placement buff on a living target, not something you click a corpse for.
- New persistent yellow status-dot indicator on a dead ally's square specifically when Soul Link is your only option and you're outside its 5-yard range -- clears the instant you're back in range or the situation changes.
- New on-screen alert (WoW's native error-banner style) naming who you're too far from, shown when you actually attempt to use Soul Link while still out of range.
- New option: "Emergency Soul Link on dead allies" (Interface Options -> Decursive), on by default. Also available via `/dcrsoullink`.
- Confirmed via testing: players cannot battle-rez AI followers in solo Follower Dungeons at all -- that's a hard Blizzard restriction with no addon workaround, not a bug. Works as expected against real players in a real group.

## Fix: DandersFrames installed no longer silently disables native-only features
- Having DandersFrames installed was auto-opting Decursive into the DandersFrames detection provider on first run whenever it was detected as usable, with no visible indication. Since native-only features (the debuff-identity tooltip, and now the battle-rez indicator above) depend on the native provider, this silently broke them the moment DandersFrames was present. Native detection is now always the default; DandersFrames integration requires an explicit opt-in.

## Fix: MUF squares not repopulating after a follower-dungeon death/disband/reform cycle
- A follower-dungeon death/disband/revive/reform cycle never fires `PLAYER_ENTERING_WORLD` (you never actually leave the instance), only a burst of `GROUP_ROSTER_UPDATE` -- which only ever triggered a lightweight scheduled display update, never the thorough reset-and-rebuild that a real zone transition gets. Confirmed via diagnostic logging: MUFs randomly missing (often just the player and pet) after that cycle, always fixed by a full `/reload`. `GROUP_ROSTER_UPDATE` now triggers the same thorough rebuild zone transitions already used.

## v11.0.34

## Fixes MUF squares not repopulating after death/revive
- `PLAYER_ALIVE` unregistered itself after the first time it fired, so only the very first revival of a session (typically at login) ever triggered a MUF reconfigure. Every death/rez after that -- including the disband/reform cycle in follower dungeons -- silently skipped it, leaving squares missing until a manual `/reload`. The handler now stays registered and reconfigures on every revival.

## v11.0.33

## Default to native detection even when DandersFrames is installed
- Having DandersFrames installed was silently auto-switching Decursive's detection provider away from native on first run, which disables the native-only debuff-identification tooltip with no indication why. Native detection is now the default regardless of DandersFrames' presence; DandersFrames integration is opt-in only.

## v11.0.32

## Critical: fixes crash on secret enemy spell IDs
- `GetDispelDBEntry`/`GetEncounterDBEntry` indexed their spell-ID lookup table directly with the spell ID from `UNIT_SPELLCAST_SUCCEEDED`/`UnitCastingInfo`, which WoW 12.1 can mark secret for some enemy casts -- confirmed in-game ("attempted to index a table that cannot be indexed with secret keys", crashing the debuff-identification cast watcher). Both lookups now bail out safely via `issecretvalue` instead of indexing with a secret key.

## v11.0.31

## Critical: fixes "mixed versions detected" false positive
- The `@project-version@` restoration in v11.0.29 only covered `.lua` files -- the 7 `.xml` files (`embeds.xml`, `Dcr_DIAG.xml`, `Decursive.xml`, `Dcr_lists.xml`, `Dcr_LiveList.xml`, `Dcr_DebuffsFrame.xml`, `Localization/load.xml`) still had their version stamps hardcoded to the literal "11.0.10". Now that `dcrDiag`'s mixed-version detection actually works (fixed in v11.0.29), this stale stamp made every real release since then falsely report "installation is corrupted, mixed versions detected!" on load. Fixed by applying the same token restoration to all 7 XML files.

## v11.0.30

## Critical: fixes "Decursive installation is corrupted!" on load
- The packager's `--@debug@`/`--@end-debug@` inline preprocessing was duplicating the closing `]==]` bracket on these blocks in every packaged build, producing a Lua syntax error that aborted the whole file and cascaded into a fatal "installation is corrupted!" popup on every login. This is what actually broke v11.0.28 and v11.0.29 in-game. Fixed by making these blocks permanently inert instead of packager-processed (no behavior change for our retail build, which never used the debug-activation path anyway).

## OnBackdropSizeChanged warning fix
- `BackdropTemplateMixin` exists in 12.1 but no longer defines `OnBackdropSizeChanged`, producing a Lua warning on the main bar frame. Now copies Blizzard's mixin and backfills only the missing method instead of an all-or-nothing fallback.

## v11.0.29

## CurseForge changelog fix
- `.pkgmeta`'s manual changelog was pointed at the legacy `WhatsNew.md` (stuck at "2.8.3", predating this fork's WoW 12.1 work) instead of the actively maintained `CHANGELOG.md`. Every CurseForge upload was embedding the wrong, outdated release notes as a result. Releases from this version onward pull from `CHANGELOG.md`.

## Retail-only CI
- Removed the classic/mists/bcc packaging jobs from GitHub Actions -- `Decursive.toc` doesn't declare classic-compatible interface versions, and this release line targets retail only.

## v11.0.28

## Season 2 Mythic+ interrupt alerts
- New EncounterDB (`Database/EncounterDB_Core.lua`, `Database/Encounters/Midnight.lua`) covering 36 verified priority interrupts across all 8 Season 2 dungeons.
- An enemy-cast watcher (`Dcr_12_1_Encounters.lua`) drives an on-screen alert popup and a chat message when a tracked interrupt is cast nearby, plus an optional DBM early-warning bridge.
- Detection is native (`UNIT_SPELLCAST_START` on nameplates/boss/target/focus units) -- no external addon required.

## Debuff identification on MUF hover
- WoW 12.1 blocks any secure-click addon from reading a debuff's real identity through any API (live query, the newer `C_UnitAuras.GetUnitAuras`, or the combat log) -- confirmed this patch via extensive in-game testing, matching the exact restriction DandersFrames itself hits.
- New: a real, secret-safe native Blizzard tooltip on hover, modeled on DandersFrames' own mechanism (a dedicated AuraSlot with `SetTooltipAnchorPoint`/`SetHideTooltipInCombat`), created safely at MUF-init time. Shows dispellable debuffs by default; `/dcridentity alldebuffs` toggles to show all harmful debuffs.
- Falls back to a "best guess" from the enemy's own recent cast when the native tooltip isn't available (e.g. DandersFrames integration active).

## Status dot
- The MUF status light now stays hidden while idle instead of always showing gray, appearing only for range/fail/success states that need attention.

## v11.0.26

## Spam-click false red fix
- Debounced the post-cure status light: re-clicking the same MUF within 2 seconds of a successful cure no longer flashes red when the repeat cast instantly errors ("Nothing to Dispel") against an already-cleared target.
- Reuses the existing out-of-range suppression mechanism rather than adding new state.

## Season 2 Mythic+ dispel database
- Added dispellable-debuff entries for all 8 Season 2 (patch 12.1) Mythic+ dungeons: Altar of Fangs, Murder Row, Den of Nalorakk, The Blinding Vale, Voidscar Arena, Kings' Rest, Ruby Life Pools, and Temple of Sethraliss.
- Spell IDs cross-checked against Wowhead; entries with an unresolved buff/debuff-direction conflict in source material were left out rather than guessed.
- Fixed a pre-existing King's Rest entry (spell 270920) that was mislabeled "Seduction" — it's actually "Bind Soul", verified against Wowhead.

## Website update
- `X-Website` metadata and the Readme.md download link now point to https://github.com/randylorfing/Decursive/.

## Maintainer contact update
- Addon `Author` metadata, the `D.author` variable, and the in-game About page now show Randy Lorfing.
- Bug-report contact (`X-eMail` metadata and the debug-report fallback address) now points to randylorfing@gmail.com.
- Original GPL copyright headers crediting John Wellesz (2006-2025) are unchanged.

## Zhaohu-Decursive
- Fixed a settings-page rebuild error caused by calling `SetScript("OnClick")` on a pooled plain `Frame`.
- Pooled toggle rows now retain the child switch button handler while their option state is safely rebound on reuse.
- Prevents intermittent blank pages / first-click navigation failures caused by the rebuild abort.
- No MUF, zoning, provider, DispelDB, or aura-sound logic changed.

- Stabilized settings navigation: destination pages are initialized/shown before old pages are hidden.
- Navigation now honors each page's `Refresh()` contract instead of force-rebuilding option pages on every click.
- `Spells & Bindings` is no longer torn down/recreated just by navigating to it.
- Sidebar buttons now store their destination key directly instead of relying on loop-captured callbacks.

- Restored the physical addon root folder to `Decursive` so the physical and internal addon identities match.
- Fixed settings sidebar navigation with a minimal `ShowPage()` change: all previously built content pages are hidden before the requested page is refreshed and shown.
- Kept the menu fix isolated from MUF, zoning, DandersFrames, secure-frame, and aura-provider code.
- Changed the fresh/default dispel notification to **Female Voice — Dispel** without intentionally overwriting saved user selections.
- Preserved the working 12.1 DispelDB aura-sound engine, zoning soft reinitialization, and DandersFrames integration toggle.

## Zhaohu test build square-sound18-danders-toggle
- Added a persistent DandersFrames integration toggle under Integrations.
- First-run default: enabled automatically when DandersFrames and its public AuraContainer API are detected.
- Once the user explicitly changes the toggle, that preference is preserved across reloads/logins.
- Disabling the integration selects Decursive's Native Blizzard-managed provider on the next UI reload.
- Re-enabling DandersFrames likewise requires a UI reload because protected AuraContainer topology is session-latched.
- When DandersFrames is unavailable, the integration control is disabled and native detection remains active.
- Preserves the square-sound16+ zoning reinitialization and working local DispelDB/native aura-sound engine.

# Zhaohu's Decursive v11.0.10

## MUF-Linked Sound Trigger Hardening
- Sound alerts are now explicitly tied to units that are currently assigned to Decursive Micro Unit Frames.
- Added a dedicated `UNIT_AURA` listener for the sound engine so live alerts do not depend on another Decursive event handler remaining installed.
- A MUF unit changing from clean to player-dispellable requests the selected alert through the shared group-wide debounce gate.
- Remaining afflicted stays silent; returning clean re-arms that MUF for the next affliction.
- Group, role, specialization, and world-entry changes silently re-seed MUF sound state to prevent false alerts while frames are being reassigned or sorted.
- The live query remains `HARMFUL|RAID`, Blizzard's WoW 12.1 filter for harmful auras the active player can dispel, matching the actionable condition represented by Decursive's managed MUF overlay.

## Added User Voice Pack
- Added four user-provided natural voice alerts as selectable Sound Notification presets: **Dispel**, **Dispel me**, **Cleanse**, and **Cleanse me**.
- Source MP3 files were converted to OGG for consistent in-game playback.
- Existing 18 sounds remain available, bringing the selector to **22 total alert choices**.
- All new voices use the same master enable switch, output channel, Test Sound button, and configurable 2-second group-wide debounce.

---

# Zhaohu's Decursive v11.0.9

## MUF-Affliction Sound Trigger
- Replaced the unreliable learn-first protected-aura sound path with a live WoW 12.1 MUF-state trigger.
- Sound alerts now use Blizzard's opaque aura-instance-ID query with `HARMFUL|RAID`, which represents harmful auras the active player can dispel.
- Decursive never reads protected aura names, spell IDs, dispel types, durations, stacks, or managed AuraButton visibility.
- A unit transition from clean to dispellable requests the configured alert sound.
- Remaining afflicted does not retrigger the sound; returning clean re-arms that unit.
- All units still share the configurable group-wide debounce window (2.0 seconds by default).
- MUFs are silently seeded when created/retargeted so entering a group or a spec change does not create false alerts.
- The older learned spell-ID system remains only as a fallback if the opaque-ID API is unavailable.
- Preserves the v11.0.8 follower-dungeon roster stabilization and all 18 sound choices.

---

## v11.0.8 — Follower Dungeon Spec-Change Roster Guard

- Fixed the remaining follower-dungeon issue where changing the player from a DPS specialization to a healer specialization could leave only the player and pet MUFs visible until `/reload`.
- Root cause: during the role/spec transition, Blizzard can briefly expose an incomplete follower-party membership snapshot while secure party frames are being rebuilt/re-sorted. v11.0.5 retried the scan, but it still committed the bad snapshot first, causing the missing MUFs to be hidden.
- Decursive now keeps a **last-known-good party roster snapshot** and refuses to replace it with a smaller transient roster during the bounded post-specialization recovery window.
- With DandersFrames active, Decursive also uses the published `DandersFrames_GetFrameForUnit(unit)` lookup as a supplemental presence signal during the transition.
- DandersFrames `OnFramesSorted` now immediately nudges Decursive's post-spec roster recovery so the MUFs can follow the new healer/DPS sorted position without waiting for a later generic refresh.
- Added `PLAYER_ROLES_ASSIGNED` as a second stabilization trigger after the specialization change. This restarts/extends the bounded recovery window at the point where role-based frame sorting commonly settles.
- Recovery retries now run at approximately 0.10, 0.35, 1, 2, 4, 7, and 10 seconds, with a 12-second last-known-good roster protection window.
- The protection applies only around a specialization/role transition; normal party joins/leaves continue to update normally outside that short window.
- Preserved all v11.0.7 sound additions, the 2-second notification debounce, automatic DandersFrames provider/order integration, native fallback, Party/Raid MUF sizing, and previous production fixes.

## v11.0.7 — Expanded Alert Sound Library

- Added **15 new dispel notification sounds**, bringing the Sound Notifications selector to **18 total choices**.
- Added seven new short combat tones: Bright Ping, Double Ping, Triple Ping, High Chime, Low Chime, Rising Pulse, and Falling Pulse.
- Added eight original synthesized voice callouts: Dispel, Cleanse, Cure, Help, Cleanse me, Cure me, Help, cleanse me, and Help, cure me.
- Voice and tone alerts use the existing master Sound Notifications switch, output-channel selection, and deterministic group-wide debounce.
- A group-wide affliction still produces only one accepted alert during the configured burst-ignore window, regardless of which sound preset is selected.
- Existing profiles retain their currently selected alert sound after upgrading.

## v11.0.6 — Sound Notifications

- Added a dedicated **Sound Notifications** settings page.
- Added a master **Enable sound notifications** toggle and moved the legacy dispel-sound control out of General.
- Added a configurable **Burst ignore window**, defaulting to **2.0 seconds**.
- The debounce is now deterministic and group-wide: the first accepted dispel alert starts the timer and every additional alert request during the window is discarded.
- Fixed an edge case where the old timestamp-style debounce could suppress an alert during the first seconds after UI load.
- **Test dispel alert** bypasses the debounce without resetting or extending the live alert timer.
- Added selectable alert sounds: the classic Affliction Alert, Quick Pulse, and Short Alert.
- Added selectable output channels: Master, Sound Effects, Dialog, Ambience, and Music.
- Added an independent **Play cure-failure sound** toggle.
- Updated Decursive's safe sound wrapper so notification sounds respect the selected output channel.
- Added learned WoW 12.1 protected-aura alerts without reading protected AuraButton state.
- When a successful player dispel exposes a public aura spell ID, Decursive learns that ID for the current class/spec.
- Future public `SPELL_AURA_APPLIED` combat-log events for learned IDs are routed through the same exact debounce gate as other Decursive alerts.
- A group-wide Poison/Magic/Disease/Curse application therefore produces one alert, then suppresses additional group-member alerts for the configured window.
- Direct `C_UnitAuras.AddAuraSound` playback is intentionally not used for live alerts because Blizzard plays those sounds internally and does not expose a callback that Decursive can safely debounce across units.
- If WoW hides the combat-log spell ID for a protected aura, Decursive leaves that occurrence visual-only instead of using an unthrottled sound fallback.
- Added manual **Add protected aura Spell ID** and **Clear learned aura IDs** controls.
- Learned IDs are capped to the 32 most recent entries per class/spec.
- Preserved v11.0.5 specialization-change roster recovery, automatic DandersFrames provider selection/order mirroring, native fallback, Party/Raid MUF sizing, and the Blizzard Settings/Escape-menu fix.

## v11.0.5 — Spec-Change MUF Roster Recovery

- Fixed a follower-dungeon issue where changing specialization could leave only part of the Decursive MUF row visible until `/reload`.
- The issue was reproducible when DandersFrames re-sorted the player's frame during a specialization change, such as Elemental Shaman -> Restoration Shaman.
- Added a bounded post-specialization roster stabilization sequence. Decursive now re-reads the current Blizzard party/raid roster several times while the specialization and secure unit-frame sort settle.
- Each recovery pass rebuilds the Blizzard unit array first, then applies the latest DandersFrames frame order when that provider is active.
- Prevents a transient follower/party roster snapshot from becoming the persistent MUF list.
- If a specialization change occurs during combat lockdown, the secure MUF rebuild is deferred until combat ends.
- Automatic DandersFrames provider selection and native Blizzard fallback behavior from v11.0.4 are unchanged.

## v11.0.4 — Automatic DandersFrames Provider + MUF Order Mirror

### Packaging Correction

- Fixed a mixed-version fatal startup error in the initial v11.0.4 package.
- Updated `embeds.xml`, XML UI files, and localization loader self-check stamps from `11.0.2` to `11.0.4`.
- Audited every file in Decursive's internal `_LoadOrderedFiles` integrity check; all active self-check version values now resolve to `11.0.4`.
- No provider-selection or gameplay behavior was changed by this packaging correction.

- Built directly from the v11.0.2 production baseline; the abandoned v11.0.3 status-indicator toggle is not included.
- DandersFrames provider selection is now automatic at startup.
- If DandersFrames is installed/enabled and its public AuraContainer API is available, Zhaohu's Decursive automatically selects DandersFrames as the protected dispel-detection provider.
- When DandersFrames is selected automatically, Decursive MUFs also automatically mirror DandersFrames' published unit-frame order.
- No manual DandersFrames integration toggle is required.
- If DandersFrames is not installed, is disabled, or its provider API is unavailable at startup, Decursive automatically uses the native Blizzard-managed detection provider.
- Provider selection remains session-latched so protected AuraContainer topology is never swapped during combat or mid-session.
- The Integrations page now reports automatic provider selection instead of presenting a manual provider switch.

## v11.0.2 — Blizzard Settings / Escape Menu Hotfix

- Fixed an issue where opening **Settings → AddOns → Zhaohu's Decursive → Open Zhaohu's Decursive** could prevent the Escape/Game Menu from reopening until `/reload`.
- Replaced the direct `SettingsPanel:Hide()` launcher behavior with Blizzard's managed Settings exit path so UIParent's panel state is cleaned up correctly.
- Preserves Blizzard's normal unapplied-settings confirmation instead of silently discarding or forcing pending changes.
- The standalone Zhaohu v11 settings window is now registered as an Escape-closeable special frame, so pressing `Esc` closes it naturally before opening the Game Menu.
- Retains the v11.0.1 independent Party/Raid MUF sizing feature and all v11.0.0 production behavior.

## v11.0.1 — Separate Party and Raid MUF Sizes

- Added independent **Party MUF size** and **Raid MUF size** controls under **Micro Unit Frames → Layout & Display**.
- Party size is used whenever the player is not in a raid, including solo/open world, normal parties, follower dungeons, dungeons, and Mythic+.
- Raid size is applied automatically whenever WoW reports the player is in a raid.
- Existing profiles migrate safely: both new values initially inherit the user's current MUF size, so upgrading does not unexpectedly resize frames.
- Group transitions automatically switch to the appropriate size.
- Size transitions that occur while secure frames are combat-locked are deferred until combat ends.
- Legacy single-size controls are retained internally for compatibility but are hidden from the v11 settings UI.

## v11.0.0 — Production Release

- Fixed the MUF Colors-page control layout so Edit Color buttons no longer overlap alpha sliders or percentage steppers.

- Promoted the tested alpha.23 codebase to the v11.0.0 production release for WoW 12.1.
- Native Blizzard managed AuraContainer/AuraSlot detection is the default provider and no longer requires DandersFrames.
- Preserved DandersFrames as an optional integration/provider; enabling it remains a user choice and it is not disabled or removed.
- Includes native dispel detection, MUF affliction rendering, secure curing, cooldown overlays, post-cure verification, range/status feedback, player/pet support, raid layout, profiles, environment modes, and the modern v11 settings interface.
- Removed alpha-only runtime build flags so the package identifies and behaves as a stable production build.

## v11.0.0-alpha.23 — Native AuraSlot Rendering Fix

- Fixed native Blizzard-API dispel detection where the status circle updated but the MUF square itself could remain unlit.
- Direct Blizzard `AddAuraSlot()` buttons are now explicitly anchored over their owning MUF, matching the proven geometry used by the DandersFrames AuraContainer path.
- Applied the same native slot anchoring to remaining-target cooldown carriers and post-cure verification carriers so native mode uses one consistent rendering model.
- Corrected native cooldown carrier initialization to Blizzard's required order: `SetUnit` -> `AddAuraSlot` -> anchor slot -> `SetEnabled` last.
- Added an initial `UpdateAllAuras()` dirty-mark after native carriers are armed so pre-existing Poison/Magic/Disease/Curse auras appear immediately.
- DandersFrames integration remains optional and unchanged; native Blizzard API mode remains the default.

## v11.0.0-alpha.22 — Native Blizzard Provider Parity

- Rebuilt the native 12.1 provider so it follows the same protected-dispel workflow as the DandersFrames provider while querying Blizzard's managed AuraContainer API directly.
- Native detection now uses separate Blizzard-managed priority AuraSlots filtered by Decursive's configured dispel types; addon Lua never reads protected aura identity or presence.
- Added native protected post-cure verification carriers. A successful cure shows green for 3 seconds only while no matching protected dispel need remains; if the matching affliction remains, the native verifier paints the status light red for the same 3-second result window.
- Native status-light range now uses the configured friendly cure spell through `C_Spell.IsSpellInRange()` with `UnitInRange()` fallback. Secret booleans are passed directly to Blizzard's boolean-aware texture API, giving native mode the same Yellow > Red/Green > Gray precedence as DandersFrames mode.
- Native remaining-target cooldown carriers are now static Blizzard-managed AuraSlots created before combat. Decursive only changes an addon-owned holder alpha when the public cure cooldown starts/stops, matching the DandersFrames carrier strategy and avoiding live combat filter retuning.
- Added native carrier retry after combat when the addon/MUFs initialize during combat.
- DandersFrames remains completely optional. When disabled, all MUF status lights, cure-result timing, remaining-target cooldown overlays, player/pet handling, secure clicks and raid layout continue natively from Blizzard APIs.
- Provider-specific differences remain intentional: DandersFrames integration can mirror DandersFrames' custom unit ordering and uses the dedicated DandersFrames behavior profile; native mode uses Decursive's own roster ordering and Open World/Dungeon/Mythic+/Raid/PvP behavior profiles.

## v11.0.0-alpha.21 — Blizzard Settings Integration

- Added **Zhaohu's Decursive** to Blizzard's **Settings → AddOns** list using the current Settings API.
- Added a lightweight native Blizzard status/launcher page showing the active user profile, detection provider, behavior profile, character/spec and combat configuration state.
- Added quick actions for the full v11 settings window, Integrations, Diagnostics, 12.1 Status, Profiles & Modes, and MUF show/hide.
- The Blizzard page is intentionally **not a second settings system**; all configuration remains in the single resizable v11 interface.
- DandersFrames status text clearly describes the provider boundary: DandersFrames supplies protected dispel detection/range/order data while Decursive owns MUFs, secure curing, cooldowns and status feedback.

## v11.0.0-alpha.20 — Reliable Cure Result Status + Yellow Priority

### MUF status result events
- Fixed the 12.1/Midnight status-light result path: red and green no longer depend on the legacy combat-log `ClickedMF` flow that is disabled in Midnight.
- Added modern `UNIT_SPELLCAST_SUCCEEDED`, `UNIT_SPELLCAST_FAILED`, and `UNIT_SPELLCAST_INTERRUPTED` handling tied to the secure MUF click tracker, plus a short-window `UI_ERROR_MESSAGE` fallback for instant failures such as line of sight.
- A failed configured cure now produces a three-second red result state.
- A successful configured cure starts DandersFrames protected post-cure verification; the light is green for three seconds only when the matching affliction is no longer present, while the protected verifier paints it red if the dispel need remains.

### Range precedence
- DandersFrames yellow/out-of-range is now a hard visual override for result feedback. An explicit out-of-range cast error is kept yellow and suppresses the transient red result.
- The possibly-secret `dfInRange` boolean is passed directly into Blizzard boolean-aware texture APIs; Lua never branches on it.
- Red/green result layers are suppressed while yellow is active, then the light returns to the live range/ready state when the three-second result window expires.
- Native detection follows the same visible precedence using Decursive's non-secret range state.

## v11.0.0-alpha.19 — Verified Cure Status Lights

- Added a green per-MUF success state: when a cure clears the affliction, that MUF's status circle stays green for 3 seconds.
- With DandersFrames integration active, post-cast success/failure is verified visually through a prebuilt DandersFrames protected AuraContainer carrier; Decursive does not read protected aura state back into Lua.
- The verification carrier is filtered to the cure priority used for the clicked MUF. If the matching dispellable affliction remains after the cast, a red circle covers the green success base; if it is gone, the green confirmation remains visible.
- All actual cure failures now produce red feedback, including an out-of-range cast attempt. DandersFrames' proactive out-of-range state remains yellow before a cast is attempted; after red expires, it returns to yellow if still out of range.
- SPELL_MISSED, SPELL_DISPEL_FAILED, LoS, invalid-target and other failed-cast paths cancel green verification and show red.
- Verification carriers are created before combat, use static DandersFrames candidate filters, and are only intent-shown during the short post-cast verification window.
- Native detection mode also receives the 3-second green successful-cast confirmation; DandersFrames remains the protected post-affliction verification source when its integration is enabled.

## v11.0.0-alpha.18 — DandersFrames Range-Driven Status Lights

- When DandersFrames integration is active, each MUF status light now mirrors the corresponding DandersFrames frame's live `dfInRange` result.
- WoW 12.1 secret range booleans are passed directly into `Texture:SetVertexColorFromBoolean()`; Decursive does not inspect or branch on protected range values.
- Yellow now means DandersFrames reports the unit out of range. Gray means DandersFrames reports the unit in range.
- Red still takes priority after a failed cleanse. Line-of-sight remains failure-driven because DandersFrames and the WoW API do not expose a continuous public LoS state.
- Native detection mode keeps Decursive's existing range/status-light logic.

## v11.0.0-alpha.17 — Per-MUF Status Lights + Raid Grid

- Removed the alpha.16 status-color behavior from the original hidden MUF move handle; the move handle is back to movement/quick-access duty only.
- Added one dedicated, always-visible, non-clickable status light above every displayed MUF.
- Status lights are solid circles sized to 25% of the MUF square: gray = ready, yellow = out of cleanse range, red = a cleanse attempt failed for a non-range reason.
- Red failure state is tracked per clicked MUF and expires automatically; successful casts clear the clicked MUF's transient failure state immediately.
- Added vertical cell spacing that reserves room for the status light so lights cannot collide with MUFs in adjacent raid rows.
- Added Automatic raid grid (enabled by default). Raids larger than five players reflow into a compact grid capped at five rows; a 40-player raid uses an 8 × 5 layout.
- DandersFrames integration continues to control MUF unit order. The raid grid changes only Decursive's visual arrangement, not DandersFrames-derived sequence.
- Manual Units per row remains available and is used whenever Automatic raid grid is disabled.
- Screen-clamping calculations now include the status-light footprint so the top indicator is kept on-screen with its MUF.

## v11.0.0-alpha.16 — MUF Handle Status Light

- The small move handle above MUF #1 now doubles as a castability/status light while retaining all Alt-drag/quick-access behavior.
- Yellow indicates the MUF currently under the mouse is outside configured cleanse range; an explicit out-of-range cleanse failure holds yellow briefly so the reason is visible even after the pointer moves.
- Red is shown briefly after a cleanse attempt fails for any non-range reason, including line-of-sight, invalid-target, missed and dispel-failed outcomes.
- Red has priority over yellow so an actual failed cleanse is never hidden by the range state.
- Successful cleanses clear the transient handle failure state immediately.
- The status-light logic is provider-independent and does not read DandersFrames aura internals or protected aura state.
- Includes the alpha.15 DandersFrames MUF-order synchronization work: when DandersFrames integration is active, Decursive MUFs mirror DandersFrames' public frame order.

## v11.0.0-alpha.15 — DandersFrames MUF Order Synchronization

- When DandersFrames integration is active, Decursive Micro Unit Frames now mirror DandersFrames' party/raid/arena unit-frame order.
- Uses DandersFrames' published `DandersFrames_GetFrameForUnit(unit)` API and `OnFramesSorted` callback; no private DandersFrames sort tables are read.
- DandersFrames re-sorts trigger a Decursive MUF order refresh. If the re-sort happens during combat, the protected MUF reassignment is queued until combat lockdown ends.
- Decursive-only units that do not have a main DandersFrames frame (for example focus/pet entries) remain supported and are appended after DandersFrames-matched group members in their previous relative order.
- Integration status now reports the MUF-order synchronization method and number of matched DandersFrames frames.
- Native Decursive ordering remains unchanged whenever DandersFrames integration is disabled.

## v11.0.0-alpha.14 — Full UI Architecture + Resize + LoS Feedback

- Reviewed every v11 settings page and reorganized the navigation into Overview, Curing, Display, Profiles and System groups.
- Made the v11 settings window resizable (960×650 minimum, 1500×1000 maximum) and persist its size per user profile.
- Added a scrollable grouped sidebar so new dedicated pages do not crowd or clip on smaller window sizes.
- Rebuilt Micro Unit Frames into purpose-focused subsections: Layout & Display, Spacing & Opacity, Colors and Performance.
- Broke Bleed Management out of the general Curing page with separate Discovery/Keywords and Known Bleed Effects subsections.
- Split Affliction Filters into Filter Rules and Ignored Afflictions subsections.
- Separated Cooldowns from Range & Visibility.
- Added a dedicated Range & Visibility page with environment-aware out-of-range controls and colors.
- Added transient Line-of-Sight feedback: a failed cleanse caused by SPELL_FAILED_LINE_OF_SIGHT marks only that MUF with a configurable LoS color for a configurable time; LoS no longer reuses the generic blacklist color.
- DandersFrames remains detection-only: LoS feedback comes from Decursive's own cleanse result and does not read DandersFrames internals or protected aura details.
- Flat, already-focused pages (Messages, Macro, Live List, Import/Export, Integrations, Diagnostics and About) remain dedicated pages instead of being fragmented unnecessarily.

# Zhaohu Decursive v10.43 - WoW 12.1 Profile Framework

- Added embedded AceSerializer-3.0 from the Ace3 library stack.
- Extended the existing AceDB/AceDBOptions profile system with current-profile import/export.
- Added a Profile Import / Export section to Decursive options.
- Imports preserve AceDB profile table identity and rebuild Decursive runtime state safely.
- Profile exports intentionally exclude global, locale, and class-scoped data to avoid destructive cross-character imports.
- Retains the v10.42 protected Live List fix and WoW 12.1 managed-aura-only detection path.

# Zhaohu 12.1 Compatibility Patch v10.42 — 2026-08-20

- Fixed `Dcr_LiveList.lua:415` Lua error in WoW 12.1 protected-aura mode.
- Removed calls to nonexistent `LiveList:AddLineToFrame()` and `LiveList:PostCreate()` helpers.
- The legacy Live List now safely hides its rows while 12.1 protected aura data is unavailable.
- Added a one-time chat notice directing players to the Blizzard-managed Micro Unit Frames for protected dispel detection.
- The notice resets after leaving protected mode so it can appear once on a later protected-mode transition without timer spam.


# Zhaohu 12.1 Compatibility Patch v10.41 — 2026-08-20

- Made Blizzard-managed `AuraContainer` / `AuraButton` filtering mandatory for dispel detection on WoW Retail 12.1.
- Removed the Open World `MANAGED_LEGACY_SAFE` policy; existing saved environment profiles migrate to `STRICT_MANAGED`.
- Disabled legacy Lua aura enumeration throughout the 12.1 runtime.
- Reworked `UnitClass`, `UnitRace`, `UnitIsCharmed`, and `UnitIsPossessed` wrappers to validate returned values with `canaccessvalue()` instead of blanket-blocking non-player units merely because combat is active.
- Fixed two MUF class-color callers that discarded the second `UnitClass()` return value when using the 12.1 wrapper.
- Updated the options panel to show the enforced Strict Managed policy rather than offering a legacy fallback.


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

## v10.34 - Cure-Range Detection Fix

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

- Fixed out-of-range state remaining on the normal priority color.
- Range detection now checks Decursive's configured friendly cure spells instead of relying only on generic `UnitInRange()`.
- If all configured cure spells report the unit out of range, the MUF displays the configured out-of-range color.
- Raised the addon-owned range overlay above the managed priority fill so yellow visibly overrides red/blue while out of range.
- No protected aura details are inspected.

## v10.33 - Yellow Out-of-Range Default

- Changed the default out-of-range MUF overlay color from black to yellow.
- Out-of-range units now use a yellow range-state tint by default for immediate recognition.
- The out-of-range color remains fully configurable under Micro Unit Frame Settings -> Display Options.
- Reset Out-of-Range Color now restores yellow with the existing 60% overlay amount.
- Existing users who already saved a custom range color keep their saved setting; the new default applies to new/reset configurations.
- No changes to managed priority detection, cleanse logic, or cooldown handling.

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

## v10.26 - Forbidden-object hardening

- Removed the unsafe shared-priority cooldown gate implementation.
- Fixed `calling 'Hide' on bad self` / forbidden-object errors caused by dynamic cooldown children parented to Blizzard managed AuraButtons.
- Blizzard-managed AuraContainer/AuraButton objects are now used only for Blizzard-controlled affliction visibility and priority coloring.
- No dynamic cooldown/tint frame is created under a Blizzard-managed aura object.
- Live cooldown tint and timer are rendered only on Decursive-owned MUF overlay frames.
- Removed post-initialization `UpdateAllAuras()` forcing from the managed priority-color refresh path.
- Disabled priority-gate SetUnit/filter mutation paths that existed only for shared cooldown propagation.
- Preserved working Blizzard-managed Magic/Poison/Curse/Disease priority coloring.
- Preserved per-clicked-MUF cooldown timer/tint and all diagnostic test tools.
- The experimental shared cooldown across same-priority afflicted MUFs is intentionally disabled because WoW 12.1 can mark the managed aura branch and descendants forbidden when aura state is secret.

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

# Changelog

## v10.18 - Two-layer simultaneous-affliction model

- Simplified live dispel visuals to a maximum of two simultaneous dispellable auras per MUF.
- The first/primary dispellable aura always owns the inner square, regardless of whether it maps to Decursive Priority #1, #2, or #3.
- A second simultaneous dispellable aura uses one pulsing border in that aura's Blizzard-managed priority color.
- Removed the third managed aura slot and the second outer border.
- Removed Priority #3 outer-border controls from the options and diagnostic preview.
- Priority #3 remains fully supported as a curing priority; when it is the only active affliction, its color appears in the inner square.
- Cooldown behavior remains per-square: the clicked priority transitions to a faded version of its own priority color with a white timer.

---

## v10.17 - Stacked simultaneous-affliction visuals

- Changed managed MUF alert logic from fixed priority layers to simultaneous-affliction slots.
- A single dispellable affliction always owns the inner square, regardless of whether it maps to Priority #1, #2, or #3.
- The inner square color is supplied by Blizzard's protected dispel-type evaluation and mapped to the affliction's configured Decursive priority color.
- A first border is shown only when a second simultaneous dispellable aura is present; it uses that second aura's configured priority color and pulses.
- A second outer border is shown only when a third simultaneous dispellable aura is present; it uses that third aura's configured priority color and pulses.
- Increased the managed aura group from one to three managed aura slots so simultaneous dispellable effects can be represented without Decursive reading protected aura types.
- Existing per-square cooldown behavior remains unchanged.

---

## v10.16 - Blizzard-managed priority dispel visuals

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



## v10.6
### Priority #2 Pulsing Border Test

- Updated the MUF visual test to reinforce the priority layout:
  - **Priority #1** uses the inner square and countdown timer.
  - **Priority #2** uses the outer MUF border.
- The Priority #2 border now pulses to make the secondary curing priority more noticeable.
- Added **Pulse Priority #2 cooldown border** under Micro Unit Frame display options.
- The pulse can be enabled or disabled without changing the Priority #2 color, opacity, or thickness settings.
- The pulsing behavior works with both **Test selected MUF square** and **Test ALL MUF squares**.
- Pulse animation is performed only on addon-owned border textures; Blizzard-managed aura frames remain untouched.

---



## v10.4 - MUF Overlay Sync and Test Controls

- Changed cooldown overlay positioning to use Decursive's own MUF layout coordinates instead of reading geometry from secure MUF frames.
- Added a selectable **MUF square to test** control.
- Added **Test selected MUF square** for one-at-a-time verification.
- Added **Test ALL MUF squares** to preview every visible square simultaneously.
- Individual and all-square tests preview Priority #1 inner/timer and Priority #2 border for 8 seconds.
- Test mode remains visual-only and does not inspect protected aura data or cast spells.
# Changelog

## v10.1
### Per-Square Priority Cooldown Fix

- Reworked the WoW 12.1 cooldown visuals so every Blizzard-managed dispellable MUF owns its own cooldown widget.
- **Priority #1** now uses the inner square and Decursive's existing Priority #1 color.
- The Priority #1 numeric cooldown timer is rendered independently on each dispellable square.
- **Priority #2** now uses the MUF border and Decursive's existing Priority #2 color.
- Priority #1 and Priority #2 cooldown states can be visible at the same time when they use different curing spells.
- Added an option to enable or disable the Priority #2 cooldown border.
- Added Priority #1 inner opacity, Priority #2 border opacity, and Priority #2 border thickness controls.
- Removed the need for a custom cooldown-border color; the border now follows Decursive's configured priority color automatically.
- The cooldown spell state is global, but each MUF has its own visual widget.
- Cooldown visuals are children of Blizzard's managed aura buttons, so they naturally follow Blizzard's protected dispellable-unit visibility without Lua reading the protected aura type.
- Due to WoW 12.1 protected aura restrictions, Decursive still does not infer whether a specific unit's hidden aura is Magic, Poison, Disease, Curse, or Bleed.

---

## v10
### Configurable Cooldown Border Display

- Added three cooldown display styles for Micro Unit Frames:
  - **Overlay + Timer**
  - **Border + Timer**
  - **Border Only**
- Added a **Cooldown display style** selector under **Micro Unit Frame Settings → Display Options**.
- Added an adjustable **Cooldown border color** picker.
- Added adjustable **Cooldown border opacity**.
- Added adjustable **Cooldown border thickness** from 1 to 5 pixels.
- Preserved the master **Dispel cooldown overlay** enable/disable option.
- Preserved the optional numeric cooldown countdown.
- The compatibility border is drawn separately from Decursive's original class/status border so original MUF coloring remains intact.
- Updated the 12.1 Status page to report the selected cooldown display style and border settings.
- Updated the MUF visual test to preview the currently selected cooldown display style.
- No protected aura names, types, durations, or stacks are inspected by this feature.

---

# v9.1 - Stable Cooldown Rollback

- Removed the experimental per-cure-type MUF cooldown indicators introduced in v9.
- Restored the proven single primary-friendly-dispel cooldown overlay from v8.1.
- The cooldown resolver still follows Decursive's live class/spec/talent curing configuration.
- This avoids attempting to associate a secret 12.1 aura type with an individual MUF.
- Magic/Poison/Disease/Curse capability detection remains handled by Decursive, while Blizzard's managed aura container remains the authority for whether a unit is dispellable.
- No changes to secure cure clicks, managed aura detection, MUF sizing, status tools, or mouse bindings.

---

# Changelog

## v8 - Status, Testing, and Cooldown Polish

- Added a dedicated **12.1 Status** options page.
- Shows the current class/spec, detected friendly dispel spell, compatibility backend, MUF/container counts, cooldown settings, and combat-lockdown state.
- Added **Refresh detected dispel** for quick troubleshooting after class/spec/talent changes.
- Added `/dcrstatus` for a compact in-chat compatibility status report.
- Added **Test MUF visuals**, a visual-only preview of the 12.1 highlight/cooldown styling that does not inspect auras or cast spells.
- Added the currently detected cooldown dispel directly to **Custom Spells**.
- Added **Cooldown overlay darkness** control.
- Added **Show cooldown countdown number** toggle.
- Kept the existing enable/disable cooldown overlay option and MUF size controls.
- Updated patch metadata to v8.
- All 12.1 status/testing code intentionally avoids protected aura details.

## v7
### Options Menu Organization

- Moved **Mouse Bindings** out of **Micro Unit Frame Settings**.
- Mouse binding configuration is now located under:

  **Custom Spells → Mouse Bindings**

- No mouse-binding behavior was changed; this is a menu organization update only.
- Existing mouse assignments and saved settings are preserved.

---

# 12.1 Compatibility Patch Changelog

## v6 - Automatic cooldown spell detection
- Cooldown overlay now resolves the active friendly dispel from Decursive's live spell registry.
- Automatically follows specialization and talent changes.
- Respects enabled Decursive curing priorities.
- Excludes enemy dispels and charm-only utilities from cooldown tracking.
- Prefers Decursive's own best-ranked general-purpose friendly cleanse when multiple curing spells are available.

# Decursive  -Ace3-

## [2.8.2-2-g4a1865f](https://github.com/2072/Decursive/tree/4a1865fe2d850907321d89ff3af5a90ac7db74f6) (2026-08-17)
[Full Changelog](https://github.com/2072/Decursive/compare/2.8.2...4a1865fe2d850907321d89ff3af5a90ac7db74f6) [Previous Releases](https://github.com/2072/Decursive/releases)

- ...  
- - Better disabling of Decursive in 12.1 (notably prevents some possibilities to run some add-on command through LDB menus)  
    - Add diagnostic for the random taint error some people are still getting even while Decursive is disabled, hopefully this is an opportunity to finally identify the root cause of this random problem.  
    #skipclassic #skipmop #skipbcc  


## v10.21 - Managed Aura Pool Ordering Fix
- Fixed Blizzard AuraContainer pooled-frame ordering so priority textures are attached to the AuraButtons that actually become live slot #1 and slot #2.
- Priority colors now use Decursive's native `D.Status.dsCurve` when available.
- No change to secure cure-click behavior.

## v10.28 - Shared Priority Duration Binding
- Fixed shared-priority cooldown timer not appearing in restricted WoW 12.1 content.
- Removed the forbidden/unreliable AuraSlot:IsShown() -> SetAlphaFromBoolean() visibility bridge.
- Priority-specific AuraSlots now start parked and are activated by public candidate filters only while that priority's cure spell is on cooldown.
- Added a static faded priority fill to each priority AuraSlot.
- Added a C_DurationUtil DurationTextBinding to each priority AuraSlot for secret-safe white cooldown countdown text.
- The clicked/cleansed MUF is excluded from the shared cooldown gate; other units that still need the same priority receive the faded fill + countdown.
- No protected aura type, visibility, duration, name, or stack value is read by addon Lua.

## v10.32 - Configurable Out-of-Range Dimming
- Added a Decursive-owned out-of-range visual layer for MUFs.
- Out-of-range units are dimmed without replacing the underlying priority color.
- Added options under Micro Unit Frame Settings -> Display Options:
  - Dim MUFs when out of range
  - Out-of-range dim amount
  - Out-of-range overlay color
  - Reset out-of-range color
- Default tint is black at 60% dim strength.
- Range state is refreshed approximately five times per second.
- Protected/unknown range results are treated conservatively and are not used to infer secret aura state.
- The range overlay never mutates Blizzard-managed AuraButtons or AuraContainers.


## v10.35 - Strict Priority Filtering

- Tightened the WoW 12.1 managed-aura display so protected auras cannot fall back to Priority #1 merely because they are dispellable.
- Added an engine-side `candidateFilters.includeDispelTypes` allow-list containing only dispel types currently mapped by Decursive to configured friendly cure priorities.
- Removed the managed priority texture's fallback to the older shared `D.Status.dsCurve`; the managed display now uses the 12.1 compatibility curve built directly from current cure mappings.
- If a protected aura does not match a configured Decursive cure type, no priority color is shown.
- No legacy aura scanning or protected aura reads were added.

## v10.38
### Four Environment Profiles

- Added four environment-specific operating profiles: Raid, Mythic+, PvP, and Open World.
- Added Environment Mode setting with Automatic and manual overrides.
- Automatic detection uses Blizzard instance type and active Challenge Mode state.
- Added per-environment saved settings for range appearance and cooldown presentation.
- Raid defaults favor lower visual noise; Mythic+ favors stronger range/cooldown visibility; PvP enables the strict protected-aura path; Open World keeps balanced defaults.
- Environment transitions announce in Decursive output only when the effective mode actually changes.
- PvP enter/leave announcements are preserved.
- Added Challenge Mode start/completion/reset event handling so Mythic+ mode can switch promptly.
- Existing v10.37 visual settings are migrated into the initial Open World profile.

## v10.39
### Five Environment Profiles

- Added a fifth automatic environment profile: **Dungeon**.
- Automatic environment selection now resolves to: Raid, Mythic+, Dungeon, PvP, or Open World.
- Any `party` instance without an active Challenge Mode map uses the Dungeon profile.
- This includes Follower Dungeons, Normal dungeons, Heroic dungeons, Timewalking dungeons, and Mythic-0 dungeons.
- Active Challenge Mode party instances continue to use the Mythic+ profile.
- Added Dungeon to the manual Environment Mode selector.
- Added independent saved range/cooldown settings and defaults for Dungeon.
- Environment transition chat output now naturally reports `Dungeon` when entering these instances.
- The 12.1 Status page reports Dungeon as the active environment when selected.
- Profile Manager / import-export work remains separate from this environment-classification change.

## Zhaohu's Decursive 11.0.0-alpha.1 — Modern Foundation (2026-08-20)

- Started the ground-up v11 rebuild as a modular presentation/orchestration layer.
- Added a modern primary `/decursive` configuration window with sidebar navigation and live status.
- Added native v11 pages for Dashboard, Micro Unit Frames, Curing, Cooldowns & Range, Profiles & Modes, Import/Export, Priority & Skip, Mouse Bindings, Diagnostics, and Advanced Settings.
- Separated **user profile** (AceDB setup) from **environment mode** (Open World, Dungeon/Follower, Mythic+, Raid, PvP) in the new UI model.
- Added per-environment behavior editing without requiring the player to enter that environment.
- Preserved the v10.43 backend as a compatibility bridge so no existing curing, priority, skip, custom-spell, secure-binding, MUF, cooldown, or 12.1 managed-aura functionality is removed during migration.
- `/decursive`, `/zd` open the modern UI; `/dcrclassic` opens the existing AceConfig interface. Existing `/dcr` behavior remains available.
- Added `Modern/V11_REBUILD.md` documenting the migration rules and feature-parity strategy.
- The 12.1 detection policy remains **Blizzard-managed AuraContainer only**; legacy aura scanning is not reintroduced.


## v11.0.0-alpha.7 — Optional DandersFrames Detection Provider

- Added an **Integrations** page with an optional **Use DandersFrames for dispel detection** setting.
- Added `DandersFrames` as an optional addon dependency; it is not bundled and is only used when the integration is explicitly enabled.
- Implemented strict session-latched detection-provider selection. Changing providers requires `/reload` so protected aura-container topology is never swapped live.
- When DandersFrames integration is disabled, Zhaohu's Decursive continues using its existing Blizzard-managed AuraContainer detection path.
- When DandersFrames integration is enabled, DandersFrames' public `AuraContainer` factory becomes the **sole protected dispel-detection carrier**. The native Decursive detector is not created or consulted.
- The integration is intentionally detection-only: DandersFrames determines protected dispel-match presence through Blizzard-side candidate filters; Zhaohu's Decursive retains its MUFs, cure-spell mapping, secure mouse bindings/clicks, priorities, cooldowns, range behavior, profiles and environment modes.
- No DandersFrames unit-frame styling, sorting, layout, click-casting or profile settings are imported.
- Added per-cure-priority DandersFrames protected filter records so the existing Decursive cure-priority/spell mapping can be driven without reading secret aura data back into Lua.
- Adapted shared same-priority cooldown gates to use the selected DandersFrames provider rather than creating native Decursive AuraContainers.
- Added provider diagnostics including selected provider, DandersFrames version/API availability, carrier counts, reload-pending state and fail-closed reason.
- If DandersFrames is selected but unavailable/incompatible, detection now **fails closed** and displays a warning instead of silently falling back to or mixing with native Decursive detection.
- The integration never reads protected aura names, dispel-name strings, durations, stacks or AuraButton visibility from DandersFrames.

## v11.0.0-alpha.6 — Native Spells & Bindings UI

- Rebuilt **Spells & Bindings** as a purpose-built v11 page instead of rendering the legacy option tree generically.
- Added a clean active cure-assignment summary with the current 12.1 cooldown-dispel resolver result.
- Added native secure MUF mouse-assignment controls for cure priorities, target, and focus, including conflict-safe swapping and reset-to-defaults.
- Added native custom spell/item creation with the existing Decursive validation path and optional editable internal macro creation.
- Added expandable spell/item cards with enable/disable, cure-type selection, spell priority, pet ability, unit filtering, internal macro editing, and remove/hide controls.
- Fixed the overlapping text, clipped controls, and broken vertical layout visible on the alpha.5 Spells & Bindings page.
- No changes to the WoW 12.1 managed-aura detection engine or secure curing backend.

## v11.0.0-alpha.5 — Detect • Cleanse • Protect

- Updated the project motto to the exact branding: **Detect • Cleanse • Protect**.
- Updated the v11 header and internal branding references to use centered-dot separators.
- No curing, profile, MUF, binding, or WoW 12.1 managed-aura behavior changed in this build.

## v11.0.0-alpha.4 — Motto Branding

- Replaced the v11 header subtitle `Modern rebuild` with the project motto.
- Updated internal v11 branding references so the modern interface consistently uses the project motto.
- No curing, profile, MUF, binding, or WoW 12.1 managed-aura behavior changed in this build.

## v11.0.0-alpha.3 — New Branding

- Replaced the legacy Decursive radiation artwork with the new Zhaohu's Decursive logo supplied for the v11 rebuild.
- The new logo is now used by the modern v11 header, addon list icon, minimap/DataBroker icon, and existing icon fallback paths.
- Added a subdued grayscale version of the same new artwork for the disabled/off state; the legacy logo is no longer used.
- Converted the supplied artwork to a WoW-friendly 512x512 TGA texture while preserving the original square composition.

## v11.0.0-alpha.2 — Single UI

- Removed the legacy AceConfig settings window from the user-facing addon. Decursive now has one configuration interface.
- Added a native v11 renderer for the complete Decursive option model, including General, Micro Unit Frames, Curing, Custom Spells/Mouse Bindings, Affliction Filters, Live List, Messages, Macro, and About.
- Added native priority and skip list management directly inside the v11 window, including add-target, move up/down/top/bottom, remove, and clear actions.
- `/decursive`, `/dcr`, `/zd`, the Decursive options key binding, and Alt+RightClick now all route to the modern v11 UI.
- Removed `/dcrclassic`; AceConfigDialog, AceConfigCmd, AceConfigRegistry, and AceGUI are no longer loaded; v11 uses its own lightweight refresh hook.
- Retained AceDB, AceDBOptions, LibDualSpec, secure MUF behavior, custom spells, list logic, and the WoW 12.1 managed-aura engine as backend functionality.
- Added a native **12.1 Status** page for the existing managed-aura status, dispel resolver refresh, selected-MUF test, and all-MUF test controls.
- Updated the v11 Dashboard and documentation to describe the single-UI architecture.



## v11.0.0-alpha.8 — Global Settings Search

- Added a global **Search settings…** field to the v11 header.
- Search covers page names, native v11 controls, and the mature Decursive option model used by General, MUFs, Curing, filters, Live List, Messages, Macro, 12.1 Status and About.
- Added search aliases for environment modes, cooldown/range controls, secure mouse bindings, custom spells/items, profile management, Priority/Skip lists, diagnostics and DandersFrames integration.
- Search results display the destination page and setting context; clicking a result opens that page immediately.
- Pressing Enter opens the best current match; Escape clears/closes search.
- Search metadata is rebuilt when dynamic options change, without reading protected aura details or altering the WoW 12.1 detection provider.
- No changes to curing, secure MUFs, DandersFrames detection-provider behavior, profiles, or Blizzard-managed aura handling.


## v11.0.0-alpha.9 — Provider-Independent Cooldown Overlay

- Fixed the MUF cooldown overlay not appearing when **DandersFrames dispel detection** was enabled.
- Root cause: DandersFrames `AuraContainer:ApplyTuning()` intentionally defers candidate-filter changes during combat, so it cannot be used as a post-cleanse cooldown visibility gate.
- DandersFrames integration is now even more strictly scoped: it supplies protected **dispel detection only**. It no longer creates or tunes Decursive cooldown-gate carriers.
- The cooldown overlay is now driven entirely by Zhaohu's Decursive using the MUF the player clicked, the successful friendly-dispel spell cast, and that player's spell `DurationObject`.
- The clicked MUF now receives the shaded cooldown state and optional numeric countdown regardless of whether the active detection provider is Native or DandersFrames.
- Native detection retains the optional shared same-priority cooldown gate for other afflicted MUFs. DandersFrames mode does not attempt in-combat `ApplyTuning()` calls.
- No protected aura names, types, durations, stacks, or visibility are read into Lua.


## v11.0.0-alpha.13 — DandersFrames Profile + Cooldown Carrier Fix

- Fixed DandersFrames remaining-target cooldown overlays by creating the three priority-filtered DandersFrames cooldown carriers for every MUF before combat.
- The just-cleansed square still clears immediately; only other still-dispellable squares receive the player dispel cooldown tint/countdown.
- Fixed v11 slider numeric readouts so the number field updates live while dragging the slider.
- When the session uses DandersFrames detection, Decursive now uses one dedicated **DandersFrames** behavior profile everywhere instead of switching between Open World, Dungeon/Follower, Mythic+, Raid and PvP behavior blocks.
- The user's previous native environment-mode preference is preserved and resumes after DandersFrames integration is disabled and the UI is reloaded.
- Added diagnostics for DandersFrames detection-carrier and cooldown-carrier counts.

## v11.0.0-alpha.12 — Slider & Numeric Stepper Controls

- Fixed v11 sliders whose thumb could remain centered/non-responsive because template-less Slider frames did not explicitly set horizontal orientation.
- All standard numeric settings now have synchronized slider + exact-value controls.
- Added minus/plus stepping buttons beside numeric values.
- Added mouse-wheel stepping while hovering either the slider or numeric value field.
- Numeric fields accept direct typed values and clamp/snap to each option's allowed range and step.
- Percentage settings display/edit friendly percentages (for example `60%`) while preserving their internal 0–1 values.
- Updated custom-spell priority and color-alpha sliders to use the same corrected horizontal/stepper behavior.
- Removed reliance on the optional `userInput` flag for custom-spell priority sliders, improving compatibility with Retail slider callbacks.

## v11.0.0-alpha.11 — Remaining-Target Cooldown Model

- Changed post-cleanse MUF behavior: the successfully cleansed square now clears immediately and never receives a cooldown overlay.
- Cooldown tint/countdown is shown only on other MUFs that still match the same cure priority while the player's dispel is unavailable.
- Fixed an intermittent lingering faded-red MUF state by explicitly clearing the clicked square's addon-owned shade/cooldown state.
- DandersFrames mode now supports remaining-target cooldown overlays without `ApplyTuning()` in combat: DandersFrames keeps static candidate filters and its carrier visibility is toggled by Decursive's public spell cooldown state.
- DandersFrames remains the sole aura/dispel source of truth when its integration is enabled; Decursive never reads protected aura details.
- New profiles default shared same-priority cooldown display to enabled in every environment.

## v11.0.0-alpha.10 — MUF Settings Layout Fix

- Fixed the overlapping **Show MUFs** and **Lock position** controls on the Micro Unit Frames page.
- Moved the two Frame Basics toggles to separate full-width rows for reliable layout across UI scales and resolutions.
- Increased the Frame Basics card height and shifted the scrolling settings area down to preserve clean spacing.
- No dispel detection, DandersFrames integration, cooldown, secure-click, or profile behavior changed in this build.


## Zhaohu test build square-sound17-dispeldb-status
- Promoted square-sound16 zoning + native aura-sound behavior as the working baseline.
- Added a dedicated **Dispel Database** status page to the modern UI.
- Added `/zddb` for per-expansion database counts and coverage state.
- Expanded verified Legion coverage from LittleWigs encounter handlers (Court of Stars / Black Rook Hold).
- Expanded Dragonflight metadata and retained verified enemy-purge records separately from friendly alerts.
- Corrected expansion display names in the local DB modules.
- Added cure-type counts and ordered expansion statistics to the DispelDB core.
