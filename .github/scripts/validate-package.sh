#!/usr/bin/env bash
#
# Validates a packaged Decursive build BEFORE it is uploaded anywhere.
#
# This exists because luacheck cannot see this class of fault: the repository
# source is valid Lua and the corruption is introduced *during* packaging. Three
# releases -- v11.0.46, v12.0.4 and v12.0.5 -- passed lint, uploaded
# successfully, and shipped a LibQTip-1.0.lua that would not parse in game.
#
# Run against the packager's output directory, e.g.
#   .github/scripts/validate-package.sh .release
#
set -euo pipefail

releasedir="${1:-.release}"

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
if grep -rln --include='*.lua' --include='*.xml' --include='*.toc' \
        -e '@project-version@' -e '@project-date-iso@' "$releasedir"; then
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
            luac*) "$luabin" -p "$f" >/dev/null 2>&1 || fail "Lua syntax error in ${f#"$releasedir/"}" ;;
            *)     "$luabin" -e "assert(loadfile([[$f]]))" >/dev/null 2>&1 || fail "Lua syntax error in ${f#"$releasedir/"}" ;;
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
# 6. Licence must ship with the package.
# ---------------------------------------------------------------------------
if find "$releasedir" -maxdepth 2 -name 'LICENSE.txt' | grep -q .; then
    note "LICENSE.txt present"
else
    fail "LICENSE.txt is missing from the package; check license-output in .pkgmeta."
fi

if [ "$status" -eq 0 ]; then
    echo "Package validation passed."
else
    echo "Package validation FAILED; nothing should be uploaded." >&2
fi
exit "$status"
