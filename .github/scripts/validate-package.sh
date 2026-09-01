#!/usr/bin/env bash
#
# Validates a packaged Decursive build BEFORE it is uploaded anywhere.
#
# This exists because luacheck cannot see this class of fault: the repository
# source is valid Lua and the corruption is introduced *during* packaging. Three
# releases -- v11.0.46, v12.0.4 and v12.0.5 -- passed lint, uploaded
# successfully, and shipped a LibQTip-1.0.lua that would not parse in game.
#
# Run against an assembled packager output directory, not a source checkout or
# zip archive, e.g.
#   bash .github/scripts/validate-package.sh .release
#
set -euo pipefail

if [ "$#" -ne 1 ]; then
    echo "Usage: bash .github/scripts/validate-package.sh <assembled-release-directory>" >&2
    exit 2
fi

releasedir="$1"
case "$releasedir" in
    [A-Za-z]:[\\/]* )
        if command -v cygpath >/dev/null 2>&1; then
            releasedir=$(cygpath -u "$releasedir")
        fi
        ;;
esac
releasedir="${releasedir//\\//}"
releasedir="${releasedir%/}"

status=0
fail() { echo "ERROR: $*" >&2; status=1; }
note() { echo "  $*"; }

[ -d "$releasedir" ] || { echo "ERROR: no package directory at '$releasedir'." >&2; exit 1; }

echo "Validating packaged output in '$releasedir'"

# ---------------------------------------------------------------------------
# 1. Structure. The .pkgmeta move-folders entries must land both addon folders
#    at the top level. A missing self-reference nests them one level deeper and
#    the addon silently never loads.
# ---------------------------------------------------------------------------
for addon in Decursive Decursive_Options; do
    toc="$releasedir/$addon/$addon.toc"
    if [ -f "$toc" ]; then
        note "found $addon/$addon.toc"
    else
        fail "$addon/$addon.toc is missing or nested too deeply; the addon will not load."
    fi
done

if [ -d "$releasedir/Decursive/Decursive" ]; then
    fail "double-nested package folder ($releasedir/Decursive/Decursive). Check the self-referencing move-folders entry in .pkgmeta."
fi

# ---------------------------------------------------------------------------
# 2. Duplicated long-string delimiters. The packager appends its own ]==] to a
#    line already ending in ]==] wherever an --@end-debug@ marker survives,
#    leaving a bare bracket as code.
# ---------------------------------------------------------------------------
if grep -rn --include='*.lua' -e ']==]]==]' -e ']===]]===]' "$releasedir"; then
    fail "duplicated long-string delimiter in packaged Lua (see above). This will not parse in game."
else
    note "no duplicated long-string delimiters"
fi

# ---------------------------------------------------------------------------
# 3. Unsubstituted package tokens. Source keeps these; a shipped build must not.
# ---------------------------------------------------------------------------
if grep -rlnE --include='*.lua' --include='*.xml' --include='*.toc' \
        --include='*.md' --include='*.txt' \
        '@project-[[:alnum:]-]+@' "$releasedir"; then
    fail "unsubstituted package tokens in packaged output (see above)."
else
    note "all package tokens substituted"
fi

# ---------------------------------------------------------------------------
# 4. Lua syntax. Parse every packaged Lua file if an interpreter is available.
#    This is the direct check that would have caught the LibQTip breakage.
# ---------------------------------------------------------------------------
luabin=""
for candidate in luac luac5.1 luac5.4 lua lua5.1 lua5.4; do
    if command -v "$candidate" >/dev/null 2>&1; then luabin="$candidate"; break; fi
done

if [ -n "$luabin" ]; then
    parsed=0
    while IFS= read -r f; do
        case "$luabin" in
            luac*)
                if ! parser_output=$("$luabin" -p "$f" 2>&1); then
                    fail "Lua syntax error in ${f#"$releasedir/"}"
                    printf '    %s\n' "$parser_output" >&2
                fi
                ;;
            *)
                if ! parser_output=$("$luabin" -e "assert(loadfile([[$f]]))" 2>&1); then
                    fail "Lua syntax error in ${f#"$releasedir/"}"
                    printf '    %s\n' "$parser_output" >&2
                fi
                ;;
        esac
        parsed=$((parsed + 1))
    done < <(find "$releasedir" -name '*.lua' -type f)
    note "parsed $parsed Lua files with $luabin"
else
    note "no Lua interpreter available; skipped the syntax parse (structural checks still ran)"
fi

# ---------------------------------------------------------------------------
# 5. Every file a .toc references must exist in the package.
# ---------------------------------------------------------------------------
for addon in Decursive Decursive_Options; do
    toc="$releasedir/$addon/$addon.toc"
    [ -f "$toc" ] || continue
    missing=0
    while IFS= read -r rel; do
        rel="${rel%$'\r'}"
        [ -f "$releasedir/$addon/${rel//\\//}" ] || { fail "$addon.toc references a missing file: $rel"; missing=$((missing + 1)); }
    done < <(grep -E '^[A-Za-z0-9_].*\.(lua|xml)[[:space:]]*$' "$toc" || true)
    [ "$missing" -eq 0 ] && note "$addon: every referenced file present"
done

# ---------------------------------------------------------------------------
# 6. Each top-level addon must ship the licence.
# ---------------------------------------------------------------------------
for addon in Decursive Decursive_Options; do
    if [ -f "$releasedir/$addon/LICENSE.txt" ]; then
        note "$addon/LICENSE.txt present"
    else
        fail "$addon/LICENSE.txt is missing; check license-output and move-folders in .pkgmeta."
    fi
done
if [ -f "$releasedir/Decursive/LICENSE.txt" ] \
    && [ -f "$releasedir/Decursive_Options/LICENSE.txt" ]; then
    if ! cmp -s "$releasedir/Decursive/LICENSE.txt" "$releasedir/Decursive_Options/LICENSE.txt"; then
        fail "the two packaged LICENSE.txt files differ."
    elif ! grep -q 'GNU GENERAL PUBLIC LICENSE' "$releasedir/Decursive/LICENSE.txt" \
        || ! grep -q 'Version 3, 29 June 2007' "$releasedir/Decursive/LICENSE.txt"; then
        fail "the packaged LICENSE.txt files are not the GNU GPL version 3 text."
    else
        note "both addon licenses contain identical GPLv3 text"
    fi
fi

# ---------------------------------------------------------------------------
# 7. Case-insensitive filename collisions.
#
#    Linux packs the zip, but most players extract it on Windows, where two
#    paths differing only in case are ONE file. v12.1.2 shipped both
#    Decursive/README.md and Decursive/Readme.md: extracting it prompted to
#    overwrite, and one document silently replaced the other.
#
#    The Lua parser cannot see this -- neither file is Lua -- so it needs its
#    own check.
# ---------------------------------------------------------------------------
collisions=$(
    find "$releasedir" -type f -printf '%P\n' 2>/dev/null \
        | tr 'A-Z' 'a-z' | sort | uniq -d
)
if [ -n "$collisions" ]; then
    while IFS= read -r lower; do
        [ -n "$lower" ] || continue
        actual=$(find "$releasedir" -type f -printf '%P\n' 2>/dev/null \
            | awk -v l="$lower" 'tolower($0)==l' | paste -sd', ' -)
        fail "case-insensitive filename collision: $actual (these are one file on Windows)"
    done <<< "$collisions"
else
    note "no case-insensitive filename collisions"
fi

# ---------------------------------------------------------------------------
# 8. Source-only files must not ship.
#
#    With package-as: Decursive the packager stages the entire checkout under
#    the package folder, so anything left at the repository root lands inside
#    the addon unless .pkgmeta ignores it. v12.1.2 shipped README.md and
#    RELEASE_PROCESS.md this way. v12.1.4-alpha.4 then shipped CHANGELOG.md,
#    OldChangeLog.md, WhatsNew.md, and RELEASE_NOTES_v12.1.4-alpha.4.md
#    because the leak-list denylist only named older RELEASE_NOTES files.
# ---------------------------------------------------------------------------
leaked=0
while IFS= read -r pattern; do
    hits=$(find "$releasedir" -type f -iname "$pattern" 2>/dev/null || true)
    if [ -n "$hits" ]; then
        while IFS= read -r h; do
            [ -n "$h" ] || continue
            fail "source-only file shipped in the package: ${h#"$releasedir/"}"
            leaked=$((leaked + 1))
        done <<< "$hits"
    fi
done <<'PATTERNS'
RELEASE_PROCESS.md
RELEASE_NOTES_v11*.md
RELEASE_NOTES_v12.0*.md
RELEASE_NOTES*.md
CHANGELOG.md
OldChangeLog.md
WhatsNew.md
Todo.txt
IMPLEMENTATION_SUMMARY.md
FULL_ENVIRONMENT_PROFILES.md
12_1_PATCH_NOTES.md
V10.*.md
V11_*.md
.gitattributes
.editorconfig
.docmeta
.pkgmeta
LICENSE
PATTERNS
[ "$leaked" -eq 0 ] && note "no source-only files leaked into the package"

# The repository's own development docs directory must never be packaged.
if [ -d "$releasedir/Decursive/docs" ] || [ -d "$releasedir/docs" ]; then
    fail "the docs/ tree was packaged; it is repository-only."
fi

if [ -n "$(find "$releasedir" -type d -name .github -print -quit)" ]; then
    fail ".github/ was packaged; release automation is repository-only."
fi

if [ -n "$(find "$releasedir" -type d -name .cursor -print -quit)" ]; then
    fail ".cursor/ was packaged; agent rules are repository-only."
fi

# The branding asset is source-only and is 612 KB, ~30% of an otherwise clean
# download. It has shipped by accident before.
if [ -n "$(find "$releasedir" -type d -name branding -print -quit)" ]; then
    fail "branding/ was packaged; it is source-only and no code references it."
fi

if [ "$status" -eq 0 ]; then
    echo "Package validation passed."
else
    echo "Package validation FAILED; nothing should be uploaded." >&2
fi
exit "$status"
