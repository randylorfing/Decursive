# Zhaohu's Decursive v11.1.0

## Modern settings redesign

- Rebuilt the standalone settings window with a modern midnight/cyan visual system.
- Added a branded header, live core state, active profile/environment context, improved global search, and clearer action feedback.
- Reorganized navigation into purpose-based groups without removing any settings pages.
- Rebuilt the Dashboard around live session health, context cards, quick actions, and a visible WoW 12.1 safety summary.
- Refined page hierarchy, cards, controls, navigation states, spacing, and the Test Lab.

## DISPEL alert preview fix

- Fixed the menu's **Test DISPEL alert warning** button appearing to do nothing when the live warning was disabled.
- The settings preview now bypasses the live enable gate and debounce, but still uses the selected font, color, and duration.
- Added DISPEL preview actions to both the Dashboard and Test Lab with visible success/failure feedback.
- Timed DISPEL warnings continue to default to 2 seconds.

## WoW 12.1 safety

- The UI rebuild only creates ordinary settings frames and alert text.
- Blizzard-managed AuraContainers remain the source of truth for dispel presence.
- No protected aura details are enumerated or recovered.
- No secure click attributes or managed AuraSlots are changed by the new UI.
- Existing combat-lockdown guards remain in place for MUF and secure configuration changes.
