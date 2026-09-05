> **Current rebuild: v13.1.2 — ZDecursive for Retail 12.1.**
>
> The maintained rebuild uses **one addon folder, `ZDecursive`**, and its source
> and current user guide are on the [`zdecursive` branch](https://github.com/randylorfing/Decursive/tree/zdecursive).
> Check [Releases](https://github.com/randylorfing/Decursive/releases) for available packaged downloads.
>
> **The `master` branch and the guide below describe the legacy two-folder addon.**
> For the rebuild, follow the [current installation guide](https://github.com/randylorfing/Decursive/blob/zdecursive/README.md),
> not the legacy instructions below. Install the packaged `ZDecursive` folder
> into Retail `Interface/AddOns` and disable the older `Decursive` and
> `Decursive_Options` addons before enabling the rebuild.
>
> Keep a backup of your existing settings when upgrading. The rebuild stores its
> settings in `DecursiveRebuildDB`; it does not import the legacy `DecursiveDB`.
> Existing rebuild users retain their rebuild profiles and assignments.

---

# Zhaohu's Decursive — User Guide

A fast dispel addon for **World of Warcraft Retail 12.1**. It shows your group as a
compact grid of squares that light up when someone has something you can remove,
and you cure them by clicking. No target swapping, no scanning nameplates.

- **Project:** https://github.com/randylorfing/Decursive
- **Requires:** WoW Retail 12.1 (interface `120100`)
- **License:** [GNU GPL version 3 or later](LICENSE)

---

## Installation

**Install both folders.** They are shipped together in one download:

| Folder | What it does |
|---|---|
| `Decursive` | The combat core. Always loaded. Draws the squares, does the curing. |
| `Decursive_Options` | The settings interface. Loads only when you open settings. |

Copy both into `World of Warcraft\_retail_\Interface\AddOns\`, then restart the
game (a `/reload` is enough if WoW was already running).

If `Decursive_Options` is missing, the addon still works — you just can't open
settings. Decursive will say so in chat.

---

## Quick start

1. **Log in on a character that can dispel.** Decursive configures itself from the
   spells you actually have. On a class with no friendly dispel it will tell you so
   and stay quiet.
2. **Find the grid.** A block of small squares appears — one square per group
   member. Solo, that's a single square: you.
3. **Move it.** Drag it where you want. `/dcrreset` puts it back if it ends up
   off-screen.
4. **Wait for a square to light up.** The colour tells you *what kind* of effect it
   is — Magic, Curse, Poison, Disease, and so on.
5. **Click it.** Left click casts your best cure for that effect on that person.

That's the whole loop. Everything below is refinement.

---

## Reading the squares

Each square is one group member, and it's the primary display — you don't need
their unit frame.

| What you see | What it means |
|---|---|
| Plain / dim square | Nothing to cure |
| Coloured square | Has a curable effect; the colour is the effect type |
| Yellow tint | Out of range for your cure |
| Dimmed with a countdown | Your cure is on cooldown |
| Border highlight | A second, lower-priority effect is also present |
| Raid target icon | Marked target, shown on the square |

Hover a square to see who it is and what's on them.

**Status light** — an extra indicator above each square showing whether a cure
actually landed. It is **off by default** because it makes each row taller. Turn it
on under **MUFs** if you want it; spacing returns to normal when you turn it off.

---

## Curing

Clicking a square casts a cure. Which cure depends on which mouse button you use,
and that mapping is fully configurable under **Cure**.

By default the buttons run down your cure priority list — left click for the
highest-priority effect present, right click for the next, and modifier
combinations (`Ctrl`, `Shift`, `Alt`) plus mouse buttons 3–5 for the rest.

**Two bindings are reserved:** the last two entries in the list always target and
focus the unit instead of curing it, so you can grab someone from the grid.

### Cure order

When someone has more than one curable effect, Decursive picks by priority. The
default order is:

1. Magic
2. Curse
3. Poison
4. Disease
5. Enemy Magic
6. Charm
7. Bleed

Reorder it under **Cure**. `/dcrshoworder` prints the current order in chat, which
is the fastest way to confirm what a click will actually cast.

Effects you can't remove never light up — the list adapts to your class and spec,
and re-checks when you change specialization.

---

## Opening settings

Any of these open the settings window:

```
/dcr
/decursive
/zd
```

It also opens from **Game Menu → Options → AddOns → Zhaohu's Decursive**, and from
the minimap button if you use one.

The window has seven pages:

| Page | Use it for |
|---|---|
| **Overview** | Current state at a glance — profile, detection, environment |
| **MUFs** | Size, spacing, layout, borders, status light |
| **Cure** | Cure order and click bindings |
| **Alerts** | On-screen warning text, sounds |
| **Profiles** | Saved configurations and per-environment behavior |
| **Advanced** | Diagnostics and edge-case options |
| **All Settings** | Every option in one searchable list |

If you can't find something on a focused page, it's in **All Settings**.

> Most settings can't be changed during combat — WoW blocks reconfiguring the
> click-to-cure buttons mid-fight. Decursive queues the change and applies it when
> you drop combat.

---

## Environment profiles

Decursive adjusts its behavior to the content you're in, detected automatically
from the **instance type** — not your group size.

| Where you are | Profile |
|---|---|
| Raid instance | **Raid** |
| Dungeon (Normal, Heroic, Mythic 0, Follower) | **Dungeon** |
| Dungeon with an active keystone | **Mythic+** |
| Battleground or arena | **PvP** |
| Anywhere else, including a party in the open world | **Open World** |

Each profile has its own out-of-range dimming, cooldown overlay opacity and alert
behavior. Adjust them under **Profiles**, or pin one environment permanently
instead of auto-detecting.

> A five-player group questing in the open world counts as **Open World**, not
> Dungeon. The profile follows the instance, not the party.

---

## Alerts

### On-screen warning

When something dispellable appears, Decursive can flash **DISPEL** in the middle of
your screen. It is **on by default** and hides after **2 seconds**.

- Switch it to stay visible until cleared, change the duration, font size or colour
  under **Alerts**.
- Reposition it with `/dcralerts move`, drag it, then run the command again to lock.

**PvP suppresses all on-screen text by default.** In battlegrounds and arenas the
DISPEL and Soul Link text stay hidden so they don't cover what you're watching —
sounds and the squares still work normally. Turn it back on with the **PvP
on-screen text alerts** switch under **Profiles**.

### Sound

A sound plays when a dispellable effect appears. On by default, through the
**Master** channel, with a selectable alert sound under **Alerts**.

Sound registration happens **out of combat** — WoW forbids changing it mid-fight.
Whatever was registered when the fight started keeps working throughout, so
changing sound settings during a pull applies when combat ends.

---

## Priority and skip lists

**Priority list** — people you always want cured first, regardless of the normal
order. Useful for the tank, or a healer who's about to die.

```
/dcrpradd      add your current target
/dcrprshow     show the list
/dcrprclear    empty it
```

**Skip list** — people to ignore entirely.

```
/dcrskadd      add your current target
/dcrskshow     show the list
/dcrskclear    empty it
```

You can also tell Decursive to ignore **specific debuffs**, optionally per class,
under **All Settings** — handy for effects that are harmless or that you're
supposed to leave on.

---

## Command reference

**Everyday**

| Command | Does |
|---|---|
| `/dcr`, `/decursive`, `/zd` | Open settings |
| `/dcrshow` | Show the squares |
| `/dcrhide` | Hide the squares |
| `/dcrreset` | Reset the window position |
| `/dcrshoworder` | Print the current cure order |
| `/dcralerts move` | Unlock the alert text for dragging |

**Lists**

| Command | Does |
|---|---|
| `/dcrpradd`, `/dcrprshow`, `/dcrprclear` | Priority list |
| `/dcrskadd`, `/dcrskshow`, `/dcrskclear` | Skip list |

**Diagnostics** — for troubleshooting or a bug report

| Command | Does |
|---|---|
| `/dcrstatus` | 12.1 compatibility status |
| `/dcrdiag` | Full self-diagnostic |
| `/dcrreport` | Report you can paste into an issue |
| `/zdsound` | Why a sound did or didn't play |
| `/zdmuf` | Square layout state |
| `/zddb` | Dispel database state |
| `/dcrsoullink` | Toggle Soul Link tracking |
| `/dcridentity` | Debuff identity tooltip options |

---

## Troubleshooting

**No squares.** You may have no dispel on this spec — `/dcrstatus` will say. If you
do, check the display is enabled under **MUFs**, or run `/dcrshow`.

**Squares vanish in some content.** Check **Auto-hide** under **MUFs**. It can be
set to hide when solo, when not in a raid, or when in a raid. Default is never
hide.

**Clicking does nothing.** Almost always range or cooldown — a yellow tint means out
of range, a countdown means cooldown. Otherwise `/dcrshoworder` confirms what that
button is bound to cast.

**Settings won't open.** `Decursive_Options` isn't installed or is disabled. Both
folders must be present; enable it at character select under AddOns.

**Nothing changes when I drag a slider in combat.** Expected. WoW blocks it; the
change applies when you leave combat.

**Something's broken.** Run `/dcrreport` and include the output in an issue at
https://github.com/randylorfing/Decursive/issues

---

## Credits

Decursive was created by **Patrick Bohnet (Quu)** and released into the public
domain as *Decursive v1.9.4*. **John Wellesz** took it over after its first year and
maintained and developed it from 2006 through 2026. This fork continues that work for
WoW 12.1 and is maintained by **Randy Lorfing**.

Licensed under the [GNU General Public License version 3 or later](LICENSE).

