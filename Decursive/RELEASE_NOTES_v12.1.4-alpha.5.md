# Zhaohu's Decursive v12.1.4-alpha.5

## Profile assignments now match AceDB exactly

- Decursive now uses AceDB's exact display-realm character key while retaining
  its normalized internal identity. A known normalized alias remains safe, and
  unrelated saved profile keys are left alone.
- The profile manager verifies the physically loaded AceDB profile after binding
  and reconciles it with the selected Decursive Profile and Environment Profile.
  The same operation remains safely deferred during combat.
- Saved specialization mappings remain dormant when per-specialization profiles
  are disabled. Settings clearly distinguish active, saved-but-inactive, and
  fallback assignments, and the LibDualSpec compatibility adapter follows the
  same rule.

## Combat startup and MUF recovery are transactional

- Configuration no longer clears secure MUF state when combat prevents it from
  finishing. Decursive reports initialization complete only after secure
  configuration succeeds.
- Leaving combat now applies deferred configuration, cure bindings, MUF sizing,
  ordering, creation, attributes, and layout in a deterministic sequence.
- Delayed MUF creation retains its owning object, missing public-unit MUFs are
  recreated after combat, and protected visibility and mouse changes wait for a
  safe out-of-combat boundary.
- MUF order changes made during combat stay pending and do not update the active
  profile until the layout succeeds. The settings page shows that pending state.
- The Live List starts hidden and follows the selected profile without a startup
  flash.

## MUF size controls follow the edited environment

- Open World and PvP show both Party and Raid size controls.
- Party/Dungeon and Mythic+ show the Party control only.
- Raid shows the Raid control only.
- Changing the edited or previewed Environment Profile refreshes the controls
  immediately. Hidden values remain saved and cannot be modified through hidden
  controls.

## Packaging and validation

- Player packages exclude source release notes, changelogs, and internal project
  documents. The shipped README links to the source-only environment-profile
  guide on GitHub.
- Package validation enforces a closed Markdown allowlist and consistent version,
  interface, schema, and build identity across both addon folders.
- Executable regression coverage now includes combat-startup recovery, final
  secure MUF attributes, profile-key reconciliation, dormant specialization
  assignments, deferred MUF ordering, context-aware MUF controls, and Live List
  startup behavior.

This release does not add new environment-reset controls or a shared-profile
mode. Profile schema 6 and Interface 120100 are unchanged.
