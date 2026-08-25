# Zhaohu's Decursive v11 UI Architecture Audit

Alpha 14 reviews every settings surface. The rule is to create dedicated pages or subsections only when they improve discoverability or prevent deep option trees from becoming visually unstable.

| Page | Alpha 14 treatment |
|---|---|
| Dashboard | Keep dedicated; status and quick actions only. |
| General | Keep dedicated/flat; current option count does not justify another navigation layer. |
| Curing | Keep core cure behavior here; move Bleed Management out. |
| Bleed Management | New dedicated page with Discovery & Keywords / Known Bleed Effects subsections. |
| Spells & Bindings | Keep purpose-built native v11 editor. |
| Affliction Filters | Split into Filter Rules / Ignored Afflictions subsections. |
| Priority & Skip | Keep dedicated two-list editor; window minimum width protects the two-column layout. |
| Micro Unit Frames | Split into Layout & Display / Spacing & Opacity / Colors / Performance subsections. |
| Cooldowns | Dedicated cooldown-only page. Range settings removed. |
| Range & Visibility | New dedicated page for range and event-driven line-of-sight feedback. |
| Live List | Keep dedicated/flat. |
| Profiles & Modes | Keep dedicated native v11 editor. |
| Import / Export | Keep dedicated sharing page. |
| Detection | Keep dedicated; native Blizzard-managed provider status only. |
| Messages | Keep dedicated/flat. |
| Macro | Keep dedicated/flat. |
| 12.1 Status | Keep dedicated protected-aura compatibility surface. |
| Diagnostics | Keep dedicated diagnostic actions/status. |
| About | Keep dedicated/flat. |

## Window behavior

- Resizable from 960x650 through 1500x1000.
- Size persists per AceDB user profile.

## Detection boundary

Dispel detection uses Decursive's native Blizzard-managed AuraContainer path only. Decursive owns MUFs, secure curing, cooldowns, range/LoS feedback, priorities, profiles, and environment modes. Unit order comes from Decursive's roster.
