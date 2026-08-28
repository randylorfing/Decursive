# Zhaohu's Decursive

![Zhaohu's Decursive logo](https://raw.githubusercontent.com/randylorfing/Decursive/master/Decursive/branding/decursive-logo.jpg)

**Detect. Cleanse. Protect.**

Zhaohu's Decursive is a fast, focused dispel assistant for **World of Warcraft Retail 12.1**. It preserves Decursive's compact Micro Unit Frames (MUFs) and click-to-cure workflow while adding a modern settings interface, Blizzard-native protected-aura support, combat alerts, sound notifications, cooldown feedback, and automatic environment profiles.

[Download on CurseForge](https://www.curseforge.com/wow/addons/decursive-12-1-compatibility-patch) | [Source on GitHub](https://github.com/randylorfing/Decursive) | [Report an issue](https://github.com/randylorfing/Decursive/issues)

> Zhaohu's Decursive is an independently maintained GPLv3 fork of [Decursive](https://github.com/2072/Decursive). It is not the upstream 2072 release.

## Features

- Compact, secure Micro Unit Frames for fast click-to-cure gameplay
- Native Blizzard managed-aura detection for WoW 12.1
- Automatic class, specialization, talent, and cure-spell detection
- Support for Magic, Poison, Disease, Curse, Bleed, and special cure types where available
- Movable party and raid layouts with independent size and spacing controls
- Dispel text alerts and selectable sound notifications
- Cooldown shading and countdown numbers inside each MUF square
- Optional range and cure-result indicators
- Priority and Skip Lists
- Custom mouse bindings and custom spells
- Named profiles with import and export
- Automatic Open World, Dungeon, Mythic+, Raid, and PvP behavior profiles
- Protected combat operations that are deferred until Blizzard permits them

No external unit-frame addon is required. Zhaohu's Decursive uses Blizzard's native protected-aura system directly.

## Installation

### CurseForge App

Install Zhaohu's Decursive normally through the CurseForge App. The package includes both required addon folders.

### Manual installation

1. Close World of Warcraft.
2. Download a packaged release from CurseForge or GitHub Releases.
3. Remove or move aside any existing `Decursive` and `Decursive_Options` folders. Do not merge a new release over an old installation.
4. Extract both folders into:

   ```text
   World of Warcraft\_retail_\Interface\AddOns\
   ```

5. Confirm this exact layout:

   ```text
   Interface\AddOns\Decursive\Decursive.toc
   Interface\AddOns\Decursive_Options\Decursive_Options.toc
   ```

6. Start World of Warcraft and enable both addons on the character-selection screen.

Keep the folder names exactly as shown. The main folder must remain `Decursive` so existing `DecursiveDB` settings continue to work.

Do not install GitHub's automatic **Source code** archive. Install a packaged release so version tokens, dependencies, localization, and release directives are processed correctly.

Replacing the addon folders does not normally delete your settings. WoW stores SavedVariables separately, but backing up your `WTF` folder before a major update is always sensible.

## Quick start

1. Type `/dcr` to open the settings window.
2. Open **MUFs**, enable **Show MUFs**, and turn off **Lock position**.
3. Drag the MUF handle to the desired location, then lock it again.
4. Set separate party and raid sizes, spacing, growth direction, and grid layout if desired.
5. Open **Cure** and verify the spells and mouse buttons assigned to each cure priority.
6. Open **Alerts**, choose a sound, and press **Test Sound**.
7. Enter a party, dungeon, or raid and click an afflicted player's MUF with the assigned mouse button.

The same settings window opens with `/decursive`, `/dcr`, `/zd`, or `/zdecursive`.

## Using the Micro Unit Frames

Each MUF represents a player or pet. When Blizzard reports an affliction your character can remove, the frame changes to show that action is needed. Click the square with the configured mouse button to cast the appropriate cure.

### What the MUF visuals mean

| Visual | Meaning |
| --- | --- |
| Colored inner square | The primary dispellable affliction and its configured cure priority |
| Red, blue, orange, or another fill color | A cure-priority color; orange is normally priority 3. Colors are customizable under **All Settings > Curing** |
| Colored or pulsing border | A second simultaneous dispellable affliction, when enabled |
| Dark shading or countdown number | The relevant cure is on cooldown for another player who still needs it |
| Yellow tint or dimming | The unit is outside the usable range of the configured cure |
| Tooltip on hover | Blizzard-provided unit and aura information where the game permits it |

Cooldown, range, and affliction visuals stay inside the MUF's inner square so the original border remains visible.

### Optional status light

The small status light above a MUF is disabled by default. Enable it under **MUFs** or **All Settings > Range & Visibility** if you want additional feedback.

| Light | Meaning |
| --- | --- |
| Yellow | The unit is out of cure range |
| Red | The cure failed or the affliction remained |
| Green | The cleanse succeeded |

Red and green result feedback remains visible briefly. Yellow takes priority while the unit is out of range. Disabling the status light restores the original tight MUF spacing.

### Tooltips and PvP

MUF hover tooltips are enabled by default. Blizzard can provide managed aura details in dungeon and raid combat. In PvP, Zhaohu's Decursive uses only the safe unit/help tooltip and does not attempt to read protected aura contents.

## Cure priorities and mouse bindings

Zhaohu's Decursive detects the cure spells available to your current class, specialization, and talents. Each cure priority can be assigned to a mouse button or modifier combination, including:

- Left, right, and middle click
- Mouse Button 4 and Mouse Button 5
- Shift, Ctrl, and Alt modifiers

Use **Cure** for the common controls or **All Settings > Spells & Bindings** for the complete assignment system.

Secure binding and frame-structure changes cannot be applied during combat. When necessary, Zhaohu's Decursive waits until combat ends before applying them.

## Alerts and sounds

### Dispel text alert

The on-screen **DISPEL** notification can be enabled per environment. Its size, position, duration, and related chat notice are configurable under **Alerts**. Test and live notifications use the same display pipeline.

PvP environment profiles disable addon-owned text and chat alerts by default. MUF detection and secure curing remain active.

Use `/dcralerts move` to reposition the alert-warning anchor.

### Sound notifications

The default sound is **Female Voice - Dispel** on the Master channel. Pressing **Test Sound** confirms only that the selected file and audio channel can play.

Live protected-aura sounds work differently in WoW 12.1:

- Blizzard requires an exact public Spell ID before combat.
- The native sound fires when the aura is first added.
- Stack increases or refreshes of the same continuing aura are intentionally silent.
- A fully removed aura should play again if it is later reapplied.
- An unknown protected aura may remain visual-only until its verified Spell ID is added to the Dispel Database.
- Blizzard-native sounds can overlap when several party members receive an aura at once. The configurable two-second debounce applies only to addon-owned public fallback alerts.

If **Test Sound** works but live alerts do not, run `/zdsound` and include its output in your report.

## Cooldown feedback

After a successful cleanse, the clicked MUF clears immediately. Other MUFs that still need the same cure priority can show a dark cooldown overlay and optional countdown until the spell is ready again.

Cooldown visibility, opacity, numbers, and secondary-affliction borders can be configured separately for each environment.

## Profiles and environments

Named profiles and environment profiles are separate systems:

- **Named profiles** store your overall Decursive configuration and support create, copy, reset, delete, import, and export.
- **Environment profiles** automatically tune range, cooldown, text-alert, chat-alert, and secondary-affliction behavior for the current activity.

Automatic mode recognizes:

- Open World
- Dungeon and Follower Dungeon
- Mythic+
- Raid
- PvP

You can keep automatic detection or lock Decursive to one environment from **Profiles**.

## Settings guide

| Page | What it controls |
| --- | --- |
| **Overview** | Current profile, environment, runtime status, and shortcuts |
| **MUFs** | Visibility, movement, order, size, spacing, grid, border, tooltip, and status light |
| **Cure** | Cure assignments and essential click behavior |
| **Alerts** | Text, sound, channel, debounce, range, and cooldown feedback |
| **Profiles** | Named profiles, automatic environments, import, and export |
| **All Settings** | Complete legacy-compatible settings catalog, lists, custom spells, filters, colors, and database tools |
| **Advanced** | Diagnostics, runtime health, compatibility status, and support tools |

Use the search box at the top of the settings window to find controls across the modern pages and complete settings catalog.

## Priority and Skip Lists

The **Priority List** moves selected players earlier in Decursive's cure order.
Choose **MUFs > MUF order > Decursive priority** if you also want that priority
sequence to control the visible MUF arrangement. The default **Group / roster**
choice instead matches Blizzard's party or raid roster; **DandersFrames** mirrors
that addon's visible order when it is installed.

The **Skip List** excludes selected players from normal curing consideration.

Both lists can be managed from **All Settings > Priority & Skip** or with slash commands.

## Optional battle resurrection

When **Battle rez on dead allies** is enabled, clicking a dead ally's MUF tries a known class battle-resurrection spell first. If no class battle rez is available, it can fall back to the Midnight Engineering **Emergency Soul Link** item when usable.

Soulstone is not used because it is a pre-placement effect. Combat-resurrection charges remain governed by WoW.

Use `/dcrsoullink` to toggle this feature.

## Slash commands

### Settings and windows

| Command | Action |
| --- | --- |
| `/decursive`, `/dcr`, `/zd`, `/zdecursive` | Open the settings window |
| `/dcrshow` | Show the main Decursive bar |
| `/dcrhide` | Hide the main Decursive bar |
| `/dcrreset` | Reset Decursive window positions |
| `/dcrshoworder` | Print the current cure order |

### Priority and Skip Lists

| Command | Action |
| --- | --- |
| `/dcrpradd` | Add the current target to the Priority List |
| `/dcrprclear` | Clear the Priority List |
| `/dcrprshow` | Show or hide the Priority List window |
| `/dcrskadd` | Add the current target to the Skip List |
| `/dcrskclear` | Clear the Skip List |
| `/dcrskshow` | Show or hide the Skip List window |

### Diagnostics and advanced controls

| Command | Action |
| --- | --- |
| `/dcrstatus` | Print the current WoW 12.1 provider and compatibility status |
| `/dcrdiag` | Run Decursive's self-diagnostic |
| `/dcrreport` | Open the full debug report |
| `/zdmuf` | Print MUF cold-start and visibility diagnostics |
| `/zdsound [spellID] [unitToken]` | Inspect live native sound registrations or query one spell/unit pair |
| `/zddb` | Print Dispel Database status |
| `/dcridentity` | Show the current Blizzard-managed tooltip mode |
| `/dcridentity alldebuffs` | Toggle all harmful auras versus dispellable-only tooltip mode; `/reload` required |
| `/dcralerts move` | Move or lock the alert-warning anchor |
| `/dcralertdiag [count\|clear]` | Print or clear recent alert diagnostic decisions |
| `/dcrsoullink` | Toggle battle-rez behavior on dead allies |

## Troubleshooting

### MUFs are missing after logging in

1. Confirm both `Decursive` and `Decursive_Options` are enabled.
2. Open `/dcr` and confirm **MUFs > Show MUFs** is enabled.
3. Run `/zdmuf` **before** using `/reload` so the original cold-start state is preserved in the report.
4. Save the output, then use `/reload` to recover the frames if needed.

### Test Sound works, but combat sound does not

1. Run `/zdsound`.
2. Confirm the selected sound and output channel under **Alerts**.
3. Determine whether the aura was newly added or only refreshed/stacked.
4. If possible, collect the aura's public Spell ID.
5. Report the diagnostic output, Spell ID, dungeon or encounter, class/spec, and whether the aura had fully disappeared before it returned.

### A setting does not change during combat

WoW protects secure frames, bindings, native aura registrations, and some layout changes during combat. Leave combat and allow the queued update to apply. Use `/reload` only if the setting explicitly requests it.

### The settings window does not open

Confirm `Decursive_Options` is installed beside `Decursive` and enabled. It is a LoadOnDemand companion; `/dcr` loads it when needed.

### Lua errors or strange behavior

Run `/dcrdiag`, then `/dcrreport`. Include the complete report and any BugSack or BugGrabber stack trace when filing an issue.

## Reporting bugs

Report problems through [GitHub Issues](https://github.com/randylorfing/Decursive/issues) or email `randylorfing@gmail.com`.

Please include:

- Zhaohu's Decursive version
- WoW version and build
- Character class and specialization
- Activity type: Open World, Dungeon, Mythic+, Raid, or PvP
- Exact steps that triggered the problem
- Whether the problem occurred before, during, or after combat
- Output from `/dcrdiag` and `/dcrreport`
- `/zdmuf` output for missing MUFs, captured before `/reload`
- `/zdsound` output for live sound problems
- Any unusual behavior you noticed, even if it did not produce a Lua error

## WoW 12.1 protected-aura design

Modern WoW restricts aura identities and several UI operations during combat. Zhaohu's Decursive works within those restrictions:

- Blizzard owns live protected aura detection and presentation.
- Decursive does not read protected aura names, durations, stacks, or dispel types back into Lua logic.
- MUF clicks use Blizzard's secure action system.
- Native aura-sound registrations use public Spell IDs and are changed only when Blizzard permits it.
- Unsafe legacy aura and combat-log paths fail closed on WoW 12.1.

## Credits

- **Patrick Bohnet (Quu)** created the original Decursive v1.9.4.
- **John Wellesz** took over Decursive after its first year and maintained and developed it from 2006 through 2026.
- **Randy Lorfing** maintains Zhaohu's Decursive and its WoW 12.1 compatibility, protected-aura runtime, settings interface, alerts, profiles, and related systems.
- Thanks to Decursive's translators, testers, contributors, and the players who provide detailed combat reports.

The complete contributor history remains available in the addon's in-game **About** page.

## License

Zhaohu's Decursive is free software licensed under the [GNU General Public License version 3 or later](LICENSE.txt).

Copyright notices and authorship are preserved in the source files as required by the GPL.
