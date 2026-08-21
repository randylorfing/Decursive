# Zhaohu's Decursive for WoW 12.1

**Zhaohu's Decursive** is a modernized version of Decursive designed for World of Warcraft Retail 12.1, with support for Blizzard's protected aura system, optional DandersFrames integration, sound notifications, local dispel databases, cooldown tracking, profiles, and customizable Micro Unit Frames.

Repository: https://github.com/randylorfing/Decursive/

---

# Features

* Micro Unit Frames (MUFs) for fast dispelling
* Supports all healer classes/specs with dispel abilities
* Magic, Poison, Disease, Curse, Charm, and supported special dispel types
* Blizzard 12.1 protected aura compatibility
* Optional DandersFrames integration
* Native Blizzard aura detection when DandersFrames is disabled or unavailable
* Female voice dispel notifications
* Local dispellable-spell database
* Expansion-specific spell databases
* Cooldown overlays
* Role-based MUF ordering
* Priority dispel highlighting
* Custom mouse bindings
* Profile support
* Automatic zone/instance reinitialization
* Dungeon, Raid, Mythic+, PvP, Open World, and Follower Dungeon support

---

# Important Technical Note

The **user-facing addon name** is:

```text
Zhaohu's Decursive
```

For compatibility with the original Decursive architecture, the technical addon identity remains:

```text
Root folder:        Decursive
TOC file:           Decursive.toc
Internal addon ID:  Decursive
SavedVariables:     DecursiveDB
```

Do **not** rename the addon folder to `Zhaohu's Decursive`.

---

# Installation

Extract Zhaohu's Decursive into your World of Warcraft Retail AddOns directory.

The final folder must be:

```text
World of Warcraft
└── _retail_
    └── Interface
        └── AddOns
            └── Decursive
                ├── Decursive.toc
                ├── Decursive.lua
                └── ...
```

The root folder must remain:

```text
Decursive
```

After installing or updating the addon, completely restart World of Warcraft.

---

# Opening Zhaohu's Decursive

Use:

```text
/decursive
```

to open the Zhaohu's Decursive configuration window.

The settings interface contains sections for features such as:

* Micro Unit Frames
* Cooldowns
* Curing
* Spells & Bindings
* Priority List
* Skip List
* Colors
* Display Options
* Sound Notifications
* Integrations
* Dispel Database
* Profiles
* System / Status

---

# Micro Unit Frames

Micro Unit Frames, or **MUFs**, are the small squares used by Zhaohu's Decursive to identify and dispel afflicted players.

Each square represents a party or raid member.

When a player receives an affliction that your current character can remove, the corresponding MUF changes appearance.

For example:

```text
Normal square
     ↓
Player receives a dispellable debuff
     ↓
Square highlights red/blue
     ↓
Use your configured mouse binding
     ↓
Debuff is removed
```

The exact colors can be customized in the Zhaohu's Decursive settings.

---

# MUF Ordering

MUFs can be organized using role-based ordering.

The normal order is:

```text
Tank
Healer
DPS
```

Your own MUF can also be identified with the player indicator.

MUF size, borders, fonts, positioning, and other visual settings can be adjusted from the **Micro Unit Frames** settings.

---

# Dispelling

Zhaohu's Decursive automatically determines which types of afflictions your current class and specialization can remove.

Supported categories include:

* Magic
* Poison
* Disease
* Curse
* Charm
* Other supported class-specific dispel effects

Examples of supported healer dispels include:

* Monk — Detox
* Paladin — Cleanse
* Druid — Remove Corruption / Nature's Cure
* Priest — Purify / Dispel Magic
* Shaman — Purify Spirit / Cleanse Spirit
* Evoker — Expunge / Naturalize

The addon is designed around capability detection rather than being tied to one healer class.

---

# Mouse Bindings

Open:

**Spells & Bindings**

to configure which spell or action is associated with your MUF mouse buttons.

Bindings can use:

* Left Click
* Right Click
* Middle Click
* Modifier combinations

Examples:

```text
Left Click
Shift + Left Click
Ctrl + Left Click
Alt + Left Click
Right Click
Shift + Right Click
```

Configure these according to the dispel abilities available to your class/spec.

---

# Priority System

Zhaohu's Decursive supports priority levels for important afflictions.

Priority highlighting can use:

* Inner MUF color
* Border color
* Custom priority colors
* Priority-specific cooldown information

This allows particularly dangerous mechanics to stand out from normal dispellable effects.

---

# Cooldown Overlay

Zhaohu's Decursive can display the remaining cooldown of the appropriate dispel ability directly on the MUF.

The overlay can include:

* Numeric countdown
* Darkened cooldown overlay
* Configurable font size
* Configurable display options

Cooldown behavior is based on the appropriate dispel ability for the current class/spec.

---

# Sound Notifications

Zhaohu's Decursive can play an audio alert when a known dispellable aura is applied.

Open:

**Sound Notifications**

to configure the feature.

Available controls include:

* Enable/disable sound notifications
* Select alert sound
* Select output channel
* Test Sound
* Cure-failure notification

The default alert for new/default configurations is:

**Female Voice — Dispel**

Press **Test Sound** to verify that your selected alert is working.

---

# How Sound Detection Works in WoW 12.1

World of Warcraft 12.1 protects much of the detailed aura information used by addons during combat.

Because of this, Zhaohu's Decursive does not rely on reading protected debuff information after the aura appears and then trying to trigger a sound.

Instead, Zhaohu's Decursive maintains a local database of known dispellable Spell IDs.

The process is:

```text
Zhaohu's Decursive Dispel Database
        ↓
Determine what your class/spec can dispel
        ↓
Register applicable Spell IDs with Blizzard
        ↓
Debuff is applied
        ↓
Blizzard detects the aura
        ↓
Female dispel alert plays
```

This uses Blizzard-supported aura-sound functionality and avoids unsafe protected-aura hooks.

---

# Dispel Database

Zhaohu's Decursive contains a local database of known dispellable abilities.

The database is organized by expansion:

```text
Database/
└── Dispels/
    ├── Classic.lua
    ├── TheBurningCrusade.lua
    ├── WrathOfTheLichKing.lua
    ├── Cataclysm.lua
    ├── MistsOfPandaria.lua
    ├── WarlordsOfDraenor.lua
    ├── Legion.lua
    ├── BattleForAzeroth.lua
    ├── Shadowlands.lua
    ├── Dragonflight.lua
    ├── TheWarWithin.lua
    └── Midnight.lua
```

Database records can contain:

* Spell ID
* Spell name
* Dispel type
* Expansion
* Dungeon or encounter
* Friendly debuff classification
* Enemy purge classification
* Sound-alert eligibility

The database can be expanded as new mechanics are discovered.

---

# Dispel Database Status

The **Dispel Database** settings page shows information about the currently loaded database.

This can include:

* Total database entries
* Friendly dispellable spells
* Enemy purge entries
* Entries by expansion
* Entries by dispel type
* Current coverage

You can also use:

```text
/zddb
```

to print database information to the chat window.

---

# Sound Diagnostics

Use:

```text
/zdsound
```

to display information about the live sound-registration system.

The diagnostic output may include:

```text
Build marker
Database spell count
Applicable spell count
Current units
Registered spell IDs
AuraSound registration success
```

This is useful when troubleshooting a mechanic that highlights the MUF but does not produce an alert.

---

# DandersFrames Integration

Zhaohu's Decursive can optionally use **DandersFrames** as its managed aura provider.

Open:

**Integrations**

and use:

**Enable DandersFrames integration**

## Default Behavior

If DandersFrames is installed and supported:

```text
DandersFrames detected
        ↓
Integration enabled by default
```

If DandersFrames is not available:

```text
DandersFrames unavailable
        ↓
Native Blizzard provider used
```

You can manually disable DandersFrames integration at any time.

Your selection is saved.

---

# Native Blizzard Mode

DandersFrames is **not required**.

When DandersFrames integration is disabled, Zhaohu's Decursive uses Blizzard's native managed aura system directly.

Native mode still supports:

* MUF affliction highlighting
* Dispel detection
* Local DispelDB
* Sound alerts
* Cooldown overlays
* Priority behavior
* Mouse bindings

This allows Zhaohu's Decursive to function as a standalone addon.

---

# Changing Aura Providers

Switching between:

```text
DandersFrames
```

and:

```text
Native Blizzard
```

may require a UI reload because WoW 12.1 uses protected managed aura frames.

After changing the integration setting, use:

```text
/reload
```

if requested.

---

# Zoning and Instances

Zhaohu's Decursive automatically reinitializes its MUF and managed aura state when entering or leaving zones and instances.

This includes:

* Dungeons
* Mythic+
* Raids
* Follower Dungeons
* PvP instances
* Open World transitions

The addon rebuilds its unit list and retargets its aura providers while Blizzard's group roster settles.

You should normally **not need `/reload` after entering a dungeon**.

---

# Profiles

Zhaohu's Decursive supports profiles so different configurations can be maintained for different characters or activities.

Profiles can store settings such as:

* MUF appearance
* Size and positioning
* Cure behavior
* Priority behavior
* Mouse bindings
* Sound preferences
* Cooldown display
* Integration preferences

Use the **Profiles** section of the settings interface to manage profile behavior.

---

# Activity Modes

Zhaohu's Decursive can adapt its behavior to different types of content.

Supported activity concepts include:

* Open World
* Dungeon
* Follower Dungeon
* Mythic+
* Raid
* PvP

These modes allow detection and display behavior to be tuned according to the type of content being played.

---

# Priority List

The **Priority List** allows specific afflictions to receive increased visibility.

This is useful for mechanics that:

* must be dispelled immediately
* are dangerous if allowed to expire
* require coordinated dispelling
* are more important than normal removable effects

---

# Skip List

The **Skip List** can be used for effects that should not receive normal Zhaohu's Decursive treatment.

This can be useful for mechanics that:

* should intentionally remain active
* require special timing
* are technically dispellable but normally should not be removed
* could cause a negative effect if dispelled incorrectly

---

# Useful Commands

## Open Zhaohu's Decursive

```text
/decursive
```

## Dispel Database Status

```text
/zddb
```

## Sound Diagnostics

```text
/zdsound
```

Additional diagnostic/development commands may be available depending on the build.

---

# Recommended Initial Setup

After installing Zhaohu's Decursive:

1. Log into your healer or dispel-capable character.
2. Open Zhaohu's Decursive with `/decursive`.
3. Open **Micro Unit Frames**.
4. Position and size the MUFs.
5. Open **Spells & Bindings**.
6. Verify your dispel mouse bindings.
7. Open **Curing** and verify the cure types you want enabled.
8. Open **Sound Notifications**.
9. Enable sound notifications.
10. Select **Female Voice — Dispel** or another preferred sound.
11. Press **Test Sound**.
12. Open **Integrations**.
13. Choose DandersFrames or Native Blizzard detection.
14. Enter a dungeon and verify that all group MUFs appear.
15. When a dispellable debuff occurs, verify that the MUF highlights and the alert sound plays.

---

# Troubleshooting

## MUFs Do Not Appear

Try:

```text
/reload
```

If the problem continues:

* verify Zhaohu's Decursive is enabled
* verify the root folder is named exactly `Decursive`
* verify `Decursive.toc` is directly inside that folder
* check for Lua errors
* verify your group roster is available

---

## Sound Works With Test Sound but Not During Combat

Run:

```text
/zdsound
```

Check whether:

* the DispelDB loaded
* your current class/spec has applicable entries
* group units were detected
* Blizzard AuraSound registrations succeeded

If a particular mechanic highlights the MUF but never produces an alert, its Spell ID may need to be added to the local DispelDB.

---

## DandersFrames Is Installed but Native Mode Is Active

Open:

**Integrations**

and verify:

**Enable DandersFrames integration**

After changing providers, use:

```text
/reload
```

if necessary.

---

## Menu Page Does Not Display Correctly

Ensure you are running the current build and restart World of Warcraft after replacing addon files.

Avoid copying a new development build directly over an older build.

Delete the old `Decursive` directory first and install the new version cleanly.

---

# Updating Zhaohu's Decursive

For development/test builds, the safest update process is:

1. Exit World of Warcraft.
2. Delete:

```text
Interface/AddOns/Decursive
```

3. Extract the new build.
4. Verify:

```text
Interface/AddOns/Decursive/Decursive.toc
```

5. Restart World of Warcraft.

Your SavedVariables and profile data are stored separately by WoW and are not normally deleted when replacing the addon folder.

---

# WoW 12.1 Compatibility

Zhaohu's Decursive has been modified specifically for the protected aura changes introduced in modern World of Warcraft.

The design avoids attempting to bypass Blizzard's protected combat information.

Where protected aura state is required, Zhaohu's Decursive relies on Blizzard-supported mechanisms such as:

* Managed Aura Containers
* Secure mouse bindings
* Blizzard AuraSound registrations
* Public unit/group information

---

# Current Development Focus

Ongoing development includes:

* expanding the DispelDB
* increasing Midnight coverage
* increasing The War Within coverage
* adding additional legacy expansion mechanics
* validating Timewalking dispels
* improving profile behavior
* improving PvP-specific behavior
* improving sound coverage
* continuing UI and stability improvements

---

# Credits

**Zhaohu's Decursive** is based on the original **Decursive** addon and continues to preserve compatibility with its existing architecture where possible.

This project includes extensive compatibility modifications for modern World of Warcraft and WoW 12.1 protected aura behavior.

Please refer to the included license and authors files for attribution and licensing information.
