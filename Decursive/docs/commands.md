# Zhaohu's Decursive commands

Commands are not case-sensitive.

## Settings and windows

| Command | Action |
| --- | --- |
| `/decursive`, `/dcr`, `/zd`, `/zdecursive` | Open the settings window |
| `/dcrshow` | Show the main Decursive bar |
| `/dcrhide` | Hide the main Decursive bar |
| `/dcrreset` | Reset Decursive window positions |
| `/dcrshoworder` | Show the current cure order |

## Priority and Skip Lists

| Command | Action |
| --- | --- |
| `/dcrpradd` | Add the current target to the Priority List |
| `/dcrprclear` | Clear the Priority List |
| `/dcrprshow` | Show or hide the Priority List window |
| `/dcrskadd` | Add the current target to the Skip List |
| `/dcrskclear` | Clear the Skip List |
| `/dcrskshow` | Show or hide the Skip List window |

## Diagnostics and advanced controls

| Command | Action |
| --- | --- |
| `/dcrstatus` | Show the current WoW 12.1 provider and compatibility status |
| `/dcrdiag` | Run Decursive's self-diagnostic |
| `/dcrreport` | Open the complete copyable debug report |
| `/zdmuf` | Inspect MUF cold-start and visibility state |
| `/zdsound [spellID] [unitToken]` | Inspect native sound registrations or query one spell/unit pair |
| `/zddb` | Show Dispel Database status |
| `/dcridentity` | Show the current Blizzard-managed tooltip mode |
| `/dcridentity alldebuffs` | Toggle all harmful auras versus dispellable-only tooltip mode; reload required |
| `/dcralerts move` | Move or lock the alert-warning anchor |
| `/dcralertdiag [count\|clear]` | Show or clear recent alert diagnostic decisions |
| `/dcrsoullink` | Toggle battle-resurrection behavior on dead allies |

Secure bindings, native aura registrations, and protected frame changes may wait
until combat ends.

See the [user guide](../README.md), [MUF guide](MUFs.md), [macro guide](macro.md),
[user actions](user-actions.md), and [FAQ](faq.md). Report problems through
[GitHub Issues](https://github.com/randylorfing/Decursive/issues).
