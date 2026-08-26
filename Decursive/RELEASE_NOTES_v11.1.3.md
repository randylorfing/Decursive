# Zhaohu's Decursive v11.1.3

## Native live DISPEL alert fix

- Fixed the combat-only failure where the settings preview displayed **DISPEL**, but a real dispellable affliction did not.
- The root cause was Blizzard's protected AuraSlot presentation: addon `OnShow` scripts are not a reliable notification channel for its secret visibility transition.
- Timed mode now uses Blizzard's native `CustomAuraButton:SetDurationText` API with an `ElapsedDuration` color curve.
- **DISPEL** appears when Blizzard assigns the protected dispellable aura and becomes transparent at the exact configured duration (including 2, 2.5, and 3 seconds), without repeated aura updates extending the timer.
- **Until cleared** uses Blizzard's native `SetDispelTypeText` path and follows the managed aura assignment.
- The settings preview remains independent and continues to use the selected size, color, and duration.

## WoW 12.1 safety

- No protected aura details are read or enumerated.
- No `IsShown()` or other managed visibility value is queried.
- No secret value is compared, branched on, formatted by Lua, or used as a table key.
- No managed AuraSlot script is hooked.
- No protected child region is mutated by Decursive during combat.
- No secure click attribute or managed AuraSlot geometry is changed.
