# Zhaohu's Decursive — Project Audit

**Audience:** chief of staff standing up a software-factory bot team for
[randylorfing/Decursive](https://github.com/randylorfing/Decursive).
**Not a feature request.** Do not treat this as a license to refactor.

| | |
|---|---|
| Audited commit | `98bf895` — *Harden v13 runtime, packaging, and smart MUF resurrection* |
| Branch audited | `master` (same commit as tag `v12.1.4-alpha.1`) |
| Date | 2026-09-01 |
| Official upstream | [2072/Decursive](https://github.com/2072/Decursive) (John Wellesz) |
| This fork | Randy Lorfing / CurseForge project **1659159** |
| Why the fork exists | Midnight / 12.1 **secret values** and **taint** broke cleansing. The 12.1 path never reads aura names, types, durations, or stacks; Blizzard-managed AuraContainers own detection; secure MUF clicks use pre-installed macrotext. |
| Method | Read source, headers, TOC load order, CI, `.pkgmeta`; ran `validate-v13.sh`, `validate-package.sh` against a packager dry-run `.release/`; ran Lua harnesses; `luac5.4 -p` on all 83 packaged Lua files; compared tags/releases via `gh`. **No in-game client.** |

Where this document and the tree disagree later, **the tree wins**. Re-verify
line numbers before editing.

---

## 0. What a specialist needs in the first five minutes

1. **`master` is not the newest work.** HEAD is `v12.1.4-alpha.1`. Six commits
   and four published pre-releases (`alpha.2`–`alpha.4`) live only on
   `origin/alpha`. A bot that starts from `master` will miss the profile-manager
   rewrite and will fight that branch.
2. **Latest *stable* ship is `v12.1.3`.** HEAD is already a GitHub pre-release
   as `v12.1.4-alpha.1`. It is buildable. It is **not** a clean stable cut:
   TOC still says `X-Zhaohu-12.1-Patch: v12.1.3-package-hygiene`, and the zip
   still carries ~236 KB of markdown that validators call “clean.”
3. **Combat clicks work on already-installed secure macros.** Almost every
   *configuration* mutation is deferred until `PLAYER_REGEN_ENABLED`. `/reload`
   or first configure **in combat** can leave MUF macrotext empty until regen.
4. **Four published tags shipped broken zips** (`v11.0.46`, `v12.0.4`,
   `v12.0.5`, `v12.1.2`). The two-job verify-then-release pipeline exists
   because of those. A green CI check is still not proof — download the zip.
5. **Do not “fix” the three environment-default tables** unless that is the
   assigned job. `RELEASE_PROCESS.md` §2 marks it known and deferred.

---

## 1. Findings ranked by severity

Severity here is **operational risk to users or to the next release**, not
code-style.

### HIGH

**H1 — `master` and `origin/alpha` have already diverged**

| | |
|---|---|
| Evidence | `git log origin/master..origin/alpha` is six commits, +9210/−1430 across 66 files. Tags `v12.1.4-alpha.2`–`.4` are GitHub pre-releases. `v12.1.4-alpha.4` is **not** an ancestor of `master`. |
| Why it matters | Factory bots on `master` will not see `Dcr_ProfileManager.lua`, `Dcr_CureBindings.lua`, or the alpha workflow that already verifies `alpha` pushes. Merging later will be a conflict-heavy 12.1 runtime merge. |
| Owner | Release governor + maintainer. Decide: merge alpha → master, or freeze master and treat alpha as the integration line. |

**H2 — `/reload` or first configure while in combat can leave MUF clicks dead until regen**

| | |
|---|---|
| Evidence | `DCR_init.lua:1931–1936` (`ReConfigure` defers), `:2015–2020` (`Configure` defers), `:1531` (`SetConfiguration` clears `prio_macro = {}`). `Dcr_DebuffsFrame.lua:1544–1556` (`UpdateAttributes` returns false in combat). Secure frames come back from reload with **no** writable `SetAttribute` until `PLAYER_REGEN_ENABLED`. |
| Why it matters | The product promise is “click the square to cleanse.” That promise is only true if macrotext was installed **out of combat**. A mid-fight reload is a real Midnight play pattern. |
| Not a silent taint bug | Attribute routing does **not** read `UnitIsDeadOrGhost` (`Dcr_DebuffsFrame.lua:1597–1631`; harness asserts this). The gap is empty/stale secure state, not a secret-value branch. |
| Owner | 12.1 runtime engineer. In-game repro: `/reload` inside a pull with grouped MUFs; click a lit square. |

**H3 — `GetSmartRezActions()` returns empty if combat starts before any OOC build**

| | |
|---|---|
| Evidence | `DCR_init.lua:2573–2579` — in combat, missing cache returns `nil, nil, false, false`. Soul Link visuals read `D.Status.SmartRezActions` (`Dcr_12_1_SoulLink.lua:84–91`) and will stay black. |
| Why it matters | Same class as H2: first combat after a combat-time init. Installed macrotext from a *previous* session is gone after reload. |
| Owner | Same as H2. |

**H4 — Package validators pass while ~221 KB of historical markdown still ships**

| | |
|---|---|
| Evidence | Dry-run zip `Decursive-v12.1.4-alpha.1.zip` (963,939 bytes) contains `CHANGELOG.md` (115,425), `OldChangeLog.md` (78,888), `WhatsNew.md` (15,456), `RELEASE_NOTES_v12.1.3.md` (4,915). `validate-package.sh` printed `no source-only files leaked` and exited 0. |
| Why it matters | v12.1.2’s Windows collision was two `.md` files the Lua parser cannot see. The current leak list still does not mention these four. CI will stay green while the zip stays fat and a future `README.md`/`Readme.md` pair can recur if someone restores the old name. |
| Owner | Packaging engineer. Decide which markdown is *user* docs (`Decursive/README.md` is the intended in-addon guide) vs *repo history*. |

### MEDIUM

**M1 — Three (really four) copies of environment defaults still disagree**

Confirmed on HEAD, matching `RELEASE_PROCESS.md:79–85`.

| Source | Role | Gap vs canonical |
|---|---|---|
| `Dcr_12_1.lua:133–229` | Canonical `ENVIRONMENT_DEFAULTS`; exported `D.Environment121Defaults` (`:233`) | Full keys including LoS + `Detection121Mode` |
| `Dcr_opt.lua:275–282` | AceDB `defaults.profile.Environment121Profiles` | **No** `LineOfSight121*` keys |
| `Modern/ZD_Core.lua:52–143` | Fallback if canonical missing | **No** `Detection121Mode` |
| `Dcr_ProfileIO.lua:565–566` | Import merge uses canonical | Fourth path; correct *if* `D.Environment121Defaults` is loaded |

PvP text-alert defaults (`TextAlerts121Enabled = false`) match across copies.
A fresh AceDB profile and a “reset environment” click can still produce
different stored tables. **Do not fold a fix into an unrelated PR.**

**M2 — TOC / docs claim a patch that HEAD has already outgrown**

`Decursive/Decursive.toc:25` still reads
`## X-Zhaohu-12.1-Patch: v12.1.3-package-hygiene` on a commit tagged
`v12.1.4-alpha.1` that added smart MUF resurrection, Soul Link harnesses, and
v13 runtime hardening.

**M3 — Sound-registration docs overstate the gate**

`Decursive/docs/v13/FEATURE_CONTRACT.md:92–95` says registration is blocked by
“combat lockdown nor an addon restriction.” Live code uses
`C_ChatInfo.InChatMessagingLockdown()` only
(`Decursive.lua:436–447`), with `InCombatLockdown` as a fallback. That
mismatch is how v12.1.2 *fixed* dungeon-long silent queues. A bot that
“restores” `HasActiveAddonRestriction()` here will re-break sounds.

**M4 — `.docmeta` points at files that no longer exist**

`.docmeta` lists `docs/Description.md`, `docs/faq.md`, … — those paths were
moved to `Decursive/docs/` after v12.1.3. CurseForge page generation from
`.docmeta` will fail or stay stale.

**M5 — `master` workflow does not verify `alpha` pushes**

`.github/workflows/build-package-and-upload.yml` on **HEAD** triggers
`master` + `v*` tags + PRs to `master` only. The **alpha** copy of the same
file already adds `alpha` to `push` and `pull_request`. Until that change
lands on master, a bot working only from master will not see alpha CI, and a
revert of the alpha workflow would silently drop alpha verification.

**M6 — `Dcr_opt_tree.lua` claims “solely written by Randy” but is extracted Wellesz code**

File header (`Decursive_Options/Dcr_opt_tree.lua:4–6`) is Form B.
`git log --follow` traces the file to the original Decursive 2.0 Ace option
tree (`05ba5ad`). Created as a sibling in `978a030` (v11.0.44) by splitting
`Dcr_opt.lua`. GPL wants Form A (Wellesz + Lorfing), not Form B. Not a
missing-notice defect — a **wrong-form** defect.

### LOW

**L1 — Localization: `itIT` is an empty stub (0/355).** Other locales 83–100%.
Validator treats incompleteness as informational. AceLocale falls back to
enUS. Fine until an Italian user files a bug.

**L2 — `validate-localizations.sh` is mode `644`, not `755`.** CI invokes it
via `bash`, so this is harmless. `.gitattributes` already pins `*.sh` to LF.

**L3 — `.release/` is not gitignored.** Only `*.zip` is. A local packager
dry-run leaves an unpacked `Decursive/` + `Decursive_Options/` tree that
`git add -A` can sweep. This audit’s checkout had a 3.9 MB unpacked `.release/`
from a dry run.

**L4 — `FEATURE_CONTRACT.md` mentions `V13/Platform/ProtectedAuras.lua`.**
That file does not exist. `validate-v13.sh:285–292` still allows that path as
the only legal home for protected aura APIs — a gate for a module that was
never landed.

**L5 — Historical `Co-Authored-By: Claude` trailer** on `978a030`.
`RELEASE_PROCESS.md:39` forbids it going forward. Do not rewrite that commit.

**L6 — No critical secret-value / secure-click correctness bug found on HEAD.**
The 12.1 path is fail-closed on aura reads. Do not “simplify” the helpers.

---

## 2. Architecture — original Decursive vs Zhaohu

One repo, two addon folders, one zip. Same layout DeadlyBossMods uses.

```
Decursive/                 Always-loaded combat core. Folder name is load-bearing
                           (SavedVariables path `DecursiveDB`).
Decursive_Options/         LoadOnDemand settings. RequiredDeps: Decursive.
                           No SavedVariables of its own.
.pkgmeta                   Packaging contract. Repo ROOT. Do not “tidy.”
.github/                   Verify/release workflow + validators + Lua harnesses.
RELEASE_PROCESS.md         Maintainer/agent handoff. Complements this audit.
```

### 2.1 Load order (bugs have come from ignoring this)

From `Decursive/Decursive.toc`:

| Lines | File | Origin | Job |
|---|---|---|---|
| 52 | `Dcr_preload.lua` | Wellesz, forked | Identity, `_LoadedFiles` |
| 54 | `embeds.xml` | Wellesz | Vendored Ace/Lib* — **no AceGUI/AceConfig** (intentional) |
| 56–57 | `Dcr_DIAG.lua/.xml` | Wellesz | Fatal UI, `DC.TWELVEONE = tocversion >= 120100` (`Dcr_DIAG.lua:717`) |
| 59 | `Localization/load.xml` | Wellesz | AceLocale |
| 61–64 | `DCR_init.lua`, `Dcr_LDB.lua`, `Dcr_utils.lua`, `Dcr_ProfileIO.lua` | Wellesz + fork | Addon object, LDB, secret-safe `UnitName`, profile I/O |
| 67–70 | `Dcr_opt.lua`, `Dcr_Events.lua`, `Dcr_Raid.lua` | Wellesz + fork | Defaults/handlers, events, raid roster |
| 72–84 | `Database/**` | **Fork-new** | Public spell-ID sound DB (Midnight + backfill) |
| 86–87 | `Decursive.lua/.xml` | Wellesz + fork | Cure engine, **native aura-sound registry** |
| 89–90 | `Dcr_lists.lua/.xml` | Wellesz | Priority/skip lists |
| 92–93 | `Dcr_DebuffsFrame.lua/.xml` | Wellesz + fork | **Secure MUFs** — click attributes |
| 94–97 | `Dcr_12_1*.lua` | **Fork-new** | Managed AuraContainers, overlays, Soul Link, identity tooltip |
| 99–100 | `Dcr_LiveList.lua/.xml` | Wellesz | **Disabled on 12.1** (`if DC.TWELVEONE then return false`) |
| 105–106 | `Modern/ZD_*.lua` | **Fork-new** | Compat services + LoD options bootstrap |
| 109–115 | `V13/Core/*`, `V13/Presentation/*` | **Fork-new** | Settings schema, combat scheduler, theme, notifications |

`Decursive_Options` loads only when `/dcr` (or the Blizzard AddOns page) runs
`ZD:EnsureOptionsLoaded()` (`Modern/ZD_LoadOptions.lua:99–111`). First load in
combat is **blocked**.

A file may only call what an earlier TOC entry defined.
`Dcr_DebuffsFrame.lua` loads **before** `Dcr_12_1.lua`. Calling
`D:Is121MUFStatusLightEnabled()` from the MUF file at login was a real bug.

### 2.2 What is original vs Zhaohu-specific

**Keep Wellesz-lineage (Form A headers).** Combat click path, MUF XML,
cure-order engine, AceDB profile object, lists, Live List (dormant on 12.1),
LDB, diagnostics. Edit these only with a 12.1 secret/taint reason.

**Zhaohu-only (Form B / Randy copyright).**

| Area | Files | Notes |
|---|---|---|
| 12.1 runtime | `Dcr_12_1.lua` (4,755 lines — largest file), `_Utils`, `_SoulLink`, `_DebuffIdentity` | Entire file is a no-op unless `DC.TWELVEONE` |
| Modern compat | `Modern/ZD_Core.lua`, `ZD_LoadOptions.lua` | Bridges v13 UI ↔ AceDB |
| Options UI | `Decursive_Options/Modern/ZD_UI.lua` (3,780 lines), `ZD_BlizzardSettings.lua`, `TestMode/` | Mature menu still exists; v13 is primary |
| v13 | 7 files under `Decursive/V13/`, 9 under `Decursive_Options/V13/` (validator expects **16**) | Command-center shell; `UI:InstallAsPrimary()` at `Shell.lua:395,430` |
| DispelDB | `Database/DispelDB_Core.lua` + 11 expansion files | Sound IDs only on 12.1; not a second aura scanner |
| Profile I/O | `Dcr_ProfileIO.lua` | Fork-new helpers |
| CI / packaging | `.github/**`, `.pkgmeta`, root `LICENSE`, `RELEASE_PROCESS.md` | Not shipped (except when ignore rules fail) |

**Dual UI, one primary.** `ZD_UI.lua` still builds the complete option model.
`V13/Shell.lua` replaces the user-facing window after load. A bot that “deletes
the old UI” will drop settings that the v13 pages have not re-hosted.

**Version announcement** uses AceComm prefix `ZhaohuDcrVersion` (16 chars —
AceComm max). Upstream `DecursiveVersion` is forbidden in live code
(`validate-v13.sh:122–128`). Do not “restore compatibility” with upstream’s
channel; this fork would handshake with official Decursive and lie about
versions.

### 2.3 Do-not-blindly-edit list

Give every factory agent this list.

| Path | Why |
|---|---|
| `.pkgmeta` | Every line is load-bearing. Self-referencing `move-folders`, no `externals`, no `manual-changelog`, ignore paths from **repo root**. |
| `Decursive/embeds.xml` | Re-adding AceGUI/AceConfig or `@debug@` markers re-breaks packaging or load. |
| `Decursive/Libs/LibQTip-1.0/LibQTip-1.0.lua` | Packager `--@end-debug@` → `]==]]==]` shipped three times. Markers must stay absent. |
| `Decursive/Decursive.lua` sound block | `InChatMessagingLockdown` is the DBM-matched gate. Not `HasActiveAddonRestriction`. |
| `Dcr_DebuffsFrame.lua` `UpdateAttributes` | Secure attributes. No Lua death reads. Combat must defer. |
| `DCR_init.lua` `BuildSmartRezMacroText` | 255-byte macro budget; conditionals own death/combat. |
| Wellesz copyright years | Never strip; never roll back to `2006-2025`. |
| Environment default tables | Three copies. Known deferred. |
| `package-as` / folder name `Decursive` | SavedVariables and CurseForge identity. |

---

## 3. Runtime / game — Midnight, combat, claims vs code

`DC.TWELVEONE` is `tocversion >= 120100` (`Dcr_DIAG.lua:717`). On that flag
the addon is a **managed-aura, secure-macro** program. Off that flag (Classic
etc.) the legacy UnitAura / Live List path still exists in the same files.

### 3.1 Secret values — fail-closed

Policy (not just a helper):

```48:54:Decursive/Dcr_12_1_Utils.lua
local function IsProtectedContext()
    -- On Retail 12.1, Lua aura detail access can become secret in several
    -- contexts beyond a simple raid/arena combat check. Decursive does not
    -- need direct aura-data reads on 12.1, so treat the entire 12.1 runtime as
    -- managed-only for aura inspection purposes.
    return DC.TWELVEONE == true
end
```

| API / path | What HEAD does |
|---|---|
| Aura names / types / stacks / duration | **Never read** on 12.1. `UnitCurableDebuffs` returns `DC.EMPTY_TABLE` (`Decursive.lua:2061–2072`). |
| `UNIT_AURA` | Legacy handler no-ops (`Dcr_Events.lua:790–796`). 12.1 replacement is empty (`Dcr_12_1.lua:599–602`). AuraContainer consumes the event. |
| `CombatLogGetCurrentEventInfo()` | **Not called** on 12.1 live dispatch (`Dcr_Events.lua:1027`). Guard is *before* the API. |
| `UnitName` / class / charm | `pcall` + `canaccessvalue` / `issecretvalue` (`Dcr_utils.lua:177–182`, `Dcr_12_1_Utils.lua:79–108`). |
| `playerKnowsSpell` | Same gates (`DCR_init.lua:1010–1027`). |
| Secret **booleans** (dead, in-range) | Passed straight into `SetVertexColorFromBoolean` — no Lua `if value then` (`Dcr_12_1.lua:1291–1344`). |

This is the reason the fork exists. A “restore UnitAura for better tooltips”
change is a product-killing regression.

### 3.2 Combat vs out of combat

**Blocked in combat (`InCombatLockdown`):**

- MUF `SetAttribute` / macrotext (`Dcr_DebuffsFrame.lua:1544–1556`)
- `RefreshMUFActionMacros` (`DCR_init.lua:2694–2701`)
- Account-macro create/edit (`DCR_init.lua:2502`, `:2770–2774`)
- MUF show/hide/scale/reset positions
- Overlay **construction** (`nativeConfigurationBlocked()`, `Dcr_12_1.lua:75–77`)
- AuraContainer attach / `SetUnit`
- Soul Link **module startup** (deferred to regen)
- Sound **registration** (`AddAuraSound` / `RemoveAuraSound`) — see §3.4
- First load of `Decursive_Options` (`ZD_LoadOptions.lua:109–111`)
- Profile import (`Dcr_ProfileIO.lua:663–665`)
- `ReConfigure` / `Configure`
- Slash `/dcrreset` window move (`Decursive.lua` delayed `ResetWindow`)

**Still works in combat:**

| Capability | Why |
|---|---|
| Click MUF to cleanse / rez / Soul Link | Game evaluates `@unit,dead,combat,nodead` on **already-set** `macrotext` |
| Affliction color on squares | Blizzard AuraContainer, not Lua |
| Death / Soul Link / range / cooldown **colors** on existing overlays | Tickers + secret-aware texture APIs; no `SetAttribute` |
| Sounds already registered | Blizzard plays them; addon does not hook AuraSlot visibility |
| DISPEL text / status lights | Addon-owned frames, no secure attributes |
| PreClick attempt attribution | Insecure hook (`Dcr_DebuffsFrame.lua:1256–1265`) |

**Queued, applied at regen:** `Dcr_Events.lua` `PLAYER_REGEN_ENABLED` flushes
`AddDelayedFunctionCall`, `FlushModernSecureUIDirty`, and
`FlushProtectedAuraSoundRefresh`. V13 `CombatScheduler.lua` is a **second**
queue for settings UI — do not assume one list is the other.

### 3.3 Smart MUF resurrection — claims vs code

README / CHANGELOG claim: left-click a dead square to resurrect; combat uses
battle rez or Soul Link item; OOC uses the class rez; Warlock Soulstone is
ignored.

**True on HEAD:**

- Spell lists (`DCR_init.lua:1003–1008`): normal `{50769, 7328, 2006, 2008, 115178, 361227}`; battle `{20484, 61999, 391054}`. **20707 Soulstone is not in either list.**
- Macro text uses secure conditionals only (`DCR_init.lua:2611–2641`):
  - `[@u,help,exists,dead,combat]` / `dead,nocombat` / `nodead`
  - Soul Link is `/use … item:269586`, never `spell:1259646` in the macro
- Ownership: Soul Link fills a branch only when **no** native rez owns that branch (`:2582–2587`).
- Attribute routing keys off `IsMUFRezEligibleUnitToken` (string must not contain `"pet"`) and `smartRezAvailable`. **No `UnitIsDeadOrGhost` in `UpdateAttributes`.**
- Combat defers `RefreshMUFActionMacros`.
- 255-byte budget; oversize names fall back to cure-only and log debug (`test-smart-rez.lua` asserts this).

**Harness:** `.github/scripts/test-smart-rez.lua` actually `load()`s the builder
and `SetMacrosPerPrioTable` with mocked `SECRET_VALUE` / `InCombatLockdown`.
It then string-searches the MUF/event/Soul Link files for invariants. It does
**not** instantiate a secure button.

### 3.4 Soul Link routing — claims vs code

Module header (`Dcr_12_1_SoulLink.lua:22–36`) is accurate:

- Item `269586`, spell `1259646` (5-yard). Range via `C_Spell.IsSpellInRange`, not item API.
- Visuals only: **zero** `SetAttribute` / `RegisterForClicks` / `@mouseover` rebuilds in this file (harness enforces).
- Reads cached `Status.SmartRezActions`, does not rediscover spells.
- Green = in range + ready + installed action; yellow = OOR; black = not our action / on CD / secret cooldown / pet / alive.
- Native battle rez permanently owns combat; Soul Link does not overlay it.
- `UI_ERROR_MESSAGE` range warning is bound to the **stored attempt unit**, not a later MUF reassignment (`test-soul-link-visual.lua` last cases).

Startup itself is combat-gated. Toggling `/dcrsoullink` in combat defers the
macro rewrite; the overlay can show stale ownership until regen (**M1-class
lag, not a taint**).

### 3.5 Sound trigger — claims vs code

v12.1.2 CHANGELOG (`Decursive/CHANGELOG.md:21–26`) matches the code:
`nativeAuraSoundMutationBlocked()` uses `C_ChatInfo.InChatMessagingLockdown()`
(`Decursive.lua:436–447`). `HasActiveAddonRestriction` is for AuraContainer /
identity tooltip lifecycle, **not** sounds.

- **Register** out of lockdown via `C_UnitAuras.AddAuraSound` for public IDs from DispelDB / manual learn.
- **Play** is Blizzard-owned on aura *add*. Stack/dose must not register `ApplicationsIncreased` (validator forbids that symbol).
- Raid: player keeps the full ID pool; other raid members are instance-scoped (`Decursive.lua:1069–1100`).
- A reload that begins already locked down cannot recreate handles until the gate clears (`FEATURE_CONTRACT.md:107–110` — this part is true).

`Midnight.lua` notes a community ID set, 10/10 Wowhead spot-check, and
deliberate omissions. Treat IDs as **curated**, not scraped. A “sync all DBM
auras” job will false-positive cleanse sounds.

### 3.6 Claims this audit discards or narrows

| Claim (context / docs) | Verdict |
|---|---|
| v13 runtime hardening on HEAD | **True** — combat scheduler, secret helpers, overlay inner-square sync, cold-login MUF recovery (`DCR_COLD_LOGIN_MUF_RECOVERY_V1` at `Dcr_Events.lua:752`). |
| Smart MUF resurrection | **True** as secure macros; **false** if read as “Lua checks death and picks a spell.” |
| Soul Link routing | **True** for item-on-macro + visual module. |
| Tag-only two-job pipeline | **True on master.** Alpha’s copy also verifies the `alpha` branch. |
| Packaging validators | **True that they exist.** **False that they catch every ship-blocker** (H4). |
| Past broken tags | **True.** GitHub releases for `v11.0.46`, `v12.0.4`, `v12.0.5`, `v12.1.2` are **gone**; tags remain. `RELEASE_PROCESS.md:612–615` says the CF files were pulled by the maintainer. |
| Live List / UnitAura cleansing on 12.1 | **False.** Disabled. |
| `V13/Platform/ProtectedAuras.lua` | **Does not exist.** |

---

## 4. Packaging and release

### 4.1 What the packager actually does

`.pkgmeta`:

- `package-as: Decursive` — **entire checkout** stages under that name.
- `move-folders: Decursive/Decursive → Decursive` (self-reference; without it the toc is nested and the addon does not load) and `Decursive/Decursive_Options → Decursive_Options`.
- **No `externals:`** — all libs are git-tracked. Re-adding externals → `Directory not empty` on the self-ref move.
- **No `manual-changelog:`** — stale path after move-folders → CF `Missing field metadata` + failed GitHub release.
- `enable-nolib-creation: yes` is a **no-op** without externals. Leave it.
- `license-output: LICENSE.txt` copies GPLv3 into **both** addon folders.

### 4.2 Repo root vs zip (HEAD dry run)

| Root path | Ignored? | In dry-run zip? |
|---|---|---|
| `Decursive/`, `Decursive_Options/` | n/a | Yes — the product |
| `README.md`, `RELEASE_PROCESS.md`, `LICENSE` | Yes | No |
| `.gitattributes`, `.editorconfig`, `.docmeta` | Yes | No |
| `.pkgmeta`, `.github/`, `.gitignore` | No explicit ignore | **No** (packager omits) |
| `AUDIT.md` (this file) | **Must be ignored** — added with this PR | Must stay out |

Anything **new** at repo root ships inside the addon unless `.pkgmeta` ignore
gains a line. That is how v12.1.2 put `README.md` + `RELEASE_PROCESS.md` in
users’ AddOns folders and collided with `Decursive/Readme.md` on Windows.

### 4.3 What HEAD ships that the repo also contains

**Intended user-facing:** `Decursive/README.md` (new guide, commit `5c64204`),
runtime Lua/XML/TOC, `Sounds/`, `Textures/`, vendored `Libs/`, generated
`LICENSE.txt`.

**Ships today, questionable:**

| File | Packed size | Ignored? | Leak-check? |
|---|---:|---|---|
| `Decursive/CHANGELOG.md` | 115,425 | No | No |
| `Decursive/OldChangeLog.md` | 78,888 | No | No |
| `Decursive/WhatsNew.md` | 15,456 | No | No |
| `Decursive/RELEASE_NOTES_v12.1.3.md` | 4,915 | No | No (`v12.1.2` is ignored; `v12.1.3` is not) |
| `Decursive/Database/README.md` | 1,444 | No | No |
| `Decursive_Options/README.md` | 936 | No | No (dev install notes) |

**Correctly excluded:** `Decursive/docs/**`, branding (`decursive-logo.jpg`,
612 KB), `V10*`/`V11*` notes, `Todo.txt`, `RELEASE_NOTES_v11*` / `v12.0*` /
`v12.1.2`.

Uncompressed zip listing totals **3,917,365** bytes / 183 files;
`GoldBorder.tga` is 1,048,594 on disk but ~25 KB compressed — art is no longer
the v12.0.4 logo problem. Markdown is the remaining bloat.

### 4.4 Tokens

Source baseline (validator-enforced): **50** `@project-version@`, **4**
`@project-date-iso@`, **1** `@project-abbreviated-hash@`. Confirmed on HEAD.

`Decursive/CHANGELOG.md:525` contains a **prose** `@project-version@`. It
counts toward the 50. If that sentence is deleted, CI fails. If someone quotes
the token again in markdown, CI fails the other way. Name tokens in prose
without spelling them (`RELEASE_PROCESS.md:575–577`).

`--@debug@` / `--@end-debug@`: **zero** in source. CI greps for them. The
upstream packager bug is **not fixed**; markers returning (e.g. a LibQTip bump)
will ship `]==]]==]`.

### 4.5 Pipeline

One workflow: `.github/workflows/build-package-and-upload.yml`.

| Job | Credentials | When | Does |
|---|---|---|---|
| `verify` | None. `contents: read`. `persist-credentials: false` | PR→master, push master, `v*` tags, `workflow_dispatch` | luacheck (2 passes), debug-marker grep, `validate-v13.sh`, packager `-d`, `validate-package.sh .release` |
| `release` | `CF_API_TOKEN ← secrets.CF_API_KEY`, `GITHUB_API_TOKEN ← github.token` | **Only** `push` + `refs/tags/v*` after verify | Packager upload |

Actions are pinned to full SHAs (`checkout@11d5960a…`,
`BigWigsMods/actions/luacheck@a2a89117…`,
`BigWigsMods/packager@36b4c3b7…`).

A **tag push publishes regardless of branch**. `v12.1.4-alpha.*` tags already
published pre-releases from `alpha`. That is why alpha work is live on GitHub
(and likely CurseForge alpha files) while `master` lags.

`workflow_dispatch` cannot publish. Use it as rehearsal. Compare the run’s
`headSha` to `git rev-parse HEAD` before tagging.

### 4.6 HEAD vs published

| Channel | Ref | Shippable? |
|---|---|---|
| Stable CurseForge / “Latest” GitHub | `v12.1.3` (`ec70e1a`) | Yes — last clean *stable* tag. Missing 3 master commits (README adoption, pipeline docs, v13/rez hardening). |
| HEAD / `master` | `98bf895` = `v12.1.4-alpha.1` | Yes as **alpha**. Already a GitHub pre-release (2026-08-28). Not a stable cut (M2, H4). |
| Newest published pre-release | `v12.1.4-alpha.4` on `origin/alpha` | Newer product. Not on `master`. Alpha CI failed twice during that week, then went green. |

GitHub releases exist for `v12.1.3`, `v12.1.1`, `v12.0.7`, and the four
alphas. **No** GitHub release objects for `v12.1.2`, `v12.0.6`, `v12.0.5`,
`v12.0.4`, `v11.0.46` (tags remain). Deleting a GitHub release does **not**
delete the CurseForge file.

---

## 5. Quality gates — what they catch and miss

| Gate | What it actually does | Misses |
|---|---|---|
| luacheck pass 1 (`-qo 011`) | Syntax on **all** 83 Lua files. WoW globals ignored. | Packaging corruption (tokens, `]==]]==]` introduced at pack time). |
| luacheck pass 2 (`--no-global` + ignores) | Correctness on the **maintained** set (Dcr_12_1*, V13, Modern, Database, most core, `ZD_UI.lua`). | `Dcr_Raid.lua`, `Dcr_lists.lua`, `Dcr_LDB.lua`, all Localization, all Libs, `Dcr_opt_tree.lua`, `ZD_BlizzardSettings.lua`, `TestMode.lua`. |
| Debug-marker grep | `--@debug@`, `]==]]==]` in source | Packager-introduced copies (that is why package parse exists). |
| `validate-v13.sh` | Workflow shape, SHA pins, token baseline 50/4/1, TOC author/license/email, AceComm prefix, Wellesz year, git-history attribution since `v12.0.7`, 16 v13 files, loop-capture bugs, combat-guard *string* presence, sound/CLEU/MUF invariants, TOC file existence, loc formats, then harnesses + `luac`/`xmllint` if tools exist | Semantic equality of env-default tables; in-game combat; files never mentioned in a `rg -q` needle. |
| `validate-localizations.sh` | Format-string signatures vs enUS (355 keys). Duplicates fail. | Completeness (`itIT` 0% still passes). |
| `validate-package.sh` | Structure, tokens, Lua parse of **packaged** files, TOC refs, dual LICENSE.txt, case-insensitive collisions, a **partial** leak list, no `docs/` / `.github/` / `branding/` | `CHANGELOG.md`, `WhatsNew.md`, `OldChangeLog.md`, `RELEASE_NOTES_v12.1.3.md`, in-addon READMEs. Skips Lua parse if no interpreter (CI installs lua5.4). |
| `test-smart-rez.lua` | Executes the macro builder + combat deferral; string-checks routing | Real `SecureActionButton` / 255-byte UTF-8 edge in WoW’s macro engine. |
| `test-soul-link-visual.lua` | Executes the Soul Link file with mocked `C_Item`/`C_Spell`; secret cooldown; attempt unit | Real 5-yard range, item lockouts, secret `UnitIsDeadOrGhost` in game. |

**This checkout:** `validate-v13.sh` PASS (harnesses skipped until lua5.4 was
installed, then both PASS). `validate-package.sh .release` PASS with the H4
blind spot. `luac5.4 -p` 83/83. No BOM. No CRLF. No case-insensitive collision
in `Decursive/` or the zip. Branding present on disk, absent from zip.

There is **no** `.luacheckrc`. Policy lives in the workflow `args:`.

`Decursive/docs/v13/TEST_MATRIX.md` is the in-game contract. Automated gates
do not replace it. Cold-client MUF recovery and Mythic+ secret-aura clicks are
listed there and **cannot** be proven in this environment.

---

## 6. Risks

### Credentials

- Only secret: `secrets.CF_API_KEY` → env `CF_API_TOKEN`, **release job only**.
- GitHub publish uses `${{ github.token }}` with job `contents: write`, not a PAT.
- Workflow `permissions: {}` then least-privilege per job.
- `persist-credentials: false` on both checkouts.
- No tokens in the tree. `## X-eMail: randylorfing@gmail.com` is public
  maintainer contact (validator requires it). Wellesz `Decursive AT 2072…` in
  headers is attribution.

### GPL / attribution

- Root `LICENSE` == `Decursive/LICENSE.txt` (GPLv3). Packager copies it to both
  addons. Root `LICENSE` is ignored from the zip.
- Wellesz-lineage files on HEAD carry `Copyright (C) 2006-2026 John Wellesz`
  plus `WoW 12.1 compatibility and ongoing maintenance, Copyright (C) 2026 Randy Lorfing`.
- Fork-new files carry Randy-only Form B / V13 headers. GPL notices present
  (validator: 0 files missing “GNU General Public License” outside Libs).
- **M6:** `Dcr_opt_tree.lua` Form B on extracted Wellesz tree.
- `embeds.xml` / `Localization/load.xml` omit the Quu paragraph
  (`RELEASE_PROCESS.md:187–190`) — cosmetic, pre-existing.
- Third-party `Libs/` keep upstream licenses. Out of scope.

### Windows case, BOM, line endings

| Check | HEAD |
|---|---|
| Case collision in source or zip | None. `Decursive/Readme.md` was deleted after v12.1.2; only `README.md` remains. |
| UTF-8 BOM | None (stripped in `d9bd5c6` from `ZD_UI.lua`, `Dcr_opt_tree.lua`, `ZD_Core.lua`). |
| CRLF | None. `.gitattributes` forces LF on `*.sh` / `*.yml`. `.editorconfig` wants LF globally. |
| Script modes | `validate-v13.sh` / `validate-package.sh` `755`; `validate-localizations.sh` `644`. Invoke with `bash path` anyway. |

Windows **cannot** locally prove a case collision; the filesystem collapses the
pair. That check only means anything on Linux CI.

### CurseForge vs GitHub drift

- Tag upload hits **both**. Pulling a bad build means both.
- CF’s public page can lag an accepted upload by tens of minutes
  (`RELEASE_PROCESS.md:584–588`). `Uploading ... Success!` is authoritative.
- Alpha tags already create GitHub pre-releases. Confirm whether CF should
  receive those before the next `v12.1.4-alpha.5`.
- `.docmeta` is stale (M4) — CF long description may not match `Decursive/docs/`.

### Offline zip / factory hygiene

The maintainer often hands packaged zips, not source (`RELEASE_PROCESS.md` §4).
Tokens arrive substituted. Line endings flip. A clean replace deletes
`branding/` (absent from zips **by design**). Factory bots must **merge**,
restore the 50/4/1 token baseline, and never `git add -A`.

---

## 7. Recommended next factory jobs (ranked)

Smallest job that reduces the next-release failure rate first.

| # | Job | Why this repo, why now |
|---|---|---|
| 1 | **Pick a source of truth: merge `alpha` → `master` or freeze `master`.** Document the rule in `RELEASE_PROCESS.md`. Until then, every bot needs an explicit base-branch. | H1. Six commits and four published alphas are invisible on master. This is the only job that unblocks the rest without duplicate work. |
| 2 | **Close the markdown leak allowlist.** Ignore (or explicitly allow-list) `CHANGELOG.md` / `OldChangeLog.md` / `WhatsNew.md` / `RELEASE_NOTES_v12.1.3.md` / `Database/README.md`. Teach `validate-package.sh` the same list. Add a CI check: “new repo-root file ⇒ matching `.pkgmeta` ignore.” | H4 + the v12.1.2 class. Validators currently congratulate themselves. |
| 3 | **In-game combat-reload protocol** (TEST_MATRIX addition, not a drive-by Lua rewrite). `/reload` in combat, first `/dcr` in combat, Soul Link toggle in combat, sound registry at dungeon zone-in. Record `/zdmuf` + `/zdsound` + `/dcrstatus`. | H2, H3. No cloud agent can prove this. |
| 4 | **Unify environment defaults** as a *dedicated* change: one table, AceDB defaults generated from it, ZD fallback deleted, import/reset share the generator. Add a harness that diffs the three copies. | M1. Maintainer-deferred; do not sneak it into job 2. |
| 5 | **Retag hygiene for the next stable:** bump `X-Zhaohu-12.1-Patch`, write `RELEASE_NOTES_v12.1.4.md`, decide whether HEAD+alpha is `v12.1.4` or still alpha. Rehearse `workflow_dispatch` on the exact SHA, then tag. | M2. Version metadata is how support tickets get triaged. |
| 6 | **Bring master’s workflow in line with alpha** (`alpha` on push/PR) *or* delete that divergence by merging (job 1). | M5. |
| 7 | **Fix `.docmeta` paths** to `Decursive/docs/…`. | M4. Cheap; unblocks CF page generation. |
| 8 | **Attribution pass on `Dcr_opt_tree.lua`** (Form A). Optionally drop the “solely written” line on any other extracted file. | M6. Legal hygiene, not a user-facing bug. |
| 9 | **Harness expansion:** env-default equality; profile import combat guard; token-count includes a “no new prose token” markdown scan; optional `luac` in `validate-package.sh` as hard-required (fail if no interpreter). | Quality-gate holes in §5. |
| 10 | **itIT (and deDE) localization** only after the next stable feature freeze. | L1. AceLocale fallback works. Do not block releases on this. |

**Do not schedule:** a v13 rewrite, AceGUI restoration, Live List revival on
12.1, UnitAura “for debugging,” externals for nolib zips, changelog
`manual-changelog:` restoration, or an upstream merge from 2072 without a
secret-value plan.

---

## 8. Smallest useful specialist roster (this repo)

Not a web team. Four roles cover the failure modes this tree has already paid for.

| Role | Owns | Does not own |
|---|---|---|
| **Release / packaging engineer** | `.pkgmeta`, workflow, validators, tokens, tags, CF/GitHub zip inspection, ignore-rule discipline | Combat Lua |
| **12.1 runtime engineer** | `Dcr_12_1*.lua`, `Decursive.lua` sound registry, `DCR_init.lua` macros, `Dcr_DebuffsFrame.lua` attributes, `Dcr_Events.lua` 12.1 guards | Settings chrome |
| **Settings / profile engineer** | `Decursive_Options/V13/**`, `ZD_UI.lua`, `Dcr_opt.lua` defaults, `Dcr_ProfileIO.lua`, env-default unification (job 4) | Secure click path |
| **In-game QA (human or a bot *with a WoW client*)** | TEST_MATRIX, combat-reload, M+ secrets, PvP text-off, cold login `/zdmuf` | Shipping without a downloaded zip |

Optional fifth, **part-time:** localization (after freeze) + GPL header
reviewer (job 8). That is not a standing seat.

A generic “frontend / backend / DevOps / QA” split will edit the wrong files.
The packaging engineer *is* DevOps here. The runtime engineer *is* the
security engineer (secret values == taint). QA without a client is just
re-running `validate-v13.sh`.

---

## 9. Handoff rules for factory bots

Copy these into the factory system prompt.

1. Base branch is an explicit argument. Default is **wrong** until job 1 lands.
2. Never force-push `master`. Never rewrite published tags. Fix forward.
3. No `Co-Authored-By: Claude` (or any vendor trailer).
4. Never `git add -A`. Stage named paths. `*.zip` is gitignored; `.release/`
   unpacked trees may not be.
5. After any root-level file add: `.pkgmeta` ignore + leak-pattern update in
   the same commit. This audit file is the example.
6. After any Lua/XML edit: `bash .github/scripts/validate-v13.sh`. After any
   packaging edit: packager `-d` + `validate-package.sh .release`.
7. Restore packager tokens to 50 / 4 / 1. Do not spell `@project-version@` in
   new markdown.
8. Do not strip Wellesz copyright. Do not “fix” env defaults in a drive-by.
9. Do not call `UnitAura` / `CombatLogGetCurrentEventInfo` / `UpdateAllAuras`
   on the 12.1 path. Do not put `HasActiveAddonRestriction` back on sounds.
10. A green workflow is not a release. Download the zip. Check depth-2 tocs,
    no `]==]]==]`, no raw tokens, no `Decursive/Decursive/`.
11. Offline maintainer zips are packaged builds. Merge; do not replace.
12. If asked for a fix **and** an exploit/PoC against WoW’s secret-value
    sandbox: ship the fix only.

---

## 10. Evidence index

| Topic | Primary paths |
|---|---|
| TOC / load order | `Decursive/Decursive.toc`, `Decursive_Options/Decursive_Options.toc` |
| Secret / 12.1 policy | `Dcr_12_1.lua`, `Dcr_12_1_Utils.lua`, `V10.41_12.1_SECRET_SAFETY.md` |
| Secure MUFs | `Dcr_DebuffsFrame.lua` `UpdateAttributes` |
| Smart rez macros | `DCR_init.lua` `BuildSmartRezMacroText`, `.github/scripts/test-smart-rez.lua` |
| Soul Link | `Dcr_12_1_SoulLink.lua`, `test-soul-link-visual.lua` |
| Sounds | `Decursive.lua` `nativeAuraSoundMutationBlocked`, `Database/Dispels/Midnight.lua` |
| Combat deferral | `Dcr_Events.lua` `PLAYER_REGEN_ENABLED`, `V13/Core/CombatScheduler.lua` |
| LoD settings | `Modern/ZD_LoadOptions.lua`, `V13/Shell.lua` `InstallAsPrimary` |
| Env defaults | `Dcr_12_1.lua:133–229`, `Dcr_opt.lua:275–282`, `Modern/ZD_Core.lua:52–143` |
| Packaging | `.pkgmeta`, `validate-package.sh`, `validate-v13.sh` |
| Pipeline | `.github/workflows/build-package-and-upload.yml` |
| Process / past burns | `RELEASE_PROCESS.md` |
| In-game contract | `Decursive/docs/v13/TEST_MATRIX.md`, `FEATURE_CONTRACT.md` (trust code over the sound-gate sentence) |
| User docs | root `README.md` (repo), `Decursive/README.md` (ships) |

### Commands re-run for this audit

```
git log --oneline v12.1.3..HEAD
git log --oneline origin/master..origin/alpha
bash .github/scripts/validate-v13.sh          # PASS
bash .github/scripts/validate-package.sh .release  # PASS (see H4)
lua5.4 .github/scripts/test-smart-rez.lua     # PASS
lua5.4 .github/scripts/test-soul-link-visual.lua  # PASS
# luac5.4 -p on 83 Lua files                  # 0 failures
gh release list --repo randylorfing/Decursive
```

### What this audit did not do

- No WoW client, no combat click, no CurseForge file-page login check.
- Did not merge `origin/alpha` or diff every alpha hunk (profile manager is
  out of scope for the *master* product description; job 1 must happen first).
- Did not change addon Lua/XML. No critical silent taint/crash bug was found
  that justified a behavior patch in the same PR as this report.
- Companion packaging-safety edits shipped with this document only: ignore
  `AUDIT.md` from the addon zip, and ignore `.release/` in git so a dry-run
  cannot be committed.

---

*End of audit. Hand jobs 1–3 to named owners before opening any feature PR.*
