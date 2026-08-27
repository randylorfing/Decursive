# Decursive — Release Process & Agent Handoff

Everything that must be verified before committing, tagging, or publishing a
release of Zhaohu's Decursive, including the GPL obligations inherited from
John Wellesz and the packager traps that have shipped broken builds three times.

    Repo         randylorfing/Decursive
    Branch       master
    License      GNU GPL v3
    CurseForge   project 1659159
    Written at   v12.0.7

Where this document and the repository disagree, the repository wins. Re-verify
against `.pkgmeta`, the workflow file, and the `.toc` files before relying on
any specific number here.


--------------------------------------------------------------------------------
## 1. GROUND RULES

These override convenience. Every one exists because breaking it cost a release.

**Never publish without verifying the published artifact.**
A green CI check is not proof. v11.0.46, v12.0.4 and v12.0.5 all passed CI,
uploaded successfully, and shipped a Lua file that would not parse in game. The
only reliable test is to download the release zip and inspect it (section 9).

**The maintainer's zip is source of truth.**
When they hand over offline work, do not apply independent bugfixes on top of
it. If something looks wrong, flag it and ask. Their build has usually been
verified in game; yours has not.

**Never force-push `master`. Never rewrite published tags.**
Released commits are immutable. Fix forward with a new version.

**No `Co-Authored-By: Claude` trailer** in commit messages, in this or any repo.

**Do not disable or remove existing functionality while debugging** without
asking first.

**Published version numbers are spent.**
If an offline drop is labelled with a version already released, renumber it
forward and say so explicitly.

**`luacheck` cannot catch packaging corruption.**
The repository source is valid Lua; the damage is introduced *during* packaging.
A clean lint tells you nothing about whether the shipped file parses.


--------------------------------------------------------------------------------
## 2. REPOSITORY GEOGRAPHY

One repository, two addon folders, packaged into one zip — the same layout
DeadlyBossMods uses.

    Decursive/              Core addon. Always loaded. Combat path, MUFs, detection.
    Decursive_Options/      LoadOnDemand companion. Settings UI, option tree,
                            Test Mode. RequiredDeps: Decursive
    .pkgmeta                Packaging contract. Repo ROOT, not inside an addon folder.
    .github/workflows/      Single workflow: lint -> validate -> package -> verify
    Decursive/Libs/         Vendored libraries, committed to git. NOT externals.

### Load order matters

`Decursive.toc` defines load order and several bugs have come from ignoring it:

    line  67    Dcr_opt.lua
    line  94    Dcr_12_1.lua
    line 104    Modern\ZD_Core.lua

A file may only reference something an earlier file defined. Example of a real
bug: `Dcr_DebuffsFrame.lua` loads before `Dcr_12_1.lua`, so calling
`D:Is121MUFStatusLightEnabled()` from it was unreliable at first login.

### Known live defect — do not "fix" silently

The per-environment defaults table exists in THREE copies — `Dcr_opt.lua`,
`Dcr_12_1.lua`, and `Modern/ZD_Core.lua` — and they disagree. A fresh profile and
a "reset to defaults" click can produce different PvP values. This is known and
deliberately deferred by the maintainer. Do not fold a fix for it into an
unrelated change.


--------------------------------------------------------------------------------
## 3. LICENSING & ATTRIBUTION  (the John Wellesz obligations)

Decursive is GPL v3 and descends from work that is not the current maintainer's.
The attribution chain is a licence obligation, not a courtesy.

### The chain

1. **Patrick Bohnet ("Quu")** wrote the original *Decursive v1.9.4*, released
   into the public domain.
2. **John Wellesz** took over after its first year and maintained it for nearly
   twenty years, 2006–2025. He holds copyright on the bulk of the codebase.
3. **Randy Lorfing** maintains this fork — WoW 12.1 compatibility and ongoing
   development, 2026 onward.

### HARD RULE

**Never strip or replace John Wellesz's copyright line.** Under GPL v3 the
notices must be preserved on every file derived from his work. Adding the fork's
maintenance line is correct; removing his is not permitted.

### Three header forms

Every `.lua` and `.xml` file outside `Libs/` carries a GPL v3 notice in one of
these forms. Match the form to the file's provenance.

**Form A — Wellesz-lineage file modified in this fork**

    --[[
        This file is part of Decursive.

        Decursive (v 11.0.10) add-on for World of Warcraft UI
        Copyright (C) 2006-2026 John Wellesz (Decursive AT 2072productions.com) ( http://www.2072productions.com/to/decursive.php )
        WoW 12.1 compatibility and ongoing maintenance, Copyright (C) 2026 Randy Lorfing

        Decursive is free software: you can redistribute it and/or modify
        it under the terms of the GNU General Public License as published by
        the Free Software Foundation, either version 3 of the License, or
        (at your option) any later version.

        Decursive is distributed in the hope that it will be useful,
        but WITHOUT ANY WARRANTY; without even the implied warranty of
        MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
        GNU General Public License for more details.

        You should have received a copy of the GNU General Public License
        along with Decursive.  If not, see <https://www.gnu.org/licenses/>.


        Decursive is inspired from the original "Decursive v1.9.4" by Patrick Bohnet (Quu).
        The original "Decursive 1.9.4" is in public domain ( www.quutar.com )

        Decursive is distributed in the hope that it will be useful,
        but WITHOUT ANY WARRANTY.

        This file was last updated on <ISO timestamp>
    --]]

Note: the "last updated" stamp is a dormant legacy field. It has not been bumped
by any commit in this fork. Do not start maintaining it without being asked.

**Form B — file written solely for this fork**

    --[[
        This file is part of Decursive.

        Zhaohu's Decursive v11 core module. This file was solely written by
        Randy Lorfing.
        Copyright (C) 2026 Randy Lorfing

        ... same GPL v3 paragraphs as Form A ...
    --]]

**Form C — XML files**

Identical text, wrapped in an XML comment inside the `<Ui>` element rather than a
Lua block comment.

### Audit commands

    # Every non-Libs source file must carry a GPL notice
    find Decursive Decursive_Options -type f \( -name '*.lua' -o -name '*.xml' \) \
      -not -path '*/Libs/*' | while read -r f; do
        head -30 "$f" | grep -q "GNU General Public License" || echo "MISSING: $f"
    done

    # Every Wellesz-lineage file must also carry the fork maintenance line
    comm -23 \
      <(grep -rln "John Wellesz" Decursive Decursive_Options --include=*.lua --include=*.xml | grep -v "/Libs/" | sort) \
      <(grep -rln "ongoing maintenance, Copyright (C) 2026 Randy Lorfing" Decursive Decursive_Options --include=*.lua --include=*.xml | grep -v "/Libs/" | sort)

### Also

- Both `.toc` files declare `## X-License: GNU GPL V3`.
- `LICENSE.txt` is GENERATED into the package by the packager via
  `license-output`. It is not committed at the repo root.
- Third-party code under `Libs/` keeps its own upstream licence; out of scope.
- Two files (`Decursive/embeds.xml`, `Decursive/Localization/load.xml`) omit the
  Quu provenance paragraph that the other 30 Wellesz-lineage files carry. Both
  have the full GPL notice and both copyrights, so this is a cosmetic
  inconsistency, not a licence defect. Pre-existing.


--------------------------------------------------------------------------------
## 4. RECEIVING AN OFFLINE ZIP

The maintainer frequently hands over work built outside the repo. These arrive as
PACKAGED BUILDS, not source. Committing one verbatim breaks the packager and can
silently revert recent work.

- [ ] **Extract to a scratch directory.** Never overwrite the repo before
      comparing.

- [ ] **Diff with `--strip-trailing-cr` and filter token noise.** Raw `diff`
      reports thousands of false lines: zips often ship LF where the repo is
      CRLF, and sometimes mixed endings inside one file. A change that looks like
      4,294 lines is usually 54.

- [ ] **Confirm it builds ON TOP of current state, not a diverged base.** Grep
      for distinctive markers from the last few releases. A "changed-files-only"
      zip built from a stale base silently reverts work.

- [ ] **Restore packager tokens** before committing (section 5).

- [ ] **Verify licence headers unchanged** in every modified file (first 30 lines).

- [ ] **Verify packaging-critical `.toc` fields survive:**
      `X-Curse-Project-ID`, `X-License`, `## Version:`, `## Interface:`.

- [ ] **For full-addon zips, list files present in the repo but absent from the
      zip** before any clean replace, so nothing is deleted silently.

- [ ] **Check claims against reality.** Release notes have described work that
      was not in the zip — one claimed CI validation had been added when no
      workflow file was included and no such step existed.


--------------------------------------------------------------------------------
## 5. PACKAGER TOKENS

The packager substitutes some tokens at build time and leaves others alone.
Getting this backwards either breaks versioning or deletes source.

    TOKEN                        COUNT      HANDLING
    @project-version@            55         RESTORE before committing
    @project-date-iso@           4          RESTORE before committing
    --@debug@ / --@end-debug@    0          MUST STAY ABSENT (section 10)
    @no-lib-strip@               2 pairs    Leave untouched, not substituted here
    @project-abbreviated-hash@   1          Leave untouched, not substituted here

### Restoring after an offline drop

Substitute only in `.lua`, `.xml`, `.toc`. Never blanket-replace in `.md`, where
the version number appears legitimately in changelog headings.

**Four occurrences of the version string are DELIBERATE LITERALS and must
survive:**

1. the `## vX.Y.Z` changelog heading
2. `## X-Zhaohu-12.1-Patch:` in the TOC
3. the release-notes title
4. a dated code comment in `Dcr_12_1.lua`

Restore tokens by matching each line's exact shape, then confirm the counts
return to baseline:

    grep -rho "@project-version@\|@project-date-iso@" Decursive Decursive_Options | sort | uniq -c
    #   4 @project-date-iso@
    #  55 @project-version@


--------------------------------------------------------------------------------
## 6. THE .pkgmeta CONTRACT

Every directive was set deliberately, and three were set in response to a broken
release. Do not "tidy" this file.

    package-as: Decursive

    move-folders:
        Decursive/Decursive: Decursive
        Decursive/Decursive_Options: Decursive_Options

    ignore:
        - Decursive/Libs/LibStub/tests
        - Decursive/branding

    optional-dependencies:
        - bug-grabber

    enable-nolib-creation: yes

    license-output: LICENSE.txt

### Why each line is load-bearing

**The self-referencing `move-folders` entry.**
`Decursive/Decursive: Decursive` looks redundant and is not. The packager stages
everything one level under `package-as`, so without this entry the output is
`Decursive/Decursive/Decursive.toc` and the addon does not load at all. DBM
carries the identical `DBM-Core/DBM-Core: DBM-Core` entry for the same reason.

**There is no `externals:` block, on purpose.**
Every library is committed under `Decursive/Libs/`. Re-adding externals re-fetches
the same paths at build time, and the duplicate collides with the self-referencing
move — `mv` cannot merge a directory onto an existing same-named directory,
producing a hard `Directory not empty` failure.

**There is no `manual-changelog:`, on purpose.**
The packager resolves the changelog path ONCE, before `move-folders` runs, and
never refreshes it. After the self-referencing move the cached path no longer
exists, which produced an empty changelog, a malformed CurseForge payload
(`Missing field metadata`), and a failed GitHub release. DBM does not use it either.

**`ignore:` paths resolve from the REPO ROOT.**
They are plain shell globs matched against the path as the packager prints it —
`Decursive/branding/decursive-logo.jpg` — so they need the `Decursive/` prefix. An
unprefixed `branding` matched nothing and shipped a 612 KB unused logo in every
release through v12.0.4, roughly 30% of the download. After changing an ignore
rule, confirm the build log says `Ignoring:` and not `Copying:`.

**`enable-nolib-creation` currently produces nothing.**
The packager only builds a nolib archive when its internal exclude list is
non-empty, and that list is populated ONLY while processing an `externals` block.
With all libraries committed there is nothing to strip. Left enabled in case
externals ever return. DO NOT re-add externals to make this emit a file — that
reintroduces the collision above.


--------------------------------------------------------------------------------
## 7. CI PIPELINE

One workflow: `.github/workflows/build-package-and-upload.yml`. It fires on
pushes to `master` and on ANY tag — nothing else.

**Consequence:** feature branches do not build. There is no way to smoke-test a
package from a branch without either pushing to `master` or cutting a tag. Push
to `master` first and let that build go green before tagging.

    STEP                                        PURPOSE
    Run luacheck                                Lints source. Cannot see packaging
                                                corruption.
    Check for packager-rewritable debug markers GATE. Fails the job BEFORE
                                                packaging if any --@debug@ /
                                                --@end-debug@ marker exists, or a
                                                duplicated delimiter is committed.
    Package retail                              Builds and, on tags, uploads to
                                                CurseForge + creates the GitHub
                                                release.
    Verify packaged output                      Backstop. Greps .release for
                                                duplicated delimiters.

**Ordering is deliberate.** The marker gate runs BEFORE the packager. On tag
builds the CurseForge upload happens INSIDE the packager step, so a check placed
after it would only report the problem once the broken file was already
published — which is exactly how three broken releases escaped.

### Reading the log

`CurseForge ID: 1659159 [token set]` is the proof an upload was actually
attempted. Its ABSENCE — with no error alongside it — means the packager never
recognised the project, which is a `.pkgmeta` or TOC fault, not a credentials
problem. That silent absence is how two releases uploaded nothing at all.


--------------------------------------------------------------------------------
## 8. RELEASE PROCEDURE

Ordered, and the order is the point. Each step catches something the previous
step cannot.

**1. Confirm the maintainer has tested in game.**
Do not tag on your own initiative. If they direct you to publish without testing,
state the risk once, then proceed — it is their call.

**2. Audit the working tree.**
Licence headers intact, packager tokens restored to 55 / 4, no stray build
artifacts staged, `.toc` fields present.

**3. Commit.**
Explain WHY, not just what — root cause, mechanism, and what was verified. No
`Co-Authored-By` trailer.

**4. Push to `master` and wait for green.**
This is the free rehearsal: it runs luacheck and the marker gate without creating
anything that has to be cleaned up. Runs can take several minutes to appear in
the queue; a missing run is usually latency, not failure.

**5. Update the maintainer's AddOns folder.**
Build from committed state, substitute tokens, apply the `ignore` rules, then
verify every file referenced by each `.toc` exists.

    AddOns path:
    C:\Program Files (x86)\World of Warcraft\_retail_\Interface\AddOns

**6. Tag and push.**
Annotated tag, `vX.Y.Z`. Never reuse a published number. The tag message becomes
the human record of the release.

**7. Verify the published artifact.** Mandatory — section 9.

**If it fails:** if the tag build fails BEFORE creating a release, delete the tag
locally and on the remote, fix, and re-cut the same number. If a release was
already created, do not rewrite it — publish a new patch version.


--------------------------------------------------------------------------------
## 9. POST-PUBLISH VERIFICATION  (mandatory)

Download the release zip and inspect it. This is the step that would have caught
all three broken releases.

    gh release download vX.Y.Z --repo randylorfing/Decursive --pattern "*.zip"
    unzip -q Decursive-vX.Y.Z.zip -d ex

- [ ] **Structure:** `ex/Decursive/` and `ex/Decursive_Options/` at top level,
      each `.toc` at depth 2. Anything deeper means the addon will not load.
- [ ] **No duplicated delimiters:** `grep -rn ']==]]==]' ex` returns nothing.
- [ ] **No raw tokens:** `grep -rl '@project-version@\|@project-date-iso@' ex`
      returns nothing.
- [ ] **Ignored paths absent:** `ex/Decursive/branding` does not exist.
- [ ] **`LICENSE.txt` generated** into both addon folders.
- [ ] **CurseForge upload confirmed** in the log: `CurseForge ID: 1659159
      [token set]` followed by `Uploading... Success!`

**Watch out:** counting text with `grep` does not tell you whether that text is
LIVE CODE or sits inside a Lua long comment. When it matters, check the comment
boundaries — find the opener line, the closer line, and confirm the code sits
between them.


--------------------------------------------------------------------------------
## 10. KNOWN FAILURE MODES

Each of these shipped. Recognise the signature rather than rediscovering the cause.

**`unexpected symbol near ']'`**
The packager matches a `--@end-debug@` closer and appends its own `]==]` to a
line already ending in `]==]`, giving `]==]]==]`. Where a long comment was open
the extra bracket becomes bare code and the whole file fails to parse.
*Fix:* remove the markers so the blocks are ordinary inert long comments.
*Important:* the upstream packager bug is NOT fixed. It recurs if markers return
— for instance by updating a vendored library from upstream, since LibQTip ships
these markers by default. The CI gate is what makes that safe.

**Addon absent from the list**
Double-nested package folder. The `package-as` folder needs its own
self-referencing `move-folders` entry.

**`mv: cannot overwrite ...: Directory not empty`**
A git-tracked `Libs/` colliding with an externally fetched one during the
self-referencing move. Remove the `externals` block.

**`Missing field metadata` (HTTP 400) / GitHub release "Problems parsing JSON"**
Stale `manual-changelog` path, resolved before `move-folders` and never
refreshed. Remove the directive.

**No CurseForge line in the log at all**
Not a credentials fault. The packager did not recognise the project — check
`X-Curse-Project-ID` in the TOC and the `.pkgmeta` structure.

**Thousands of diff lines in an offline zip**
Line-ending mismatch, not real change. Re-diff with `--strip-trailing-cr`.

**Package unexpectedly large**
Check images first. Art has repeatedly dominated the download — an unused logo
and two 512x512 icons were once 55% of it. Compare COMPRESSED sizes
(`unzip -v`), not on-disk sizes: a 1 MB TGA may compress to 24 KB while a
600 KB JPEG compresses to 0%.


--------------------------------------------------------------------------------
## 11. OUTSTANDING

**v11.0.46, v12.0.4 and v12.0.5 remain live on CurseForge** and all carry the
unparseable `LibQTip-1.0.lua`. Anyone installing them gets the syntax error.
Hiding or deleting those files requires the CurseForge project's file-management
page and cannot be done from the repository.
