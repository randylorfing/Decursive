# v11 Feature-Parity Matrix

The v10.43 package remains the behavioral reference. In v11, **v11 UI** means the feature is configured entirely inside the new window even when the proven backend implementation is still being reused.

| Feature | Status in 11.0.0 |
|---|---|
| WoW 12.1 Managed AuraContainer detection | Retained / core safety invariant |
| Native provider parity | Direct Blizzard AuraContainer detection, cooldown membership, post-cure verification, and cure-spell range status; same MUF feedback contract as DandersFrames mode |
| Global settings search | Native v11 header search across pages and options |
| Automatic DandersFrames detection provider | Auto-selects DandersFrames when its public provider API is available; otherwise uses Native |
| DandersFrames integration scope | Detection carrier only; no frame/click/layout takeover; Decursive uses one dedicated DandersFrames behavior profile |
| DandersFrames unavailable at startup | Native Blizzard-managed provider is selected automatically |
| Secure Micro Unit Frames | Retained backend + v11 UI |
| All healer/class/spec dispel capability logic | Retained |
| Magic / Poison / Disease / Curse / Charm | v11 UI |
| Bleed/custom handling | v11 UI |
| Left/right/middle mouse bindings | v11 UI |
| Button4/Button5 bindings | v11 UI |
| Ctrl/Shift/Alt modifier bindings | v11 UI |
| Custom spells/items/macros | v11 UI |
| Priority list | Native v11 list editor |
| Skip list | Native v11 list editor |
| Priority/skip move up/down/top/bottom and remove | Native v11 list editor |
| Role/group ordering | v11 UI |
| Player indicator | v11 UI |
| Priority colors and borders | v11 UI |
| MUF show/hide and lock/move | v11 UI |
| MUF sizing/layout/max count | v11 UI |
| Cooldown overlay/numbers/opacity | v11 UI + per-environment controls |
| Secondary-affliction border/pulse | v11 UI + per-environment controls |
| Out-of-range dimming/color | v11 UI |
| Shared same-priority cooldown | v11 UI + per-environment controls |
| Open World behavior | v11 UI |
| Dungeon / Follower behavior | v11 UI |
| Mythic+ behavior | v11 UI |
| Raid behavior | v11 UI |
| PvP behavior | v11 UI |
| Automatic environment detection | v11 UI; paused while DandersFrames provider is active |
| AceDB profiles | v11 UI |
| AceDB profile reset/copy/delete | v11 UI option renderer |
| LibDualSpec | v11 UI option renderer |
| Profile import/export | Native v11 page |
| Affliction filtering/per-class ignores | v11 UI option renderer |
| Live List settings | v11 UI option renderer |
| Message settings | v11 UI option renderer |
| Macro settings/key binding | v11 UI option renderer |
| 12.1 status / selected-MUF visual tests / dispel resolver refresh | v11 UI option renderer |
| Diagnostics | Native v11 page |
| About/version controls | v11 UI option renderer |
| Legacy AceConfig settings window | Removed from user experience |
| `/dcrclassic` | Removed |

## Single-UI rule

A backend implementation may remain temporarily while the ground-up rewrite proceeds, but it may not expose a second settings window. All configuration belongs in the v11 UI.
