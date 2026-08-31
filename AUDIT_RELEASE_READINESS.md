# Decursive alpha.4 release-readiness audit

Date: 2026-08-31
Scope: profile schema 6, five complete Environment Profiles, ProfileIO input
hardening, priority-color editing, source validation, and a credential-free
offline package rehearsal. No Git index/history, tag, remote, network service,
live SavedVariables, or installed addon was changed by this audit.

## Verdict

**GO for committed alpha.4 rehearsal and copied-SavedVariables in-game testing.**

**NO-GO for publication** until the intended files are committed, branch CI
passes for that exact commit, an exact local `v12.1.4-alpha.4` tag package passes,
and in-game acceptance is complete. The published alpha.3 tag remains immutable.

- P0: 0
- P1: 0
- P2: 2 release-process gates: exact alpha.4 identity and in-game acceptance
- P3: 0

## Resolved findings

Schema-6 startup clears nil, malformed, schema-2, schema-4, and schema-5 data in
place before AceDB initializes, then creates one protected Default profile with
exactly five fresh Environment Profiles. Schema-6 reloads preserve valid
divergent data. A newer schema is detected before defaults, AceDB, callbacks,
events, or configuration and remains byte-for-byte unchanged.

The executable [ProfileIO harness](.github/scripts/test-profile-io.lua) covers
complete and single-environment round trips; byte, string, key, depth, and node
limits; invalid headers; truncation; unmatched markers; multiple roots;
non-table roots; future formats; cyclic/shared decoded graphs; deserializer and
manager failures; and exact rollback. Every rejected input preserves the target
variants. It is required by
[validate-v13.sh](.github/scripts/validate-v13.sh) and documented in the
[test matrix](Decursive/docs/v13/TEST_MATRIX.md).

The 22 previously changed statements with trailing semicolons were corrected
without logic changes.

## Validation evidence

- 14/14 maintained Fengari harnesses: PASS
- Four intentional failure self-tests: PASS with nonzero status
- Source and test parsing: 99 Lua files, PASS
- Runtime source parsing: 85 Lua files, PASS
- Localization: PASS with a 444-key enUS baseline
- Full [validate-v13.sh](.github/scripts/validate-v13.sh): PASS
- `git diff --check`: PASS; line-ending warnings only
- Changed-line Lua semicolon gate: PASS, zero code matches
- Published alpha.3 changelog section: unchanged from the tag
- Workflow, action pins, vendored libraries, and dependencies: unchanged

## Offline Stage A package rehearsal

The existing BigWigs packager checkout was verified at
`36b4c3b7b7bd17c835ad8c83fed4976c067edfbe` and run with upload, externals, and
ZIP creation disabled. Output: `.release-alpha4-stage-a`.

- Package validator: PASS
- Packaged Lua: 85/85 parsed
- Core: 134 files; Options: 16 files; total: 150
- Sorted tree SHA-256:
  `5cc881a0988547df3a4544c67c32e67e34abe0b2fd3fb2f111c27f026680da8b`
- Both generated licenses exactly match repository `LICENSE`
- No unresolved tokens, source-only leaks, malformed delimiters, missing TOC
  references, or case-insensitive collisions

The rehearsal still identifies as alpha.3 because no Git mutation was
authorized. The new alpha.4 release note is absent because the packager excludes
untracked files. After named-path staging and commit, the exact local alpha.4
tag rehearsal must identify as alpha.4 and is expected to contain 135 core files
plus 16 options files.

## Remaining gates

1. Stage only reviewed paths, commit on `alpha`, push, and require branch CI for
   the exact commit SHA.
2. Create a local annotated alpha.4 tag and repeat all package gates before
   pushing it.
3. Test the reset against copied SavedVariables, configure divergent values in
   all five environments, reload and restart twice, and exercise environment and
   specialization changes, secure clicks, native priority colors, cooldowns,
   and combat deferral.
4. Push the tag only after separate publication approval, then download and
   independently validate the GitHub artifact and confirm CurseForge success.

See [Full Environment Profiles](Decursive/FULL_ENVIRONMENT_PROFILES.md), the
[test matrix](Decursive/docs/v13/TEST_MATRIX.md), and the
[alpha.4 changelog](Decursive/CHANGELOG.md).
