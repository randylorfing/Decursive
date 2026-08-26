# Zhaohu's Decursive v11.1.4

This hotfix restores live dispel sound and makes the live **DISPEL** warning match the font size shown in the options preview.

## Fixed

- Re-enabled Blizzard-native `C_UnitAuras.AddAuraSound` registrations after the v11.1.3 protected-text rewrite.
- Guaranteed one native sound-registration pass when Decursive completes initialization.
- Rebuilds native registrations when the sound preset, channel, or enable settings change.
- Falls back to Decursive's normal sound player for a public, known dispellable aura when that unit/spell pair did not register successfully.
- Uses one shared Font object for both preview and live labels.
- Corrects native label scale against `UIParent`, so the combat warning honors the configured font size instead of appearing oversized because of MUF/UI-scale differences.

## WoW 12.1 safety

Live text remains attached through Blizzard's `CustomAuraButton:SetDurationText` / `SetDispelTypeText` APIs. Live sound uses Blizzard's `C_UnitAuras.AddAuraSound` registry for public DispelDB or learned Spell IDs. The addon does not enumerate protected aura details, compare secret values, query protected visibility, or alter secure attributes in combat.

The first occurrence of a previously unknown aura can remain silent if WoW hides its Spell ID. Once a successful dispel exposes a public Spell ID, Decursive learns and registers it for later occurrences.
