# Zhaohu's Decursive v11.1.1

## Timed DISPEL warning hotfix

- Fixed live **DISPEL** text remaining visible longer than the configured duration.
- Blizzard can briefly refresh the same managed AuraSlot multiple times; those refreshes were repeatedly restarting the warning timer.
- Timed mode now uses one ordinary Decursive-owned banner and one fixed timer.
- Additional AuraSlot or sound events during the configured duration do not extend the warning.
- A short 0.35-second quiet-period check prevents a managed-slot refresh flicker from being treated as a new affliction.
- **Until cleared** remains available and continues to follow Blizzard-managed parent visibility.

## WoW 12.1 safety

- No protected aura details are read or enumerated.
- No `AuraSlot:IsShown()` query is used.
- No secret-value comparison or table key is introduced.
- No secure click attributes or managed AuraSlot geometry are changed.
