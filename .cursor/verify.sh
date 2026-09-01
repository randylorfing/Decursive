#!/usr/bin/env bash
#
# Reproduce the credential-free CI verification pipeline locally.
#
# Mirrors the `verify` job in
# .github/workflows/build-package-and-upload.yml step for step, so a green run
# here is the same signal CI gives on a pull request. It never uploads anything
# and needs no credentials. Requires the toolchain installed by
# .cursor/install.sh.
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

PACKAGER="${HOME}/.cache/decursive-dev/bigwigs-packager/release.sh"
if [ ! -x "$PACKAGER" ]; then
    echo "ERROR: BigWigs packager not found at $PACKAGER. Run .cursor/install.sh first." >&2
    exit 1
fi

# The maintained-code static-check file list is kept in sync with the workflow.
maintained_files=(
    Decursive/DCR_init.lua
    Decursive/Dcr_12_1.lua
    Decursive/Dcr_12_1_Utils.lua
    Decursive/Dcr_12_1_DebuffIdentity.lua
    Decursive/Dcr_12_1_SoulLink.lua
    Decursive/Dcr_DIAG.lua
    Decursive/Dcr_DebuffsFrame.lua
    Decursive/Dcr_Events.lua
    Decursive/Dcr_LiveList.lua
    Decursive/Dcr_ProfileIO.lua
    Decursive/Dcr_opt.lua
    Decursive/Dcr_preload.lua
    Decursive/Dcr_utils.lua
    Decursive/Decursive.lua
    Decursive/Database
    Decursive/Modern
    Decursive/V13
    Decursive_Options/Modern/ZD_UI.lua
    Decursive_Options/V13
)

step() { printf '\n\033[1m=== %s ===\033[0m\n' "$*"; }

step "1/6 Parse all Lua sources with luacheck (syntax only)"
luacheck -qo 011 -- .

step "2/6 Maintained-code static checks"
luacheck -q --codes --no-global \
    --ignore 211 212 213 231 232 233 241 311 312 313 314 331 \
    421 422 423 431 432 433 611 612 613 614 621 631 411/select \
    -- "${maintained_files[@]}"

step "3/6 Check for packager-rewritable debug markers"
marker_status=0
if grep -rn --include='*.lua' -- '--@debug@\|--@end-debug@' Decursive Decursive_Options; then
    echo "::error:: rewritable @debug@/@end-debug@ markers found" >&2
    marker_status=1
fi
if grep -rn --include='*.lua' -e ']==]]==]' -e ']===]]===]' Decursive Decursive_Options; then
    echo "::error:: duplicated long-string delimiter found" >&2
    marker_status=1
fi
[ "$marker_status" -eq 0 ] && echo "OK: no rewritable debug markers, no duplicated delimiters."
[ "$marker_status" -eq 0 ] || exit 1

step "4/6 Validate repository invariants"
bash .github/scripts/validate-v13.sh

step "5/6 Package (dry run, no upload)"
bash "$PACKAGER" -d

step "6/6 Validate packaged artifact"
bash .github/scripts/validate-package.sh .release

printf '\n\033[1;32mAll verification steps passed.\033[0m\n'
