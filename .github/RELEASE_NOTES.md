# Zhaohu's Decursive v13.1.2

Production release for **WoW Retail 12.1**, based on the engine.8 build confirmed
working in-game by the maintainer.

**Upgrade from the older two-folder build:** exit WoW completely. This release
installs into `ZDecursive`. If this project's old `Decursive` and
`Decursive_Options` folders remain after updating through CurseForge, remove
that old copy before launching WoW. Manual installers should remove it before
extracting the release. Keep `WTF` and your settings backups. Legacy
`DecursiveDB` profiles do not automatically migrate; existing **ZDecursive**
settings are retained. Automatic folder cleanup has not been verified.
The rebuild warns outside combat if it detects this project's old addon running
alongside it; the warning does not delete files or change settings.

Changes since v13.1.2-Alpha:

- Redesigned options with clear categories, setting descriptions, search, a frame preview, and distinct editing/applied environment status.
- Carried-bandage discovery and selection, tailoring-rank item tooltips, click assignment, and optional low-stock reminders. Reminders default off and appear outside combat.
- Improved Soul Link fallback and battle-rez warning attribution, native aura tooltips, and cooldown handling. Cooldown numbers remain enabled with overlay darkness at 0 by default.
- **OUT OF RANGE** feedback for confirmed out-of-range dispel attempts. Alert text now fits large font sizes and wraps on narrower screens.
- Out-of-range MUFs default to **50% brightness across the entire frame**, including icons and cooldown numbers. One toggle and brightness slider control both afflicted and unafflicted frames; unknown range stays bright.
- Automatic roster sorting prefers DandersFrames when ready and falls back to group order, while respecting explicitly selected order modes.
- Reduced redundant updates, improved profile/environment recovery, and optional 15- or 30-second performance captures with copyable reports.
- Pet frames consistently use **80% of the configured player-frame size**, matching the original Decursive proportion while retaining party/raid size controls.

Open `/dcr` to review settings. Bandages are under **Supplies**, range brightness
under **Colors > Range**, and the dispel range warning under **Alerts**. Existing
ZDecursive profiles and assignments are retained; the range-default migration updates the
previous shipped 60% value while preserving other customized brightness values.
