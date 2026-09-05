# Decursive — Release Process

Everything that must be verified before committing, tagging, or publishing a
release of Zhaohu's Decursive, including the GPL obligations inherited from
John Wellesz and the packager traps that have shipped broken builds four times.

    Repo         randylorfing/Decursive
    Branch       master
    License      GNU GPL v3
    CurseForge   project 1659159
    Written at   v12.1.3

Where this document and the repository disagree, the repository wins. Re-verify
against `.pkgmeta`, the workflow file, and the `.toc` files before relying on
any specific number here.


--------------------------------------------------------------------------------
## 1. GROUND RULES

These override convenience. Every one exists because breaking it cost a release.

**Never publish without verifying the published artifact.**
A green CI check is not proof. v11.0.46, v12.0.4 and v12.0.5 all passed CI,
uploaded successfully, and shipped a Lua file that would not parse in game.
v12.1.2 then passed all eight automated package checks — including a syntax parse
of 83 Lua files — and still shipped a Windows extraction collision, because the
fault was in two `.md` files. Automation only covers the classes you have already
been burned by. Download the release zip and inspect it (section 9).

**The maintainer's zip is source of truth.**
When they hand over offline work, do not apply independent bugfixes on top of
it. If something looks wrong, flag it and ask. Their build has usually been
verified in game; yours has not.

**Never force-push `master`. Never rewrite published tags.**
Released commits are immutable. Fix forward with a new version.

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
    .github/workflows/      PR/master/tag verification; tag-only publication
    .github/scripts/        Repository, localization, and built-package validators
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
- The complete GPLv3 text is committed as [LICENSE](LICENSE) for GitHub license
  discovery and as [Decursive/LICENSE.txt](Decursive/LICENSE.txt) for the addon.
  The packager copies `LICENSE.txt` into both packaged addon folders through
  `license-output`; the root `LICENSE` is ignored by [.pkgmeta](.pkgmeta).
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
    @project-version@            50         RESTORE before committing
    @project-date-iso@           4          RESTORE before committing
    --@debug@ / --@end-debug@    0          MUST STAY ABSENT (section 10)
    @no-lib-strip@               2 pairs    Leave untouched, not substituted here
    @project-abbreviated-hash@   1          RESTORE before committing

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

    grep -rho "@project-version@\|@project-date-iso@\|@project-abbreviated-hash@" Decursive Decursive_Options | sort | uniq -c
    #   1 @project-abbreviated-hash@
    #   4 @project-date-iso@
    #  50 @project-version@


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
`Decursive/branding/decursive-logo-v2.jpg` — so they need the `Decursive/` prefix. An
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

One workflow: [.github/workflows/build-package-and-upload.yml](.github/workflows/build-package-and-upload.yml).
Its read-only `verify` job runs on pull requests targeting `master`, pushes to
`master`, version tags (`v*`), and manual `workflow_dispatch`. Its write-enabled
`release` job runs only for version tags.

It is split into two jobs, and the split is the whole safety model:

    JOB       CREDENTIALS   WHAT IT DOES
    verify    READ ONLY     full-tree Lua syntax plus maintained-code static
                            checks; debug-marker gate; install ripgrep;
                            validate-v13.sh (repository and localization
                            invariants); packager
                            dry run (args: -d, skip uploading); then
                            validate-package.sh against .release
    release   CF + GitHub   needs: verify. Gated on a pushed version tag.
                            Packages and uploads. The ONLY job holding tokens.

**Why it is split.** On a tag build the CurseForge upload happens *inside* the
packager step. Any check placed after that step reports a fault only once the
broken file is already public — which is exactly how v11.0.46, v12.0.4 and
v12.0.5 escaped. Packaging and validating with no credentials in scope, then
publishing only on success, closes that hole.

**Rehearsal.** Pull requests and `master` pushes verify automatically.
`workflow_dispatch` also runs `verify` only, because `release` requires both a
`push` event and a `v*` tag ref. A manual run therefore lints, packages and
validates but *cannot* publish, even if an existing version tag is selected as
the dispatch ref. Use it before every tag:

    gh workflow run "Check and build addon" --ref master

### The two validators

[.github/scripts/validate-package.sh](.github/scripts/validate-package.sh)
`<assembled-release-directory>` — inspects the BUILT, expanded package directory
(normally `.release`), not the source checkout or a zip archive. It checks
structure, duplicated delimiters, every unsubstituted package token including
the abbreviated hash, a Lua **syntax parse of every packaged file**, TOC
references, both addon licenses, case-insensitive filename collisions, and
source-only files that leaked in.

[.github/scripts/validate-v13.sh](.github/scripts/validate-v13.sh) — repository
invariants: workflow permissions and immutable action pins, the
package-token baseline (50 version / 4 date / 1 hash), TOC authorship and licence
metadata, localization format compatibility and coverage, and v13 architecture
boundaries.

**The repository validator requires Git, Perl, and ripgrep.** Git for Windows
includes Git and Perl; install ripgrep separately. The script now fails fast if
one is unavailable instead of inverting checks and reporting false failures.
The workflow installs ripgrep explicitly on `ubuntu-latest`.

On Windows, run the shell commands from **Git Bash**. The validators locate the
repository from their own script paths, tolerate CRLF TOC metadata, and
normalize drive-letter or backslash paths passed to the package validator.

### Reading the log

`CurseForge ID: 1659159 [token set]` followed by `Uploading ... Success!` is the
proof the file reached CurseForge. That `Success!` is CurseForge's own API
response, printed separately from the GitHub one.

Its ABSENCE — with no error alongside it — means the packager never recognised
the project, which is a `.pkgmeta` or TOC fault, not a credentials problem. That
silent absence is how two releases uploaded nothing at all.

The packager reads `CF_API_KEY` **or** `CF_API_TOKEN`, and `GITHUB_OAUTH` **or**
`GITHUB_API_TOKEN` (release.sh ~line 486). Either name works; validate-v13.sh
requires the `*_TOKEN` spellings.


--------------------------------------------------------------------------------
## 8. RELEASE PROCEDURE

Ordered, and the order is the point. Each step catches something the previous
step cannot.

**1. Confirm the maintainer has tested in game.**
Do not tag on your own initiative. If they direct you to publish without testing,
state the risk once, then proceed — it is their call.

**2. Audit the working tree.**
Licence headers intact, package tokens at the 50 / 4 / 1 baseline, `.toc` fields
present. Run repository validation, assemble a credential-free package into
`.release`, and only then pass that assembled directory to the package validator:

    bash .github/scripts/validate-v13.sh
    # Run the pinned BigWigs packager locally with -d to assemble .release.
    bash .github/scripts/validate-package.sh .release

The package validator does not accept the source tree or a zip path.

**3. Stage deliberately. Never `git add -A` blind.**
It has swept a 2 MB `Decursive.zip` build artifact into a commit. Stage named
paths, then read `git diff --cached --stat` before committing. `*.zip` is now
gitignored, but the habit is the protection.

**4. Commit.**
Explain WHY, not just what — root cause, mechanism, and what was verified.

**5. Push to `master`, confirm its automatic verification, then rehearse the
exact commit if needed.**
The push automatically runs `verify`. A manual rehearsal remains available:

    gh workflow run "Check and build addon" --ref master

Wait for green. Verification has read-only repository permission, no publishing
secrets, and cannot publish. **Confirm the run used the commit you are about to
tag** — compare the run's `headSha` with `git rev-parse --short HEAD`. A
documentation-only commit has broken the token baseline before (see §11).

**6. Update the maintainer's AddOns folder and let them test.**
Prefer deploying the *published artifact* over a local rebuild once a release
exists, so they test exactly what users get. Before a release exists, build from
committed state, substitute tokens, and apply the `ignore` rules.

    AddOns path:
    C:\Program Files (x86)\World of Warcraft\_retail_\Interface\AddOns

**7. Tag and push.**
Annotated tag, `vX.Y.Z`. Never reuse a published number. The tag message becomes
the human record of the release.

**8. Verify the published artifact.** Mandatory — section 9.

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
- [ ] **No raw tokens:** `grep -rlE '@project-[[:alnum:]-]+@' ex`
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

**`unzip` prompts "replace ...?" on the published zip**
A case-insensitive filename collision. The zip is built on Linux, where
`README.md` and `Readme.md` are two files; on Windows they are one, so
extraction overwrites one silently. `validate-package.sh` now checks for this.

**`luac: <file>:1: unexpected symbol near '<?>'`**
A UTF-8 BOM (`EF BB BF`). WoW's Lua tolerates it, so such files ship and work in
game for releases, but standard parsers reject them. Strip the three leading
bytes: `tail -c +4 file > tmp && mv tmp file`.

**A validator reports problems that make no sense**
Check its dependencies first. `validate-v13.sh` is built on ripgrep; without it
every `! rg -q ...` guard inverts and it asserts specific, confident, wrong
things. Exit code 127 anywhere in the step is the tell.


--------------------------------------------------------------------------------
## 11. LESSONS LEARNED

Each of these cost a release, a broken build, or an hour of misdiagnosis.

**A green CI check is not proof. Download and extract the published zip.**
Three releases passed lint, uploaded successfully, and shipped a Lua file that
would not parse. Later, v12.1.2 passed all eight automated checks — including a
parse of 83 Lua files — and still shipped a Windows extraction collision,
because the fault was in two `.md` files. Automation covers the classes you have
already been burned by; extracting the artifact covers the rest.

**Anything at the repository root ships inside the addon.**
With `package-as: Decursive` the packager stages the whole checkout under the
package folder. Adding `README.md` and `RELEASE_PROCESS.md` at the root put them
in users' AddOns folders. Every new root-level file needs a matching
[.pkgmeta](.pkgmeta) ignore rule — including the GitHub-discovery
[LICENSE](LICENSE), because the package receives its own `LICENSE.txt` copies.
Treat the ignore rule as part of adding the file.

**An offline drop is a packaged build, not a source tree. MERGE, never replace.**
Files the packager ignores are simply absent from it. A clean replace deletes
them from source — including `branding/decursive-logo-v2.jpg`, which is missing from
every zip *by design*. Always list repo-only files before overwriting.

**Check the drop's base commit.**
One drop reported `v12.0.7-15-g9fe890b`, a commit that did not exist in this
repository. The offline work happens in a different clone; content may be a
superset, a subset, or diverged. Grep for markers from the last few releases
before assuming it builds on current state.

**Verify claims in release notes against the tree.**
One drop's notes stated release validation had been added. No workflow file was
in the zip and no such step existed. Another drop shipped a validator that
required a helper the same drop deliberately removed — it rejected its own fix.

**Restore every package token, not just the obvious one.**
Tokens arrive substituted. `@project-abbreviated-hash@` became a bare short hash
that a `git describe`-shaped search missed entirely; it is a public field other
addons read. Confirm the baseline is 50 / 4 / 1 afterwards.

**Prose counts as source to the token validator.**
Quoting a token name verbatim in `CHANGELOG.md` raised its count and broke the
baseline. Name tokens in prose without spelling them.

**Line endings and file modes are load-bearing.**
Shell scripts must be LF and mode 755, or Linux rejects the shebang with
`bad interpreter: ...^M`. [.gitattributes](.gitattributes) pins this; invoke scripts as
`bash path/to/script.sh` so a lost exec bit cannot break CI.

**CurseForge's public page lags an accepted upload — sometimes by a lot.**
`Uploading ... Success!` is CurseForge's own API response and is authoritative.
The project page showed the previous version for well over twenty minutes after
two successful uploads. Do not re-cut a release chasing this; check the project's
files page while logged in, which distinguishes queued from rejected.

**Deleting a GitHub release does not remove the CurseForge file.**
They are independent uploads. Pulling a bad build means doing both.

**Windows cannot reproduce a case-collision locally.**
The filesystem collapses the pair on write, so a local test reports "no
collision" and passes. That check only means anything in CI, on Linux.

**A run that has not appeared is usually queue latency, not failure.**
GitHub Actions took roughly five minutes to pick up several pushes here. Poll
before concluding anything is wrong.

**Confirm the rehearsal covers the exact commit being tagged.**
Compare the run's `headSha` against `git rev-parse --short HEAD`. A
documentation-only commit landed after a green rehearsal and broke the token
baseline; tagging blind would have failed the release build.


--------------------------------------------------------------------------------
## 12. OUTSTANDING

**The per-environment defaults table exists in three divergent copies.** See §2.
Known and deliberately deferred by the maintainer.

*(Resolved: the broken v11.0.46 / v12.0.4 / v12.0.5 / v12.1.2 files have been
removed from CurseForge by the maintainer. Deleting a GitHub release does not
remove the CurseForge file — both must be done.)*

