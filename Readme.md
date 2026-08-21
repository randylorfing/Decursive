# Decursive – Development Changelog

## Current Stable Baseline

**Base Version:** 11.0.10
**Current Build:** `square-sound25-root-decursive`

---

## Sound Notifications

### Added Live Dispel Alerts

* Added sound notifications when a registered dispellable aura is applied.
* Uses Blizzard's native `C_UnitAuras.AddAuraSound()` API for WoW 12.1 compatibility.
* Sound alerts work with both DandersFrames and the Native Blizzard aura provider.
* Removed unreliable attempts to detect protected auras through normal `UNIT_AURA` polling.
* Removed experimental AuraButton `OnShow` hooks that interfered with MUF affliction display.

### Female Voice Alerts

* Added female voice notification sounds.
* Added selectable dispel alert sounds.
* Added selectable output channel.
* Added **Test Sound** functionality.
* Added cure-failure notification option.
* Default dispel notification for new/default settings is:

**Female Voice – Dispel**

Existing saved sound selections are preserved.

### Sound Notifications Menu

* Rebuilt the Sound Notifications settings page.
* Fixed missing sound selector controls.
* Fixed missing output-channel controls.
* Fixed large blank sections in the original generic settings renderer.

---

## Local Dispel Database

### Added DispelDB Framework

Added a local spell database used to pre-register known dispellable debuffs with Blizzard.

Database structure:

```text
Database/
  DispelDB_Core.lua
  Dispels/
    Classic.lua
    TheBurningCrusade.lua
    WrathOfTheLichKing.lua
    Cataclysm.lua
    MistsOfPandaria.lua
    WarlordsOfDraenor.lua
    Legion.lua
    BattleForAzeroth.lua
    Shadowlands.lua
    Dragonflight.lua
    TheWarWithin.lua
    Midnight.lua
```

### Database Entry Support

Each entry can track:

* Spell ID
* Spell name
* Dispel type
* Expansion
* Dungeon / raid / encounter
* Friendly harmful debuff
* Enemy purge target
* Whether the aura should generate a sound alert

### Automatic Spell Filtering

* Database entries are filtered according to the current class/spec.
* Only dispel types the current character can remove are registered.
* Friendly harmful debuffs are separated from enemy purge entries.
* Applicable spells are automatically registered against current party/raid units.

### Current Spell Coverage

* Added verified Midnight dispellable spells.
* Added **Paralyzing Shots – Spell ID 1294569**.
* Added additional Magic, Poison, Disease, and Curse entries.
* Added verified entries from Legion.
* Added verified Dragonflight entries.
* Added support for expanding the database independently for every WoW expansion.

---

## Dispel Database Status

### Added Database Status Page

Added a dedicated **Dispel Database** settings/status page showing:

* Total database entries
* Friendly dispellable entries
* Enemy purge entries
* Entries by expansion
* Entries by dispel type
* Current database coverage status

### Added `/zddb`

New diagnostic command:

```text
/zddb
```

Displays local DispelDB statistics by expansion and dispel type.

### Improved `/zdsound`

The existing sound diagnostic command now displays information such as:

* Current development build
* Active built-in Spell IDs
* Applicable spells for the current spec
* Current unit count
* AuraSound registration count
* Registration success/failure
* Local DispelDB status

---

## Dungeon / Zone Reinitialization

### Fixed MUFs Disappearing After Zoning

Fixed an issue where entering a dungeon or changing zones could result in:

* Only the player's MUF appearing
* Only player and pet MUFs appearing
* No MUFs appearing
* Missing party members
* `/reload` being required to restore the MUFs

### Added Decursive Soft Reinitialization

On `PLAYER_ENTERING_WORLD`, Decursive now performs a deeper runtime reinitialization.

The process includes:

* rebuilding the party/raid unit array
* resetting MUF runtime state
* refreshing MUF creation/update passes
* reapplying MUF unit attributes
* retargeting managed aura providers
* refreshing DandersFrames integration when active
* refreshing Native Blizzard AuraContainers when active
* performing a full MUF update
* rebuilding AuraSound registrations

### Added Roster Stabilization

Additional refresh passes are performed while the dungeon/party roster settles after zoning.

This now allows MUFs to recover automatically without requiring `/reload`.

---

## DandersFrames Integration

### Added User Toggle

Added:

**Integrations → Enable DandersFrames integration**

### Default Behavior

* If DandersFrames is installed and usable, integration is enabled by default.
* If DandersFrames is unavailable, Decursive automatically uses the Native Blizzard provider.

### Persistent User Preference

* Users can manually disable DandersFrames integration.
* The user's choice persists across reloads/logins.
* Turning integration off switches Decursive to Native Blizzard-managed detection.
* Integration can be turned back on later.

### Provider Compatibility

Both providers remain supported:

```text
DandersFrames
      or
Native Blizzard Managed Aura Containers
```

The DispelDB and sound system operate independently of the selected provider.

---

## Native Blizzard Provider

* Native detection remains fully supported.
* Decursive does not require DandersFrames to function.
* Native mode continues to provide red/blue actionable MUF affliction display.
* Native mode uses the same DispelDB.
* Native mode uses the same Blizzard AuraSound registration system.

---

## MUF Affliction Display

* Preserved the working red/blue actionable affliction square behavior.
* Removed experimental hooks that interfered with protected AuraButtons.
* Sound notification logic no longer directly modifies or monitors the protected AuraButton.
* Blizzard/DandersFrames remain responsible for displaying the actionable affliction state.

---

## Menu / UI Navigation

### Fixed Settings Page Overlap

Fixed multiple settings pages occasionally remaining visible at the same time.

### Fixed Intermittent Blank Pages

Fixed an issue where some menu pages required multiple clicks before appearing.

### Fixed Pooled Control Error

Resolved:

```text
Frame:SetScript(): Cannot assign script handler for 'onclick'
```

The issue was caused by pooled generic `Frame` objects being treated as clickable `Button` objects during cleanup.

### Improved Navigation Stability

* Settings navigation now respects each page's normal `Refresh()` behavior.
* Complex pages such as **Spells & Bindings** are no longer forcibly rebuilt on every click.
* Reduced unnecessary UI destruction/recreation.
* Menu pages now respond more consistently on the first click.
* Page-navigation changes are isolated from MUF/provider functionality.

---

## Addon Root / Folder Restoration

### Restored Root Folder to `Decursive`

The physical addon folder is once again:

```text
Interface/AddOns/Decursive/
```

### Restored TOC Name

```text
Decursive/Decursive.toc
```

### Removed All `ZDecursive` References

Performed a complete case-insensitive audit of the project.

Confirmed:

```text
0 references to ZDecursive
0 references to zdecursive
```

All temporary folder-name changes were reverted.

### Internal Identity

The addon continues to use the original Decursive identities for compatibility:

```lua
AceAddon:NewAddon("Decursive", ...)
AceLocale:GetLocale("Decursive", ...)
AceDB:New("DecursiveDB", ...)
LibDataBroker:NewDataObject("Decursive", ...)
```

SavedVariables remain:

```text
DecursiveDB
```

### Restored Physical Asset Paths

All physical addon paths now point back to:

```text
Interface\AddOns\Decursive\
```

This includes:

* sounds
* textures
* icons
* XML texture declarations
* TOC icon paths
* UI assets

---

## Development Stability Fixes

* Removed unsafe protected AuraButton event experiments.
* Removed unreliable combat aura polling used for sound detection.
* Fixed DispelDB initialization/load order.
* Fixed expansion database registration against the Decursive addon object.
* Fixed development version mismatches that could trigger Decursive's fatal version protection.
* Development build markers remain separate from the official internal `11.0.10` addon version.
* Preserved SavedVariables and profile compatibility.

---

## Current Confirmed Working Features

* MUF squares load correctly.
* MUFs survive dungeon/instance zoning.
* `/reload` is no longer required after zoning.
* Red/blue actionable affliction squares work.
* Live dispel sounds work.
* Female voice notifications work.
* Sound test works from the settings menu.
* DispelDB loads correctly.
* Spell IDs are filtered by current class/spec.
* Blizzard AuraSound registrations succeed.
* DandersFrames integration works.
* Native Blizzard provider works.
* DandersFrames can be manually enabled/disabled.
* Menu navigation is functioning correctly.
* Root addon folder is restored to `Decursive`.
* No `ZDecursive` references remain.

---

## Current Development Direction

* Continue expanding the DispelDB for every WoW expansion.
* Prioritize complete Midnight dungeon and raid coverage.
* Expand The War Within coverage.
* Expand Dragonflight coverage.
* Continue backward through legacy expansions and Timewalking content.
* Continue validating dispel type and Spell ID accuracy.
* Maintain separation between friendly dispels and enemy purge targets.
* Keep future development based on the stable `square-sound25-root-decursive` baseline.
