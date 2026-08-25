# Zhaohu's Decursive — v11.0.43 Release Notes

**WoW Retail 12.1** · August 2026

---

## Highlights

This release focuses on **alert warnings**, **MUF tooltips**, and **layout polish** — fixing regressions introduced while adding timed DISPEL fade and tightening PvP safety.

---

## Alert Warnings

### DISPEL center banner (live + options test)
- **DISPEL** alert warning appears when a Micro Unit Frame lights up with a dispellable affliction (same visual presence as the red square).
- Audio remains owned by Blizzard's `AddAuraSound` engine; the banner is separate from chat/notifications.
- **Duration mode** (Settings → Messages → Alert warnings):
  - **Timed** (default) — hides after configurable seconds (default **3s**)
  - **Until cleared** — stays visible while the dispel condition is active
- **Alert text size** default increased to **48px**; slider range **16–96**.
- **Fix:** Timed-fade work had broken live display by forcing label alpha to `0` every refresh tick. Restored AuraSlot Show/Hide cascade visibility; the timer now hides text only via `OnShow`, not the status-light refresh loop.

### Soul Link alert warning
- Unchanged from prior builds — same draggable anchor (`/dcralerts move`) and shared styling controls.

---

## Micro Unit Frames

### MUF size controls (Settings UI)
- Added **Party** and **Raid** MUF size sliders (10–80 px) under **Micro Unit Frames → Layout & Display**.
- Underlying resize APIs existed but were never wired to the Modern UI.

### Status indicator light toggle
- New option: **Status indicator light** (Settings → Micro Unit Frames → Display).
- **Default: OFF** — when disabled, status lights are hidden and party/raid MUF spacing returns to the original layout (as if status lights were never added).

---

## Debuff Identity Tooltip (Dungeon / Raid)

### Native debuff tooltip
- **Fix:** Identity `AuraContainer` now receives `SetUnit`, `SetEnabled`, `Show`, and `UpdateAllAuras` so Blizzard's built-in debuff tooltip activates on hover.
- Unit retargeting refreshes the identity container.

### Unit name label on hover
- Restored the original behavior in dungeon/raid:
  - **Class-colored name** (with raid marker icon) anchored above/below the MUF
  - **Native Blizzard tooltip** shows debuff identity on the side
- Replaces the generic affliction tooltip body when the identity slot is active (avoids duplicate/conflicting tooltips).

### PvP / Arena
- Debuff identity tooltip (native slot + cast-inference fallback) is **fully disabled** in PvP and arena to avoid conflicts with priority-color rendering.

---

## Options & UI

### Priority & Skip list
- Reorder button labels fixed: mojibake arrows replaced with plain **Up / Dn / Top / End / X**.

---

## Profiles (unchanged architecture)

AceDB **user profiles** (Default, Healer, custom names) and **environment behavior blocks** (Open World, Dungeon, Mythic+, Raid, PvP) remain fully supported:

- **Settings → Profiles & Modes** — switch/create/copy/reset user profiles; set environment mode
- **Settings → Import / Export** — share the active user profile
- Classic options still expose AceDB profile controls under General

---

## Files Touched (main)

| Area | Files |
|------|--------|
| DISPEL alerts | `Dcr_12_1.lua`, `Decursive.lua`, `Dcr_opt.lua` |
| Tooltips / identity | `Dcr_12_1_DebuffIdentity.lua` |
| MUF layout / status light | `Dcr_DebuffsFrame.lua` |
| Options UI | `Decursive_Options/Dcr_opt_tree.lua`, `Decursive_Options/Modern/ZD_UI.lua` |

---

## Upgrade Notes

1. `/reload` after updating.
2. Confirm **DISPEL alert warning** is enabled under **Messages → Alert warnings** if you want the center banner.
3. **Status indicator light** defaults to **off** — enable it in MUF Display settings if you want the per-square range/status dot.
4. Debuff identity tooltip works in **dungeons and raids only**; PvP uses standard affliction tooltips.

---

## Known Limitations

- Live DISPEL text timing relies on AuraSlot Show/Hide cascade + OnShow timer; protected aura reads are intentionally not used in combat.
- PvP native debuff identity remains shelved (correlated with priority-square rendering conflicts in earlier testing).
