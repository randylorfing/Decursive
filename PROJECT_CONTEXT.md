# Decursive project context

> **Status snapshot: 2026-09-01 (America/Chicago).** The released baseline is
> `v12.1.4-alpha.4` at commit `a8677d908f6026c98f2acf482ef64a604795dd27`.
> The working tree now identifies the implemented assignment,
> combat/runtime/UI, packaging, documentation, and regression work as the
> canonical `v12.1.4-alpha.5` source candidate. Alpha4 remains historically
> affected. Alpha5 has explicit publication authorization but is not yet
> committed, tagged, or published in this source snapshot; the existing local
> AddOns deployment predates this identity update.

## Contents

- [Purpose and scope](#purpose-and-scope)
- [State legend](#state-legend)
- [Repository structure](#repository-structure)
- [Released alpha4 provenance](#released-alpha4-provenance)
- [Branches and worktree](#branches-and-worktree)
- [Runtime architecture and lifecycle](#runtime-architecture-and-lifecycle)
- [Profiles and environment resolution](#profiles-and-environment-resolution)
- [Implemented but unreleased alpha5 assignment fix](#implemented-but-unreleased-alpha5-assignment-fix)
- [V13 information architecture](#v13-information-architecture)
- [Detection, MUF presentation, colors, and bindings](#detection-muf-presentation-colors-and-bindings)
- [Combat, secure frames, secret values, and cooldowns](#combat-secure-frames-secret-values-and-cooldowns)
- [SavedVariables and schema 6](#savedvariables-and-schema-6)
- [Packaging, release, and supply-chain boundaries](#packaging-release-and-supply-chain-boundaries)
- [Deployment boundary](#deployment-boundary)
- [Validation](#validation)
- [Open audit findings](#open-audit-findings)
- [Planned alpha5 profile UX](#planned-alpha5-profile-ux)
- [Working preferences and constraints](#working-preferences-and-constraints)
- [Glossary](#glossary)
- [Safe next steps](#safe-next-steps)

## Purpose and scope

Zhaohu's Decursive is an independently maintained GPLv3 fork of Decursive for
World of Warcraft Retail 12.1. It preserves the compact Micro Unit Frame (MUF)
click-to-cure workflow while adding Blizzard-managed protected-aura detection,
native sound registration, secure cure and resurrection actions, cooldown and
range feedback, a modern settings interface, and complete environment-specific
profiles. Start with the user-facing [README](Decursive/README.md), current
[changelog](Decursive/CHANGELOG.md), alpha5 candidate
[release notes](Decursive/RELEASE_NOTES_v12.1.4-alpha.5.md), and immutable
alpha4 [release notes](Decursive/RELEASE_NOTES_v12.1.4-alpha.4.md).

This repository contains two addon folders that must be installed together:

- `Decursive` is the core runtime addon.
- `Decursive_Options` is the load-on-demand settings companion.

The project targets Retail 12.1 safety. It does not attempt to read protected
aura identity, visibility, duration, or other secret data from Lua. Blizzard's
managed aura system remains authoritative for live protected detection.

## State legend

- **RELEASED**: present in the alpha4 tag and official alpha4 ZIP.
- **IMPLEMENTED, UNRELEASED**: present only as current working-tree changes.
- **PLANNED**: approval-ready direction; no implementation exists yet.
- **BLOCKED**: known correctness or release-readiness issue that must be resolved
  and verified before publication.

## Repository structure

### Runtime core

- [Decursive.toc](Decursive/Decursive.toc) and
  [Decursive.xml](Decursive/Decursive.xml): core load order and root XML.
- [DCR_init.lua](Decursive/DCR_init.lua): AceAddon initialization, configuration,
  defaults binding, smart resurrection macro generation, and macro lifecycle.
- [Dcr_Events.lua](Decursive/Dcr_Events.lua): event dispatch, combat transitions,
  roster/world changes, and the legacy delayed-function queue.
- [Dcr_DebuffsFrame.lua](Decursive/Dcr_DebuffsFrame.lua) and
  [Dcr_DebuffsFrame.xml](Decursive/Dcr_DebuffsFrame.xml): secure MUF factory,
  attributes, layout, colors, and display updates.
- [Dcr_12_1.lua](Decursive/Dcr_12_1.lua): Retail 12.1 managed AuraContainer/AuraSlot
  integration, priority presentation, cooldown transactions, range/line-of-sight
  overlays, alerts, and modern secure lifecycle.
- [Dcr_12_1_DebuffIdentity.lua](Decursive/Dcr_12_1_DebuffIdentity.lua),
  [Dcr_12_1_SoulLink.lua](Decursive/Dcr_12_1_SoulLink.lua), and
  [Dcr_12_1_Utils.lua](Decursive/Dcr_12_1_Utils.lua): bounded 12.1 subsystems.
- [Decursive.lua](Decursive/Decursive.lua): main behavior plus the Blizzard-native
  protected-aura sound registry.
- [Dcr_CureBindings.lua](Decursive/Dcr_CureBindings.lua): automatic/manual cure
  action model and carried PvP-bandage resolution.
- [Dcr_Raid.lua](Decursive/Dcr_Raid.lua): roster ordering, priority/group modes,
  and DandersFrames integration.
- [Dcr_LiveList.lua](Decursive/Dcr_LiveList.lua) and
  [Dcr_LiveList.xml](Decursive/Dcr_LiveList.xml): legacy live-list UI.

### Profiles and persistence

- [Dcr_ProfileManager.lua](Decursive/Dcr_ProfileManager.lua): logical profiles,
  five physical environment variants, assignments, activation, copy/reset/CRUD,
  AceDB compatibility, and environment preview.
- [Dcr_ProfileIO.lua](Decursive/Dcr_ProfileIO.lua): bounded complete-profile and
  single-environment serialization, validation, transactions, and rollback.
- [Dcr_opt.lua](Decursive/Dcr_opt.lua): defaults, mature option routing, and many
  profile post-actions.
- [FULL_ENVIRONMENT_PROFILES.md](Decursive/FULL_ENVIRONMENT_PROFILES.md): source
  architecture guide. It is intentionally excluded from packages; the shipped
  README links to its GitHub source location so the packaged guide remains valid.

### V13 UI

- [Decursive_Options.toc](Decursive_Options/Decursive_Options.toc): load-on-demand
  options load order.
- [V13/Shell.lua](Decursive_Options/V13/Shell.lua) and
  [V13/Controls.lua](Decursive_Options/V13/Controls.lua): page shell, navigation,
  search, status, and reusable controls.
- [V13/Pages](Decursive_Options/V13/Pages): task-oriented pages.
- [Modern/ZD_Core.lua](Decursive/Modern/ZD_Core.lua): modern runtime facade used
  by options pages.
- [Modern/ZD_UI.lua](Decursive_Options/Modern/ZD_UI.lua) and
  [Modern/ZD_BlizzardSettings.lua](Decursive_Options/Modern/ZD_BlizzardSettings.lua):
  retained modern/Blizzard settings entry points.

### Data, automation, and documentation

- [Database/DispelDB_Core.lua](Decursive/Database/DispelDB_Core.lua) and
  [Database/Dispels](Decursive/Database/Dispels): local, public spell-ID data.
- [.pkgmeta](.pkgmeta): BigWigs packager layout, ignores, sibling folder moves,
  optional dependencies, and license output.
- [build-package-and-upload.yml](.github/workflows/build-package-and-upload.yml):
  verify-then-publish workflow.
- [validate-v13.sh](.github/scripts/validate-v13.sh),
  [validate-package.sh](.github/scripts/validate-package.sh), and focused tests in
  [.github/scripts](.github/scripts): source and package gates.
- [RELEASE_PROCESS.md](RELEASE_PROCESS.md) and
  [AUDIT_RELEASE_READINESS.md](AUDIT_RELEASE_READINESS.md): release procedure and
  audit checklist.
- [docs](Decursive/docs): source documentation excluded from addon packages.

## Released alpha4 provenance

**RELEASED**

- Branch/commit: `alpha` at
  `a8677d908f6026c98f2acf482ef64a604795dd27` (`Make profile manager test loader portable`).
- Parent: `356475fdccdec965288bde71ee25a87972b2e3b0`.
- Annotated tag: `v12.1.4-alpha.4`.
- Tag object: `3df1a0270e466a5ff476df820dd055d149f3cf05`.
- Tag target: `a8677d908f6026c98f2acf482ef64a604795dd27`.
- Tag message: `v12.1.4-alpha.4: schema-6 environment profiles`.
- Official local ZIP:
  [Decursive-v12.1.4-alpha.4.zip](output/published-alpha4/Decursive-v12.1.4-alpha.4.zip).
- ZIP SHA-256:
  `A406865D1E82FB40DAA575E4110F62DDE9955839C1CB1A292AEB71F22E5ED882`.
- Inventory: 135 files under `Decursive` and 16 under `Decursive_Options`.
- Exact offline package:
  [.release-alpha4-exact](.release-alpha4-exact).
- Official extracted package:
  [output/published-alpha4/expanded](output/published-alpha4/expanded).
- The exact and official extracted manifests were verified equal after normalizing
  only the official ZIP's `LibDataBroker-1.1/README.textile` CRLF line endings to
  LF in memory. No archive was rewritten.
- GitHub release:
  [v12.1.4-alpha.4](https://github.com/randylorfing/Decursive/releases/tag/v12.1.4-alpha.4).
- CurseForge project:
  [Decursive 12.1 Compatibility Patch](https://www.curseforge.com/wow/addons/decursive-12-1-compatibility-patch).
  The exact CurseForge file URL/ID is not retained in current local metadata and
  must be checked remotely before citing it.

The tag and official ZIP are immutable released evidence. Do not rebuild them
in place or silently replace their contents. Corrections belong in a new alpha5
commit/tag/artifact.

## Branches and worktree

### Branch state

- `HEAD`, local `alpha`, and local `origin/alpha` are at `347e7b5`, whose tree is
  byte-identical to alpha4 after a docs-only change and exact revert.
- Local `master` and `origin/master` are at `98bf895`.
- `master` is exactly nine commits behind `alpha`; `alpha` is zero commits behind
  `master`.
- Local `origin/HEAD` points to `origin/master` and local `init.defaultBranch` is
  `master`.
- The server-side GitHub default branch was not queried during the read-only
  audit. Treat “GitHub defaults to master” as unverified until checked remotely.

### Working-tree scope for the alpha5 candidate

**IMPLEMENTED, UNRELEASED tracked changes**

```text
 M .github/scripts/test-live-list-startup-sentinels.lua
 M .github/scripts/test-profile-manager.lua
 M .github/scripts/test-profile-pages.lua
 M .github/scripts/validate-package.sh
 M .github/scripts/validate-v13.sh
 M .pkgmeta
 M Decursive/CHANGELOG.md
 M Decursive/DCR_init.lua
 M Decursive/Decursive.toc
 M Decursive/Dcr_DebuffsFrame.lua
 M Decursive/Dcr_Events.lua
 M Decursive/Dcr_LiveList.xml
 M Decursive/Dcr_ProfileManager.lua
 M Decursive/Dcr_Raid.lua
 M Decursive/Dcr_opt.lua
 M Decursive/Localization/enUS.lua
 M Decursive/README.md
 M Decursive/OldChangeLog.md
 M Decursive/WhatsNew.md
 M Decursive_Options/Modern/ZD_UI.lua
 M Decursive_Options/V13/Pages/MUFs.lua
 M Decursive_Options/V13/Pages/Profiles.lua
 ?? .github/scripts/test-combat-startup-recovery.lua
 ?? .github/scripts/test-muf-context-visibility.lua
 ?? Decursive/RELEASE_NOTES_v12.1.4-alpha.5.md
 ?? PROJECT_CONTEXT.md
```

**Pre-existing untracked artifact/deployment directories**

```text
?? .deployment-backups/
?? .deployment-stage/
?? .packager-alpha3/
?? .release-alpha3-candidate/
?? .release-alpha3-commit/
?? .release-alpha3-finalcandidate/
?? .release-alpha3-finalhead/
?? .release-alpha3-verified2/
?? .release-alpha4-exact/
?? .release-alpha4-stage-a/
?? .release-alpha5-repair/
?? .release-alpha5-repair2/
?? .release-alpha5-repair3/
?? .release-cooldown-state-machine/
?? .release-cure-bindings/
?? .release-env-profile-audit-current/
?? .release-env-profile-audit/
?? .release-full-env2/
?? .release-full-environment/
?? .release-priority-colors-offline/
?? .release-priority-colors/
?? .release-profile-manager/
?? .release-schema6-audit/
?? .release/
?? output/
```

These directories are evidence and working artifacts, not source. Do not delete,
move, package, deploy, or normalize them without explicit approval and exact
target verification.

## Runtime architecture and lifecycle

1. `ADDON_LOADED` drives `D:OnInitialize()` in
   [DCR_init.lua](Decursive/DCR_init.lua). It checks future profile schemas
   before AceDB initialization, initializes schema-6 storage, creates AceDB, and
   binds the profile manager.
2. `PLAYER_LOGIN` enables the addon. `D:OnEnable()` registers runtime events,
   schedules recurring work, and calls `D:SetConfiguration()`.
3. `SetConfiguration()` binds `D.profile` to the current physical AceDB
   environment variant, rebuilds class/runtime status, discovers cure spells,
   computes priorities and secure macro models, configures UI state, and starts
   roster/MUF convergence.
4. [Dcr_Events.lua](Decursive/Dcr_Events.lua) handles world, roster,
   specialization, bag/item, and combat edges. Some mature code still uses the
   unordered legacy delayed-function table; the modern scheduler is in
   [CombatScheduler.lua](Decursive/V13/Core/CombatScheduler.lua).
5. Secure MUFs are created lazily by
   [Dcr_DebuffsFrame.lua](Decursive/Dcr_DebuffsFrame.lua). Blizzard-managed
   detection and addon-owned visual feedback are attached by
   [Dcr_12_1.lua](Decursive/Dcr_12_1.lua).
6. On `PLAYER_REGEN_ENABLED`, profile, binding, layout, native display, sound,
   and cooldown subsystems flush work that was deferred at their respective
   security boundaries.

Alpha4's combat `/reload` lifecycle is affected by historical findings 1, 2, 3,
and 6 below. The current uncommitted tree defers configuration before destructive
state reset, reports initialization only after `Configure()` succeeds, and runs
an ordered recovery transaction directly from `PLAYER_REGEN_ENABLED`. The local
behavior harness proves the coordinator and MUF recovery contract with mocks;
an in-game combat `/reload` remains the final environment-specific verification.

## Profiles and environment resolution

**RELEASED**

Schema 6 distinguishes a logical **Decursive Profile** from its physical AceDB
profiles. Every logical profile owns exactly five complete Environment Profiles:

1. `OPEN_WORLD`
2. `DUNGEON` (Party/Dungeon)
3. `MYTHIC_PLUS`
4. `RAID`
5. `PVP`

Each environment is a complete configuration, not a small override. It includes
MUF layout/visibility, pets, lists, colors, cure order, custom actions, secure
bindings, alerts, cooldowns, performance values, class settings, and other
profile settings.

### Logical profile precedence

The current resolver in [Dcr_ProfileManager.lua](Decursive/Dcr_ProfileManager.lua)
uses this precedence:

1. Current specialization assignment, only when per-specialization profiles are
   enabled and the mapped logical profile still exists.
2. Character assignment.
3. Account default assignment.
4. Protected logical `default` fallback.

Character assignment identity uses the normalized `UnitFullName` realm form.
AceDB `profileKeys` uses its physical character key based on
`UnitName("player") .. " - " .. GetRealmName()`.

### Environment precedence

1. A logical profile's explicit manual environment mode, when set.
2. Automatic detection: PvP/arena, raid, Mythic+, party/dungeon, then open world.
3. `OPEN_WORLD` as the safe fallback.

Options editing can preview a selected environment's physical AceDB profile
outside combat. Leaving editing restores the runtime-resolved environment.
Profile copy/reset/import operations are transactional and should restore the
runtime or preview target appropriate to the current mode.

## Implemented but unreleased alpha5 assignment fix

**IMPLEMENTED, UNRELEASED**

The five tracked modifications listed above correct profile assignment behavior
without changing schema version 6:

- [Dcr_ProfileManager.lua](Decursive/Dcr_ProfileManager.lua) now retains the
  normalized manager identity while computing AceDB's exact display-realm
  `profileKeys` key. It synchronizes only that exact key and an already-present
  known normalized alias; it does not broadly clean unrelated keys.
- `BindDatabase()` reconciles and verifies the physically loaded AceDB profile
  against the logical profile/environment resolver. It applies immediately when
  safe and uses the existing combat-deferred resolution otherwise.
- `ResolveBaseProfileID()` separates ordinary character/account fallback from
  specialization resolution.
- Assignment snapshots expose `storedSpec` for a dormant saved mapping and
  expose active `spec` only while per-specialization mode is enabled.
- `GetDualSpecProfile()` honors the enabled flag and otherwise returns the
  ordinary character/account-resolved physical profile.
- [Profiles.lua](Decursive_Options/V13/Pages/Profiles.lua) displays active,
  saved-but-inactive, or disabled specialization state and never presents a
  dormant mapping as active.
- [enUS.lua](Decursive/Localization/enUS.lua) supplies the new status strings.
- [test-profile-manager.lua](.github/scripts/test-profile-manager.lua) covers a
  spaced display realm, conflicting exact/normalized keys, unrelated-key
  preservation, dormant mapping retention, immediate reconciliation, and
  combat-deferred reconciliation.
- [test-profile-pages.lua](.github/scripts/test-profile-pages.lua) covers the UI
  and manager source invariants.

The focused/full source gates passed when these changes were implemented, but
they are not committed, tagged, or published. A local test deployment was made
before the alpha5 identity and release-document update, so it is no longer an
exact copy of the current source candidate.

### Implemented but unreleased alpha5 focused repair

**IMPLEMENTED, VALIDATED LOCALLY, UNRELEASED**

- Combat-time `SetConfiguration()` exits before replacing `D.Status` or its
  secure macro model and records an explicit pending recovery transaction.
- `Init()` propagates `Configure()` success; `DcrFullyInitialized` is set only
  after secure configuration completes out of combat.
- `PLAYER_REGEN_ENABLED` directly orders profile completion, configuration,
  pending bindings/scale/order, MUF creation, attribute refresh, and layout.
  The unrelated legacy delayed queue remains isolated.
- Delayed `MicroUnitF:Create` retains `self`, while `RecoverAfterCombat()` creates
  missing public-unit MUFs and applies attributes/layout synchronously.
- MUF order changes requested in combat remain pending and unpersisted until the
  out-of-combat layout transaction; V13 exposes the pending state.
- The MUF Size card follows the Environment Profile being edited: Open World
  and PvP show Party and Raid controls, Party/Dungeon and Mythic+ show Party,
  and Raid shows Raid. Context-hidden values remain saved and guarded against
  UI writes; switching the edit/preview context refreshes visibility without a
  schema or migration change.
- LiveList starts hidden and is shown only after the active profile decision.
- Package policy excludes all release-note/changelog variants and root project
  documents, retains the shipped README with an absolute architecture-guide
  link, and uses the ignored source changelog only as upload metadata.
- [test-combat-startup-recovery.lua](.github/scripts/test-combat-startup-recovery.lua)
  executes success and failure recovery paths and asserts ordering plus final
  nonempty secure `type`, `unit`, and `macrotext` model attributes.
- [test-muf-context-visibility.lua](.github/scripts/test-muf-context-visibility.lua)
  covers all five environment mappings, hidden-control write rejection, data
  retention, and edit/preview refresh behavior.

## V13 information architecture

**RELEASED**

The V13 settings shell is task-oriented rather than a second configuration
backend. It reads/writes the same active complete AceDB environment profile
through [ZD_Core.lua](Decursive/Modern/ZD_Core.lua) and mature option handlers.

- **Overview**: current context, important state, and entry actions.
- **MUFs**: visibility, lock/order, size, spacing, appearance, range,
  line-of-sight, cooldown, and test controls.
- **Cure**: automatic/manual cure bindings, cure actions, fixed target/focus
  gestures, PvP bandage status, and cure priority controls.
- **Alerts**: text, sound, feedback, and native protected-aura alert settings.
- **Profiles**: logical profile CRUD, account/character/spec assignments,
  environment selection/preview/copy/reset/import/export.
- **Advanced**: specialist and diagnostic settings.
- **All Settings** pages generated by
  [Settings.lua](Decursive_Options/V13/Pages/Settings.lua): complete mature option
  coverage when a task page does not expose a niche setting.

[Shell.lua](Decursive_Options/V13/Shell.lua) owns navigation, search, context,
and status. Pages should not invent parallel persistence. Directly relevant
backend methods belong in core; V13 pages should remain thin UI adapters.

## Detection, MUF presentation, colors, and bindings

### Detection contract

- Blizzard `AuraContainer`/`AuraSlot` filters decide whether a protected,
  dispellable harmful aura is present.
- Decursive assigns fixed public unit tokens to MUFs and never reads managed
  AuraSlot visibility or secret aura identity back into Lua.
- The local [DispelDB](Decursive/Database/README.md) supplies public spell IDs
  primarily for Blizzard-native `AddAuraSound` registration. It is not a license
  to inspect protected live aura data.
- Managed detection, public spell cooldown state, and addon-owned presentation
  are deliberately separate.

### Paint, not icons

The live MUF is a paint/status surface, not an aura-icon grid:

- The inner square is filled with the configured cure-priority color.
- A single managed border can represent a second simultaneous dispellable
  affliction when enabled.
- Default priority colors are red for priority 1, blue for priority 2, and
  orange for priority 3. Additional slots default to white.
- Range, line-of-sight, dead state, cure result, and cooldown layers modify or
  overlay the square according to their documented precedence.
- Cooldown shading/countdown applies to other MUFs that still need the same cure
  priority; the successfully cleansed MUF clears immediately.
- Do not replace this model with addon-read aura names/icons in 12.1.

### Secure binding defaults

- Default mode is **Simple Two-Button** (`AUTO`). Distinct targeted friendly
  cures receive Left, Right, then Ctrl+Left.
- Middle click targets and Ctrl+Middle focuses.
- Manual mode stores mappings by stable spell/item action identity and rejects
  duplicate or reserved gestures.
- Button5 is reserved only when a verified PvP bandage action is available.
  Carried-bag resolution uses public, usable on-use-item data; it excludes bank,
  reagent-bank, and account-bank storage and does not guess an item ID.
- Smart resurrection builds secure dead/nodead and combat/nocombat macro clauses
  outside combat. Lua does not inspect a live unit's death state to select the
  click action.
- Secure attribute or binding changes retain the last valid layout during combat
  and apply only at an allowed boundary.

## Combat, secure frames, secret values, and cooldowns

- Treat `InCombatLockdown()` as the authoritative boundary for creating,
  retargeting, moving, scaling, showing/hiding, mouse-enabling, or changing
  attributes on the secure MUF tree.
- A `pcall` catches an error but does not make a protected mutation safe.
- Never set secure `type`, `unit`, or `macrotext` attributes in combat.
- Secret values can occur outside ordinary combat in tainted/restricted
  contexts. Guard accessible/public data before Lua string, table-key, numeric,
  or comparison operations.
- Blizzard-managed aura membership is not queried from Lua. Do not use
  `IsShown()` on protected AuraSlots as a detection signal.
- Native display-object mutation uses both combat and addon-restriction/access
  boundaries. Native aura-sound registration deliberately uses
  `C_ChatInfo.InChatMessagingLockdown()` because treating every unrelated addon
  restriction as a sound blocker previously left registrations deferred.
- Cooldown logic uses public spell cooldown/charge state plus Duration objects.
  Global-cooldown-only states are rejected, final-charge consumption is handled,
  and retries are bounded/generation-guarded. Avoid Lua arithmetic on secret
  cooldown values and do not restore removed secure delegates.
- Debug information belongs in the addon's existing copyable diagnostic windows,
  not new chat-frame debug output.

## SavedVariables and schema 6

`DecursiveDB` is initialized through AceDB only after the profile manager checks
the stored schema. Schema behavior is intentionally strict:

- Any schema older than 6 triggers a one-time destructive reset of older
  Decursive settings and creates a fresh protected logical Default profile with
  five complete environment variants.
- Valid schema-6 data is normalized/repaired only where required; divergent
  environment data is preserved.
- A schema newer than 6 is fail-closed: Decursive disables itself and leaves the
  newer data unchanged byte-for-byte.
- Import validation is bounded before and after deserialization. Malformed,
  oversized, excessively deep, cyclic/shared, multi-root, truncated, or
  unsupported payloads must fail without partial mutation.
- Complete logical-profile import covers all five environments. Single
  environment import is transactional and rolls back on apply failure.

Never hand-edit, deploy, delete, or migrate the user's SavedVariables/WTF data as
part of repository work unless the user explicitly authorizes that exact action
and a backup/recovery plan exists.

## Packaging, release, and supply-chain boundaries

### Packager

- The project uses BigWigsMods Packager pinned to reviewed commit
  `36b4c3b7b7bd17c835ad8c83fed4976c067edfbe` in
  [build-package-and-upload.yml](.github/workflows/build-package-and-upload.yml).
- `.pkgmeta` packages the two sibling addon folders and moves them to top-level
  `Decursive` and `Decursive_Options` directories.
- Libraries are committed locally. Do not re-enable externals merely to create a
  nolib archive; that reintroduces the documented directory collision.
- The verify job has read-only contents permission and no publishing secrets.
  Only the tag-gated release job receives publishing credentials.
- External GitHub Actions are pinned to full commit SHAs.
- Dry-run packaging and `validate-package.sh` must pass before any upload.
- The alpha5 source identity is `v12.1.4-alpha.5`; the package validator requires
  the tag-substituted version in both TOCs to match the literal alpha5 build
  marker, preventing a ZIP filename from masking a build made from the wrong tag.
- Do not use or introduce `dyne`, LuaBinaries, unreviewed packager binaries, or
  floating action tags.

### Package hygiene caveats

- Alpha4's official ZIP historically contains `CHANGELOG.md` and its alpha4
  release-note file, and its README link targets an excluded relative document.
- The current uncommitted policy fixes all three issues. The pinned packager uses
  the ignored source `Decursive/CHANGELOG.md` as upload metadata, so it does not
  generate a player-folder changelog. `RELEASE_NOTES_*.md`, legacy changelogs,
  release summaries, and every explicit root Markdown document are excluded.
- Repository validation requires every root Markdown document to have an exact
  `.pkgmeta` ignore. Package validation uses a closed Markdown allowlist.
- The successful offline stage [.release-alpha5-repair3](.release-alpha5-repair3)
  contains 131 core and 16 options files, parses 85 packaged Lua files, and has
  no changelog, release-note, or internal-root-document leak. Its ZIP SHA-256 is
  `1FBAA3DF0D6AB049AED7C6BABEE97AE5DC222CE5B3FBF43821C42BA5687C9F9B`.
  It is a local uncommitted validation artifact retaining the alpha4 version
  token, not an alpha5 release candidate.
- Because BigWigs Packager derives `@project-version@` exclusively from Git, an
  exact alpha5 expanded package and ZIP require the alpha5 commit/tag stage. The
  current no-Git-mutation preparation pass must reject an alpha4-token build
  even when its filename is manually labeled alpha5.

### Release rule

Alpha4 is already published. Any source correction requires a new alpha5 commit,
annotated tag, exact package, official upload, and independent artifact
validation. Never amend/repoint alpha4 or overwrite its ZIP.

## Deployment boundary

Repository edits, package creation, release publication, and installation are
separate actions. None implies the next:

- Do not copy into the live `Interface/AddOns` folders unless the user explicitly
  requests deployment after tests pass.
- Do not touch `WTF`, SavedVariables, or live character/account data.
- Do not use untracked `.deployment-*` directories as authorization to deploy.
- A package that passes local validation is still not authorization to tag,
  upload, publish, or install.
- If deployment is authorized, replace both addon folders as a pair rather than
  merging files over an older installation, and report exactly what changed.

## Validation

Use existing local runtimes and dependencies. Do not install or download tools
without approval.

### Source and behavior gates

The 2026-09-01 alpha5 identity pass completed the repository validator; all 16
maintained positive harnesses and four intentional-failure harnesses passed on
both Lua 5.4.6 and 5.1.5. Both native parsers and the existing local Fengari
parser accepted all 101 maintained addon/test Lua files. The exact maintained
code luacheck warning policy passed across its 48-file scope.

```bash
bash .github/scripts/validate-v13.sh
node .github/scripts/parse-lua-tree.js
```

When native Lua is available, run every maintained harness listed by
`validate-v13.sh`. Otherwise use the repository Fengari runner with its existing
local dependencies, for example:

```bash
node .github/scripts/run-fengari.js .github/scripts/test-smart-rez.lua
node .github/scripts/run-fengari.js .github/scripts/test-profile-manager.lua
node .github/scripts/run-fengari.js .github/scripts/test-profile-io.lua
node .github/scripts/run-fengari.js .github/scripts/test-cure-bindings.lua
```

The maintained suite currently includes smart resurrection, Soul Link visuals,
native MUF ownership/detection/state safety, cooldown transactions, live-list
startup sentinels, combat-startup recovery, environment-aware MUF visibility,
local-budget checks, schema/profile manager, adversarial ProfileIO, profile
pages, full environment variants, and cure bindings.

### Diff and style gates

```bash
git diff --check
git status --short
git diff -- '*.lua' | rg '^\+[^+]'
```

Review added Lua lines manually or with a focused pattern to ensure no semicolons
were introduced. Do not treat existing upstream semicolons as authorization to
add new ones.

### Package gate

After an approved dry-run package is assembled into a fresh directory:

```bash
bash .github/scripts/validate-package.sh .release
```

Validate TOC references, substituted tokens, Lua parsing, licenses, filename
collisions, source-only leaks, inventories, release notes, and hashes before any
tag/upload step.

### Known validation gaps

- The new harness executes the real recovery coordinator and MUF recovery method
  with mocked WoW objects. It proves ordering and final attribute values, but a
  local harness cannot reproduce Blizzard's live secure-frame engine or taint.
- `validate-v13.sh` runs every maintained harness when native Lua exists. If it
  does not, it reports that CI supplies Lua; the repository Fengari runner still
  requires an already-present local Fengari module.
- No automated test can perform an actual in-game combat `/reload`; complete one
  before release and inspect the addon's copyable diagnostics if it fails.

## Open audit findings

These findings describe alpha4 history and the current uncommitted disposition.
“Implemented” does not mean released or verified inside the WoW client.

1. **Alpha4 release blocker; implemented/unreleased:** configuration now defers
   before `D.Status`/`prio_macro` reset and the executed harness proves recovery.
2. **Alpha4 release blocker; implemented/unreleased:** `Init()` propagates
   `Configure()` failure and initialization becomes true only on success.
3. **Alpha4 H2; implemented/unreleased:** configuration/MUF recovery no longer
   depends on unordered 0.3-second queue execution; regen calls it directly.
4. **Not independently defective:** an empty in-combat SmartRez result is not
   cached; the first out-of-combat call recomputes it. Add transition coverage.
5. **Alpha4 H2 latent; implemented/unreleased:** delayed `Create` now queues
   `self.Create, self, Unit, ID` and marks synchronous recovery pending.
6. **Alpha4 release blocker; implemented/unreleased:** configuration and `Init`
   stop at the combat boundary before protected visibility/mouse mutations.
7. **Alpha4 H3; implemented/unreleased:** package metadata and the validator now
   generically exclude release notes/changelogs and explicitly guard root docs.
8. **Alpha4 H3; implemented/unreleased:** the shipped README now uses an absolute
   source link while the full-environment guide remains source-only.
9. **Partial, H2 governance:** local metadata points default/origin HEAD to master,
   which is six commits behind alpha. The remote default branch needs an approved
   remote check.
10. **Not confirmed:** AddAuraSound's chat-messaging-lockdown boundary is
    deliberate and distinct from AuraSlot addon-restriction guards. Clarify
    comments; do not restore the superseded broad sound guard without new proof.
11. **Alpha4 H3; implemented/unreleased:** LiveList starts hidden and has no
    unconditional pre-decision `Show()` call.
12. **Alpha4 H3; implemented/unreleased:** MUF-order value and layout are both
    deferred; V13 labels the pending request until combat ends.
13. **Alpha4 H2; implemented with residual in-game risk:** the executed native
    Lua 5.1/5.4 harness proves final modeled `type`, `unit`, and nonempty
    `macrotext`; only live Blizzard secure-frame/taint behavior remains unmocked.

### Repair order

Items 1-6 and 8 from the original repair order are implemented and locally
validated in the current tree. Remaining release work is:

1. Perform an in-game combat `/reload` → `PLAYER_REGEN_ENABLED` check with at
   least one dispellable unit and verify clicks/macros, creation, and layout.
2. Review the combined assignment/runtime/package diff and decide commit shape.
3. Resolve master/alpha governance after an approved remote default-branch check.
4. Run a fresh exact alpha5 package/release chain only with separate approval.

## Planned alpha5 profile UX

### Reset one Environment Profile

**PLANNED**

The manager already exposes `ResetEnvironment(profileID, environment)`. Alpha5
should make a visible **Reset this Environment Profile to Defaults** action
inside the canonical Environment Profile workspace.

Required behavior:

- Reset exactly the selected logical profile's selected environment, never all
  five and never another logical profile.
- Show a confirmation naming both the logical Decursive Profile and Environment
  Profile.
- Reject or atomically defer the reset during combat; do not save new data while
  leaving the active secure runtime on the old data without a clear pending
  state.
- Preserve other environments and profile assignments.
- If the reset target is the active runtime environment, reapply it safely. If it
  is only the editing preview, remain in that preview. Otherwise do not switch
  the active physical AceDB profile.
- Keep one canonical button; do not duplicate reset actions across legacy and
  V13 surfaces without a shared backend and identical confirmation semantics.
- Add focused manager, UI, combat, active/editing restoration, and no-collateral-
  mutation tests.

### Single Profile Mode

**PLANNED; not implemented and not a sixth physical environment.**

Recommended architecture is per logical Decursive Profile:

- Add mode metadata to the logical profile record, such as an enabled boolean
  and a designated source from the existing five environment keys.
- Present the designated source as **Shared configuration** in the UI. It remains
  one real existing Environment Profile rather than a sixth `GLOBAL` variant.
- While enabled, runtime resolution and editing route every activity to that
  designated physical environment variant.
- Preserve all other environment variants untouched and dormant. Turning the
  mode off restores normal automatic/manual environment routing and the user's
  previous data.
- The designated source cannot be deleted independently because environments
  are structural members of the logical profile. Resetting while in single mode
  resets only the designated shared source after confirmation.
- Copying a logical profile copies the mode metadata and all five variants.
  Deleting a logical profile removes its metadata through normal CRUD cleanup.
- Complete-profile import/export carries validated mode metadata. Older schema-6
  exports omit it and default to mode off. Single-environment import changes the
  selected physical variant only; it must not silently toggle the mode.
- Repair invalid/missing source keys to a documented existing environment, most
  conservatively `OPEN_WORLD`, without discarding dormant data.
- Resolver, preview, combat deferral, `D.classprofile`, secure bindings,
  AuraSlot/filter colors, cooldown settings, CRUD, copy/reset, and IO tests must
  all prove that the same shared physical profile is authoritative while the
  mode is on and that mode-off restoration is lossless.

This is additive schema-6 behavior if the metadata defaults safely and old
records remain valid. A schema bump should occur only if backward-safe
normalization cannot be guaranteed.

## Working preferences and constraints

- Do not use Canvas for this project's audits or handoff documentation.
- Ask for explicit approval before mutations that are not already scoped by the
  user's current request.
- Ask before downloads, installs, vendor/dependency changes, remote mutations,
  deployment, AddOns changes, or SavedVariables changes.
- Do not download or inspect a separate `DecursiveNext` project unless the user
  explicitly requests and authorizes it.
- Test and report local changes before committing, pushing, tagging, publishing,
  or updating repository/release state.
- Never commit, push, tag, publish, deploy, or alter workflows merely because a
  source edit or audit was requested.
- Preserve unrelated working-tree changes and untracked evidence directories.
- Use `apply_patch` for source/document edits and no semicolons in new Lua.
- Debug output must use the addon's existing scrollable/copyable diagnostic
  systems, never new `print()` chat-frame debugging.
- Cite exact local evidence and distinguish inference from proven behavior.

## Glossary

- **AceDB physical profile**: one concrete table selected by AceDB, normally one
  environment variant of a logical profile.
- **Decursive Profile / logical profile**: named container that owns assignments,
  metadata, and five Environment Profiles.
- **Environment Profile**: complete settings variant for Open World, Dungeon,
  Mythic+, Raid, or PvP.
- **MUF**: Micro Unit Frame, the secure clickable square representing a fixed
  public unit token.
- **AuraContainer/AuraSlot**: Blizzard-managed protected-aura display/detection
  objects. Their live membership is not read by addon Lua.
- **Priority paint**: MUF fill/border color derived from cure-action priority,
  not an aura icon or Lua-read dispel-type identity.
- **Preview environment**: explicit settings-edit physical profile temporarily
  selected outside combat; leaving editing restores runtime resolution.
- **Dormant specialization mapping**: saved spec assignment retained while
  per-specialization mode is disabled; it is not active.
- **Native aura sound registry**: public unit/spell registrations passed to
  Blizzard `C_UnitAuras.AddAuraSound` so Blizzard detects and plays protected
  alerts.
- **Release blocker**: issue that must be corrected and behaviorally verified
  before the next artifact is published.

## Safe next steps

1. Preserve the assignment fix, focused repair, identity, release-note, and
   validation files together until reviewed.
2. Perform the in-game combat `/reload` verification described above.
3. Inspect the complete diff and decide whether runtime/package policy should be
   separate commits; do not publish either partially.
4. Implement the one-environment reset UX and its tests as a separate reviewable
   change.
5. Implement Single Profile Mode only after its source-environment terminology,
   metadata, import/export contract, and mode-off retention behavior are approved.
6. Verify the remote default branch with approval and decide whether alpha should
   merge into master before the alpha5 release chain.
7. Only after in-game verification and all blocker gates are green should a
   separately authorized alpha5 commit/tag/package/publish/deploy workflow begin.
