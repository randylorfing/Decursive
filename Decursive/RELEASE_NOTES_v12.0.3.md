# Zhaohu's Decursive v12.0.3

The Party and Raid MUF size controls now resize the live Micro Unit Frames through original Decursive's container-scale and placement path.

- **Party MUF size** applies immediately while solo, in the open world, in a dungeon, or in a party.
- **Raid MUF size** applies immediately while in a raid and is otherwise saved for the next raid.
- Changing the active size scales the canonical MUF container and immediately runs Decursive's original `Place()` behavior.
- Size changes no longer schedule an unnecessary full position reset.
- The settings page identifies which size is currently active and no longer shows duplicate size controls.
- The overlapping Frame Basics and MUF Size cards have been separated.
- If a live resize cannot be applied, the settings footer now reports that failure.

This patch does not change configured MUF spacing, raid auto-layout, status-light behavior, secure click casting, protected-aura handling, dispel alerts, or sound behavior.
