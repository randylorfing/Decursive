# Zhaohu's Decursive v11.1.2

## Combat DISPEL alert hotfix

- Fixed the v11.1.1 regression where **DISPEL** appeared in the settings preview but could be missing during combat.
- The addon-owned warning banner is now created before combat.
- A live Blizzard-managed AuraSlot transition queues banner presentation for the next frame, after the managed callback has fully unwound.
- Visual alerts are requested even when dispel audio is disabled or suppressed by its debounce.
- Timed mode still uses one fixed-duration pulse. Additional managed refreshes or sound callbacks cannot restart or extend the selected 2- or 3-second duration.
- **Until cleared** continues to follow Blizzard's managed parent visibility.

## WoW 12.1 safety

- No protected aura details are read or enumerated.
- No managed AuraSlot visibility query is used.
- No secret values are compared or used as table keys.
- No secure click attributes or managed AuraSlot geometry are changed.
- Timed mode does not write to Blizzard-parented alert text during live combat.
