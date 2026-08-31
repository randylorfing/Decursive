#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
cd "$repo_root"

for required_command in git perl rg; do
    if ! command -v "$required_command" >/dev/null 2>&1; then
        echo "ERROR: required command '$required_command' is unavailable." >&2
        echo "Install it before running repository validation; Git for Windows includes git and perl, while ripgrep must be installed separately." >&2
        exit 2
    fi
done

status=0

fail() {
    echo "ERROR: $*" >&2
    status=1
}

lua_roots=(Decursive Decursive_Options)

release_workflow=.github/workflows/build-package-and-upload.yml
if ! rg -q --fixed-strings -- "- 'v*'" "$release_workflow" \
    || ! rg -q '^  pull_request:' "$release_workflow" \
    || [ "$(rg -c '^[[:space:]]+- master$' "$release_workflow")" -lt 2 ] \
    || [ "$(rg -c '^[[:space:]]+- alpha$' "$release_workflow")" -lt 2 ]; then
    fail 'The workflow must verify pull requests and pushes for master and alpha while retaining the version-tag trigger.'
fi
if ! rg -q --fixed-strings 'args: -d' "$release_workflow" \
    || ! rg -q --fixed-strings 'needs: verify' "$release_workflow" \
    || ! rg -q --fixed-strings 'validate-package.sh .release' "$release_workflow"; then
    fail 'The publishing workflow lacks its credential-free pre-publish package gate.'
fi
if ! rg -q --fixed-strings 'Run maintained-code static checks' "$release_workflow" \
    || ! rg -q --fixed-strings -- '--no-global' "$release_workflow" \
    || ! rg -q --fixed-strings 'Decursive/Dcr_ProfileManager.lua' "$release_workflow" \
    || ! rg -q --fixed-strings 'Decursive/Dcr_CureBindings.lua' "$release_workflow"; then
    fail 'The workflow lacks its correctness-oriented maintained-code luacheck pass.'
fi
if ! rg -q --fixed-strings 'CF_API_TOKEN: ${{ secrets.CF_API_KEY }}' "$release_workflow" \
    || ! rg -q --fixed-strings 'GITHUB_API_TOKEN: ${{ github.token }}' "$release_workflow"; then
    fail 'Publishing credentials are not scoped to the verified release step.'
fi
[ -f .github/scripts/validate-package.sh ] \
    || fail 'The packaged-artifact validator is missing.'
[ -f .github/scripts/validate-localizations.sh ] \
    || fail 'The localization validator is missing.'
[ -f .github/scripts/test-smart-rez.lua ] \
    || fail 'The smart resurrection behavior harness is missing.'
[ -f .github/scripts/test-soul-link-visual.lua ] \
    || fail 'The Emergency Soul Link visual behavior harness is missing.'
[ -f .github/scripts/test-muf-aura-binding.lua ] \
    || fail 'The MUF native-owner binding behavior harness is missing.'
[ -f .github/scripts/test-muf-native-detection.lua ] \
    || fail 'The MUF native detection behavior harness is missing.'
[ -f .github/scripts/test-cooldown-state-machine.lua ] \
    || fail 'The Retail cooldown transaction behavior harness is missing.'
[ -f .github/scripts/test-muf-state-safety.lua ] \
    || fail 'The MUF state-safety behavior harness is missing.'
[ -f .github/scripts/test-live-list-startup-sentinels.lua ] \
    || fail 'The LiveList startup sentinel behavior harness is missing.'
[ -f .github/scripts/test-dcr-12-1-local-budget.lua ] \
    || fail 'The Dcr_12_1 local-budget regression harness is missing.'
[ -f .github/scripts/test-profile-manager.lua ] \
    || fail 'The profile reset, persistence and assignment regression harness is missing.'
[ -f .github/scripts/test-profile-io.lua ] \
    || fail 'The serialized ProfileIO adversarial and rollback harness is missing.'
[ -f .github/scripts/test-profile-pages.lua ] \
    || fail 'The profile page separation and routing regression harness is missing.'
[ -f .github/scripts/test-full-environment-variants-static.lua ] \
    || fail 'The full environment variant parser harness is missing.'
[ -f .github/scripts/test-cure-bindings.lua ] \
    || fail 'The automatic/manual cure-binding behavior harness is missing.'
[ -f .github/scripts/test-cure-bindings-static.lua ] \
    || fail 'The secure cure-binding static harness is missing.'
[ -f .github/scripts/run-fengari.js ] \
    || fail 'The reliable local Fengari status runner is missing.'
[ -f .github/scripts/parse-lua-tree.js ] \
    || fail 'The repository-wide Fengari Lua parser is missing.'

verify_block=$(sed -n '/^  verify:/,/^  release:/p' "$release_workflow")
release_block=$(sed -n '/^  release:/,$p' "$release_workflow")
if ! printf '%s\n' "$verify_block" | rg -q '^[[:space:]]+contents: read$' \
    || printf '%s\n' "$verify_block" | rg -q 'secrets\.|contents: write'; then
    fail 'The verify job must have read-only contents permission and no publishing secrets.'
fi
if ! printf '%s\n' "$release_block" | rg -q '^[[:space:]]+contents: write$' \
    || ! printf '%s\n' "$release_block" | rg -q --fixed-strings "if: github.event_name == 'push' && startsWith(github.ref, 'refs/tags/v')"; then
    fail 'The release job must have push-event-and-version-tag-gated contents write permission.'
fi
if rg -n 'uses:[[:space:]]+[^[:space:]#]+@(master|main|v[0-9])([[:space:]]|$)' "$release_workflow"; then
    fail 'Every external action must be pinned to a reviewed full commit SHA.'
fi
while IFS= read -r action_use; do
    if ! printf '%s\n' "$action_use" | rg -q 'uses:[[:space:]]+[^[:space:]#]+@[0-9a-f]{40}([[:space:]]+#.*)?$'; then
        fail "External action is not pinned to a full commit SHA: $action_use"
    fi
done < <(rg '^[[:space:]]+-?[[:space:]]*uses:' "$release_workflow" || true)

if ! bash .github/scripts/validate-localizations.sh; then
    status=1
fi

if rg -n --fixed-strings 'L["ER_VERSION_NOTICE"]' Decursive/DCR_init.lua \
    || rg -n --fixed-strings 'L["DEV_VERSION_ALERT"]' Decursive/DCR_init.lua; then
    fail 'The retired beta/RC startup notice is still reachable.'
fi

# Canonical @debug@ blocks are valid source directives. The BigWigs packager
# comments them in packaged builds, and the credential-free package gate parses
# the rewritten Lua before publication. Do not reject legitimate source-only
# development blocks here; malformed packaged output is rejected below CI.

if rg -n --glob '*.lua' --fixed-strings ']==]]==]' "${lua_roots[@]}"; then
    fail 'Found a duplicated long-string delimiter.'
fi

if rg -n --glob '*.lua' --fixed-strings ']===]]===]' "${lua_roots[@]}"; then
    fail 'Found a duplicated long-string delimiter.'
fi

if rg -n --glob '*.{lua,xml,toc}' '@project-[A-Za-z0-9-]+@' "${lua_roots[@]}" >/dev/null; then
    echo 'INFO: source package tokens are present as expected; packaged output must replace them.'
fi

# Runbook baseline. Changelog.md contains one deliberate project-version
# literal, so this source count intentionally covers the full addon trees;
# packaged-output validation below the workflow remains limited to runtime
# .lua/.xml/.toc files.
source_version_tokens=$(rg -o '@project-version@' "${lua_roots[@]}" | wc -l | tr -d ' ')
source_date_tokens=$(rg -o '@project-date-iso@' "${lua_roots[@]}" | wc -l | tr -d ' ')
source_hash_tokens=$(rg -o '@project-abbreviated-hash@' "${lua_roots[@]}" | wc -l | tr -d ' ')
if [ "$source_version_tokens" -ne 51 ] || [ "$source_date_tokens" -ne 4 ] \
    || [ "$source_hash_tokens" -ne 1 ]; then
    fail "Unexpected source package-token baseline (version=$source_version_tokens date=$source_date_tokens hash=$source_hash_tokens)."
fi

if ! rg -q --fixed-strings 'Dcr_ProfileManager.lua' Decursive/Decursive.toc \
    || ! rg -q --fixed-strings 'SCHEMA_VERSION = 6' Decursive/Dcr_ProfileManager.lua \
    || ! rg -q --fixed-strings 'libDualSpecMode = "manager-owned"' Decursive/Dcr_ProfileManager.lua \
    || ! rg -q --fixed-strings 'profileOrder = { Manager.DEFAULT_PROFILE_ID }' Decursive/Dcr_ProfileManager.lua \
    || ! rg -q --fixed-strings 'MAX_PROFILE_NAME_BYTES = 48' Decursive/Dcr_ProfileManager.lua \
    || ! rg -q --fixed-strings 'storedVersion and storedVersion > self.SCHEMA_VERSION' Decursive/Dcr_ProfileManager.lua \
    || ! rg -q --fixed-strings 'reset = { completed = true, schemaVersion = Manager.SCHEMA_VERSION }' Decursive/Dcr_ProfileManager.lua \
    || ! rg -q --fixed-strings 'for key in pairs(saved) do saved[key] = nil end' Decursive/Dcr_ProfileManager.lua \
    || ! rg -q --fixed-strings 'return nil, "future-schema"' Decursive/Dcr_ProfileManager.lua \
    || ! rg -q --fixed-strings 'function Manager:CopyEnvironment' Decursive/Dcr_ProfileManager.lua \
    || ! rg -q --fixed-strings 'function Manager:ImportLogicalProfile' Decursive/Dcr_ProfileManager.lua; then
    fail 'The stable-ID profile manager, compatibility mode, limits, or future-schema guard is incomplete.'
fi
if ! rg -q --fixed-strings 'Decursive/FULL_ENVIRONMENT_PROFILES.md' .pkgmeta; then
    fail 'The full-environment architecture guide must remain source-only in packaged releases.'
fi
if ! rg -q '^[[:space:]]+- \.cursor\r?$' .pkgmeta \
    || [ ! -f .cursor/rules/prohibited-luabinaries-source.mdc ] \
    || ! rg -q --fixed-strings 'Never download files from the `dyne/luabinaries` GitHub repository' .cursor/rules/prohibited-luabinaries-source.mdc; then
    fail 'The prohibited LuaBinaries source rule is missing or is not excluded from addon packages.'
fi
if ! rg -q --fixed-strings 'scope = scope == "environment" and "environment" or "logical"' Decursive/Dcr_ProfileIO.lua \
    || ! rg -q --fixed-strings 'ExportLogicalProfile' Decursive/Dcr_ProfileIO.lua \
    || ! rg -q --fixed-strings 'ImportLogicalProfile' Decursive/Dcr_ProfileIO.lua \
    || ! rg -q --fixed-strings 'BeginEnvironmentEditing' Decursive_Options/V13/Shell.lua \
    || ! rg -q --fixed-strings 'EndEnvironmentEditing' Decursive_Options/V13/Shell.lua; then
    fail 'The full logical-profile IO contract or explicit edit-preview lifecycle is incomplete.'
fi
if rg -n --fixed-strings 'LibDualSpec:EnhanceDatabase' Decursive/DCR_init.lua \
    || ! rg -q --fixed-strings 'and not D.ProfileManager' Decursive_Options/Dcr_opt_tree.lua; then
    fail 'LibDualSpec can still compete with the manager-owned profile resolver.'
fi

for toc in Decursive/Decursive.toc Decursive_Options/Decursive_Options.toc; do
    if ! rg -q '^## Author: John Wellesz, Randy Lorfing\r?$' "$toc"; then
        fail "$toc must credit John Wellesz and Randy Lorfing."
    fi
    if ! rg -q '^## X-License: GNU GPL V3\r?$' "$toc" \
        || ! rg -q '^## Version: @project-version@\r?$' "$toc"; then
        fail "$toc is missing its GPL or packager-owned version metadata."
    fi
done
if ! rg -q '^## X-eMail: randylorfing@gmail\.com\r?$' Decursive/Decursive.toc; then
    fail 'Bug reports are not routed to the fork maintainer in Decursive.toc.'
fi

if rg -n --glob '*.lua' --fixed-strings '"DecursiveVersion"' "${lua_roots[@]}"; then
    fail 'The upstream Decursive version-announcement channel is still used by live code.'
fi
if ! rg -q --fixed-strings 'RegisterComm("ZhaohuDcrVersion"' Decursive/DCR_init.lua \
    || [ "$(rg -c --fixed-strings 'SendCommMessage("ZhaohuDcrVersion"' Decursive/Dcr_Events.lua)" -lt 1 ]; then
    fail 'The fork-specific version-announcement channel is missing or inconsistent.'
fi
zhaohu_comm_prefix='ZhaohuDcrVersion'
if [ "${#zhaohu_comm_prefix}" -gt 16 ]; then
    fail 'The fork-specific AceComm prefix exceeds AceComm maximum length.'
fi

if rg -n --glob '*.{lua,xml,toc}' 'Copyright \(C\) 2006-2025 John Wellesz' "${lua_roots[@]}"; then
    fail 'Found a stale 2025 end year in John Wellesz attribution.'
fi

# Derive attribution coverage from Git history instead of a hand-maintained
# filename list. Any original file that credited John at the v12.0.7 source
# baseline and was changed afterward must retain John's updated copyright and
# add Randy's maintenance attribution near the top of the file.
if git rev-parse --verify --quiet v12.0.7^{commit} >/dev/null; then
    while IFS= read -r file; do
        [ -f "$file" ] || continue
        case "$file" in
            *.lua|*.xml) ;;
            *) continue ;;
        esac
        if git show "v12.0.7:$file" 2>/dev/null | sed -n '1,40p' \
            | rg -q --fixed-strings 'John Wellesz'; then
            header=$(sed -n '1,40p' "$file")
            if ! printf '%s\n' "$header" \
                | rg -q --fixed-strings 'Copyright (C) 2006-2026 John Wellesz' \
                || ! printf '%s\n' "$header" \
                    | rg -q --fixed-strings 'Copyright (C) 2026 Randy Lorfing'; then
                fail "$file is a modified original file without complete John/Randy attribution."
            fi
        fi
    done < <(git diff --name-only --diff-filter=AM v12.0.7...HEAD -- \
        Decursive Decursive_Options)
else
    fail 'The v12.0.7 source tag is unavailable; original-file attribution cannot be verified.'
fi

if ! rg -q --fixed-strings 'maintained and developed it from 2006 through 2026' \
    Decursive_Options/Dcr_opt_tree.lua \
    || ! rg -q --fixed-strings "Zhaohu's Decursive are maintained by Randy Lorfing" \
        Decursive_Options/Dcr_opt_tree.lua; then
    fail 'The in-game About history does not preserve both maintainers’ contributions.'
fi

v13_files=()
while IFS= read -r file; do v13_files+=("$file"); done < <(
    find Decursive/V13 Decursive_Options/V13 -type f -name '*.lua' -print | sort
)
if [ "${#v13_files[@]}" -ne 16 ]; then
    fail "Unexpected v13-owned Lua file count: ${#v13_files[@]} (expected 16)."
fi
for file in "${v13_files[@]}"; do
    header=$(sed -n '1,36p' "$file")
    for phrase in \
        'Copyright (C) 2026 Randy Lorfing' \
        'redistribute it and/or modify' \
        'WITHOUT ANY WARRANTY' \
        'You should have received a copy of the GNU General Public License'; do
        if ! printf '%s\n' "$header" | rg -q --fixed-strings "$phrase"; then
            fail "$file does not contain the complete Randy-owned GPLv3-or-later header."
            break
        fi
    done
done

source_only_files=(
    Decursive/RELEASE_NOTES_v11.0.43.md
    Decursive/RELEASE_NOTES_v11.1.0.md
    Decursive/RELEASE_NOTES_v11.1.1.md
    Decursive/RELEASE_NOTES_v11.1.2.md
    Decursive/RELEASE_NOTES_v11.1.3.md
    Decursive/RELEASE_NOTES_v11.1.4.md
    Decursive/RELEASE_NOTES_v12.0.1.md
    Decursive/RELEASE_NOTES_v12.0.3.md
    Decursive/RELEASE_NOTES_v12.0.4.md
    Decursive/RELEASE_NOTES_v12.0.7.md
    Decursive/12_1_PATCH_NOTES.md
    Decursive/IMPLEMENTATION_SUMMARY.md
    Decursive/Modern/V11_FEATURE_PARITY.md
    Decursive/Modern/V11_REBUILD.md
    Decursive/Modern/V11_UI_AUDIT.md
    Decursive/V10.20_HOTFIX.md
    Decursive/V10.41_12.1_SECRET_SAFETY.md
    Decursive/Todo.txt
    Decursive/branding/decursive-logo.jpg
)
for file in "${source_only_files[@]}"; do
    [ -f "$file" ] || fail "Source-only project file was lost: $file"
done
if [ -e Decursive_Options/LICENSE.txt ] \
    || git ls-files --error-unmatch Decursive_Options/LICENSE.txt >/dev/null 2>&1; then
    fail 'Decursive_Options/LICENSE.txt is packager output and must not be committed in source.'
fi
if ! rg -q --fixed-strings 'Decursive/branding' .pkgmeta \
    || ! rg -q --fixed-strings 'Decursive/RELEASE_NOTES_v12.0*.md' .pkgmeta \
    || ! rg -q --fixed-strings 'Decursive/docs' .pkgmeta; then
    fail 'Source-only assets or superseded release notes lack package-ignore rules.'
fi
if ! rg -q --fixed-strings 'license-output: LICENSE.txt' .pkgmeta; then
    fail 'The packager-generated license output is not configured.'
fi
if [ ! -f LICENSE ] \
    || ! diff -q --strip-trailing-cr LICENSE Decursive/LICENSE.txt >/dev/null \
    || ! rg -q --fixed-strings 'GNU GENERAL PUBLIC LICENSE' LICENSE \
    || ! rg -q --fixed-strings 'Version 3, 29 June 2007' LICENSE; then
    fail 'The repository-root LICENSE must be the complete GPLv3 text shipped in Decursive/LICENSE.txt.'
fi
if ! rg -q '^[[:space:]]+- LICENSE\r?$' .pkgmeta; then
    fail 'The repository-root LICENSE must be ignored from addon packages.'
fi

if rg -n --glob '*.lua' --glob '*.toc' --fixed-strings '/dcrv13' "${lua_roots[@]}"; then
    fail 'Found the retired v13 preview command.'
fi

if ! rg -q --fixed-strings 'UI:InstallAsPrimary()' Decursive_Options/V13/Shell.lua; then
    fail 'The v13 settings shell is not installed as the primary interface.'
fi

if ! rg -q --fixed-strings 'V13\Pages\Settings.lua' Decursive_Options/Decursive_Options.toc; then
    fail 'The complete v13 settings workspace is missing from the options TOC.'
fi

# WoW's Lua runtime reuses generic-for control variables. Deferred menu
# callbacks must therefore read an immutable local or a destination stored on
# the clicked widget. Otherwise every button in a row can act like the final
# button created by that loop.
if ! rg -q --fixed-strings 'button.navigationKey = navigationKey' Decursive_Options/V13/Shell.lua \
    || ! rg -q --fixed-strings 'UI:ShowPage(self.navigationKey)' Decursive_Options/V13/Shell.lua \
    || rg -q --fixed-strings 'UI:ShowPage(item.key)' Decursive_Options/V13/Shell.lua; then
    fail 'The v13 navigation can route clicks through a reused loop variable.'
fi
if ! rg -q --fixed-strings 'button.routeKey = routeKey' Decursive_Options/V13/Pages/Settings.lua \
    || ! rg -q --fixed-strings 'page:SetRoute(self.routeKey)' Decursive_Options/V13/Pages/Settings.lua; then
    fail 'Environment Profile workspace route buttons do not retain their own destination.'
fi
for capture in \
    'local tabKey = tab.key' \
    'local entryKey = entry.key' \
    'local bindingIndex = comboIndex' \
    'local spellID = spellIDValue'; do
    if ! rg -q --fixed-strings "$capture" Decursive_Options/Modern/ZD_UI.lua; then
        fail "A deferred mature-menu callback lacks its per-row capture: $capture"
    fi
done
if ! rg -q --fixed-strings 'move(card.kind, row.index' Decursive_Options/Modern/ZD_UI.lua \
    || ! rg -q --fixed-strings 'local choiceKey = choice.choiceKey' Decursive_Options/Modern/ZD_UI.lua; then
    fail 'A pooled mature-menu callback does not read its current frame-owned row identity.'
fi
if ! rg -q --fixed-strings 'function Controls:Apply(labelText, setter, value)' Decursive_Options/V13/Controls.lua \
    || ! rg -q --fixed-strings 'Controls:Apply(labelText, setter' Decursive_Options/V13/Controls.lua \
    || ! rg -q --fixed-strings 'if result == false then' Decursive_Options/Modern/ZD_UI.lua \
    || ! rg -q --fixed-strings 'return apply()' Decursive_Options/Modern/ZD_UI.lua; then
    fail 'V13 controls do not report backend rejection or apply failure.'
fi
if ! rg -q --fixed-strings 'local MAX_SEARCH_RESULTS = 6' Decursive_Options/V13/Shell.lua \
    || ! rg -q --fixed-strings 'ZD:FindSearchResults(query, MAX_SEARCH_RESULTS)' Decursive_Options/V13/Shell.lua \
    || ! rg -q --fixed-strings 'UI:OpenLegacyRoute(result.page)' Decursive_Options/V13/Shell.lua \
    || ! rg -q --fixed-strings 'if key == "UP" then UI:MoveSearchSelection(-1) end' Decursive_Options/V13/Shell.lua \
    || ! rg -q --fixed-strings 'key == "F" and IsControlKeyDown and IsControlKeyDown()' Decursive_Options/V13/Shell.lua; then
    fail 'The V13 search dropdown is missing bounded result routing or keyboard navigation.'
fi
if ! rg -q --fixed-strings 'function Controls:Toggle(card, labelText, description, getter, setter, enabledGetter)' Decursive_Options/V13/Controls.lua \
    || ! rg -q --fixed-strings 'function Controls:Cycle(card, labelText, valuesGetter, getter, setter, enabledGetter)' Decursive_Options/V13/Controls.lua \
    || ! rg -q --fixed-strings 'if self.controlEnabled == false then return end' Decursive_Options/V13/Controls.lua \
    || ! rg -q --fixed-strings 'end, soundEnabled)' Decursive_Options/V13/Pages/Alerts.lua \
    || ! rg -q --fixed-strings 'cooldownOverlayEnabled)' Decursive_Options/V13/Pages/Alerts.lua; then
    fail 'V13 dependent alert controls are not visibly disabled or mutation-safe.'
fi
if rg -n --fixed-strings 'D:Println' Decursive_Options/V13/Pages/Advanced.lua Decursive_Options/Modern/ZD_UI.lua; then
    fail 'Options diagnostics must use the copyable diagnostic window, never chat output.'
fi
if ! rg -q --fixed-strings 'function ZD:ShowCopyableCompatibilityReport(title, prefix)' Decursive_Options/Modern/ZD_UI.lua \
    || ! rg -q --fixed-strings 'T._ShowCopyableDiagnostic' Decursive_Options/Modern/ZD_UI.lua \
    || ! rg -q --fixed-strings 'ZD:RunCopyableSelfDiagnostic()' Decursive_Options/V13/Pages/Advanced.lua; then
    fail 'V13 diagnostics no longer route through the copyable report window.'
fi

protected_pattern='CreateUnitAuraContainer|CreateUnitAuraSlots|AddAuraGroup|AddAuraSlot|SetDispelTypeText|SetDurationText'
while IFS= read -r match; do
    normalized_match=${match//\\//}
    case "$normalized_match" in
        Decursive/V13/Platform/ProtectedAuras.lua:*) ;;
        *) fail "Protected aura API outside Platform/ProtectedAuras.lua: $normalized_match" ;;
    esac
done < <(rg -n --glob '*.lua' "$protected_pattern" Decursive/V13 || true)

legacy_pattern='AuraUtil\.ForEachAura|C_UnitAuras\.GetAuraDataBy|UnitAura\(|UnitBuff\(|UnitDebuff\('
if rg -n --glob '*.lua' "$legacy_pattern" Decursive/V13; then
    fail 'Found a legacy aura-enumeration path in v13.'
fi

sound_registry_pattern='_G\.C_UnitAuras\.(AddAuraSound|RemoveAuraSound)'
while IFS= read -r match; do
    normalized_match=${match//\\//}
    case "$normalized_match" in
        Decursive/Decursive.lua:*) ;;
        *) fail "Native aura-sound registry API outside Decursive.lua: $normalized_match" ;;
    esac
done < <(rg -n --glob '*.lua' "$sound_registry_pattern" Decursive Decursive_Options || true)

if rg -n --glob '*.lua' --fixed-strings 'MUF baseline refresh' Decursive; then
    fail 'Found the retired post-cure native sound-registry rebuild.'
fi

if rg -n --glob '*.lua' 'Native cure verification refresh|Native shared cooldown refresh' Decursive; then
    fail 'Found a retired combat-time managed AuraContainer refresh.'
fi

if ! rg -q --fixed-strings 'DCR_COOLDOWN_TX_V1_BEGIN' Decursive/Dcr_12_1.lua \
    || ! rg -q --fixed-strings 'managedCooldownDurationObjects.BeginPending(priority, spellID, targetMF, attempt)' Decursive/Dcr_12_1.lua \
    || ! rg -q --fixed-strings 'pcall(C_Spell.GetSpellCooldown, spellID)' Decursive/Dcr_12_1.lua \
    || ! rg -q --fixed-strings 'C_Spell.GetSpellChargeDuration' Decursive/Dcr_12_1.lua \
    || rg -q --fixed-strings 'GetSpellCooldownDuration, spellID, true' Decursive/Dcr_12_1.lua; then
    fail 'The Retail cooldown pending transaction, public-state gate, or documented Duration API contract is incomplete.'
fi

if rg -n --glob '*.lua' --fixed-strings 'UpdateAllAuras' \
    Decursive/Dcr_12_1.lua Decursive/Dcr_12_1_DebuffIdentity.lua; then
    fail '12.1 code must let AuraContainer process UNIT_AURA; manual UpdateAllAuras calls are forbidden.'
fi

# The guard must stay centralized in one helper, but its *boundary* changed in
# v12.1.2: HasActiveAddonRestriction() treated every unrelated AddOnRestriction
# as a reason to defer, which left the registry permanently queued in some
# dungeons. It was replaced deliberately by the chat-messaging lockdown check
# that DBM uses, so requiring the old symbol here would reject the very fix this
# script ships alongside.
if ! rg -q --fixed-strings 'nativeAuraSoundMutationBlocked()' Decursive/Decursive.lua \
    || ! rg -q --fixed-strings 'InChatMessagingLockdown' Decursive/Decursive.lua; then
    fail 'Native aura-sound registration lacks its centralized combat/restriction guard.'
fi

if rg -n --fixed-strings 'NativeAuraSoundHandles' Decursive/Decursive.lua; then
    fail 'Found the retired parallel handle array/destructive sound-registry lifecycle.'
fi

if ! rg -q --fixed-strings 'rememberNativeAuraSoundRegistration' Decursive/Decursive.lua \
    || ! rg -q --fixed-strings 'failedReplacementPairs' Decursive/Decursive.lua \
    || ! rg -q --fixed-strings 'D:RefreshProtectedAuraSounds(event .. " immediate")' Decursive/Dcr_12_1.lua; then
    fail 'Native aura-sound desired-state reconciliation or immediate roster synchronization is missing.'
fi

if ! rg -q --fixed-strings 'NativeAuraSoundRetryReason' Decursive/Decursive.lua \
    || ! rg -q --fixed-strings 'MAX_NATIVE_AURA_SOUND_REMOVE_RETRIES = 3' Decursive/Decursive.lua \
    || ! rg -q --fixed-strings 'scheduleNativeAuraSoundRemovalRetry("refresh", reason)' Decursive/Decursive.lua \
    || ! rg -q --fixed-strings 'T._AuraSoundDiag.exactMatches = exactMatches' Decursive/Decursive.lua \
    || ! rg -q --fixed-strings 'T._AuraSoundDiag.stalePerUnit = stalePerUnit' Decursive/Decursive.lua; then
    fail 'Native aura-sound cleanup retries or exact/stale diagnostics are incomplete.'
fi

if ! rg -q --fixed-strings 'if context.isRaid then' Decursive/Decursive.lua \
    || ! rg -q --fixed-strings 'builtInEntriesAllowedForUnit(entries, unit, groupContext)' Decursive/Decursive.lua \
    || ! rg -q --fixed-strings 'T._AuraSoundDiag.raidScoped = groupContext.isRaid == true' Decursive/Decursive.lua; then
    fail 'Native aura-sound raid token/content scoping is missing.'
fi

if rg -n --fixed-strings 'UnitAuraSoundTrigger.ApplicationsIncreased' Decursive; then
    fail 'Stack/dose sound registration violates the clean-to-afflicted alert contract.'
fi

if ! rg -q --fixed-strings 'state == S_Activating or state == S_Active' Decursive/Dcr_Events.lua; then
    fail 'The Activating restriction state is not preserved as blocked during event dispatch.'
fi

if ! rg -q --fixed-strings 'C_Timer.After(0, retryPendingNativeAttach)' Decursive/Dcr_12_1.lua; then
    fail 'Native AuraContainer retries are not deferred past restriction-event dispatch.'
fi

if ! rg -q --fixed-strings 'if DC.TWELVEONE then return; end' Decursive/Dcr_Events.lua \
    || ! rg -q --fixed-strings 'function D:UNIT_AURA(_event, _unit, _auraUpdateInfo)' Decursive/Dcr_12_1.lua; then
    fail 'The 12.1 UNIT_AURA payload is not fail-closed before legacy inspection.'
fi

# The normal COMBAT_LOG_EVENT_UNFILTERED event has no payload. On 12.1 the
# guard must precede CombatLogGetCurrentEventInfo() itself; checking the values
# returned by that API afterward is already too late for a secure-click addon.
combat_log_guard_line=$(rg -n --fixed-strings 'if DC.TWELVEONE and event == nil then return; end' \
    Decursive/Dcr_Events.lua | head -n 1 | cut -d: -f1 || true)
combat_log_call_line=$(rg -n '= CombatLogGetCurrentEventInfo\(\)' \
    Decursive/Dcr_Events.lua | head -n 1 | cut -d: -f1 || true)
if [ -z "$combat_log_guard_line" ] || [ -z "$combat_log_call_line" ] \
    || [ "$combat_log_guard_line" -ge "$combat_log_call_line" ]; then
    fail 'The 12.1 combat-log guard does not precede CombatLogGetCurrentEventInfo().'
fi

if ! rg -q --fixed-strings 'local function nativeConfigurationBlocked()' Decursive/Dcr_12_1.lua \
    || ! rg -q --fixed-strings 'local function nativeAuraDisplayMutationBlocked()' Decursive/Dcr_12_1.lua \
    || ! rg -q --fixed-strings 'return D.HasActiveAddonRestriction and D:HasActiveAddonRestriction() or false' Decursive/Dcr_12_1.lua; then
    fail 'AuraContainer lifecycle and post-initialization display restrictions are not separated.'
fi

if ! rg -q --fixed-strings 'DCR_NATIVE_MUF_BINDING_V1_BEGIN' Decursive/Dcr_12_1.lua \
    || ! rg -q --fixed-strings 'rebindNativeManagedAuraOwners(MF, expectedUnit, true)' Decursive/Dcr_12_1.lua \
    || ! rg -q --fixed-strings 'refreshNativeCarrierFilters(MF)' Decursive/Dcr_12_1.lua \
    || ! rg -q --fixed-strings 'Native owner binding issues (public addon-owned tokens only):' Decursive/Dcr_12_1.lua; then
    fail 'The MUF native-owner binding, lifecycle restore, or copyable diagnostic invariant is missing.'
fi

if ! rg -q --fixed-strings 'if not DC.TWELVEONE and debuffs[1] then' Decursive/Dcr_DebuffsFrame.lua; then
    fail 'The legacy MUF tooltip can still enumerate aura-instance details on 12.1.'
fi

if ! rg -q --fixed-strings 'if DC.TWELVEONE then return false; end' Decursive/Dcr_LiveList.lua \
    || ! rg -q --fixed-strings 'The 12.1 runtime uses Blizzard-managed AuraContainers' Decursive/Decursive.lua \
    || ! rg -q --fixed-strings 'if DC.TWELVEONE then return false; end' Decursive/Decursive.lua; then
    fail 'A legacy aura/Live List entry point is not explicitly disabled on 12.1.'
fi

if ! rg -q --fixed-strings 'if InCombatLockdown and InCombatLockdown() then' Decursive/Dcr_opt.lua \
    || ! rg -q --fixed-strings 'if InCombatLockdown and InCombatLockdown() then return false; end' Decursive/DCR_init.lua; then
    fail 'Macro/binding mutation is missing a combat guard at an API boundary.'
fi

if ! rg -q --fixed-strings 'type(index) == "number" and index > 0 and toDelete' Decursive/Dcr_Events.lua \
    || [ "$(rg -c --fixed-strings 'if InCombatLockdown and InCombatLockdown() then' Decursive/Dcr_DebuffsFrame.lua)" -lt 4 ]; then
    fail 'A macro-delete or secure-MUF attribute boundary is missing its combat guard.'
fi

if ! rg -q --fixed-strings 'Settings cannot be loaded for the first time during combat.' Decursive/Modern/ZD_LoadOptions.lua; then
    fail 'The LoadOnDemand settings addon can still be enabled or loaded for the first time in combat.'
fi

if ! rg -q --fixed-strings 'self:AddDelayedFunctionCall("ResetWindow", self.ResetWindow, self);' Decursive/Decursive.lua; then
    fail 'The slash-command window reset can still move the secure MUF parent during combat.'
fi

if ! rg -q --fixed-strings 'self:AddDelayedFunctionCall("Dcr_StopMUFMovement"' Decursive/Dcr_Events.lua \
    || ! rg -q --fixed-strings 'Dcr_ApplyMUFHandleMouseState' Decursive/Dcr_opt.lua; then
    fail 'A MUF drag or handle-mouse mutation can still cross the combat boundary.'
fi

for deferred_overlay in Dcr121_StatusLight_ Dcr121_RangeOverlay_ Dcr121_LineOfSightOverlay_ Dcr121_CooldownOverlay_; do
    if ! rg -q --fixed-strings "$deferred_overlay" Decursive/Dcr_12_1.lua; then
        fail "A 12.1 MUF overlay lacks combat-deferred construction: $deferred_overlay"
    fi
done

# D.IsSpellInRange is deliberately a plain (spellName, unit) function. Passing
# D as an implicit self shifts both arguments and makes an unknown nil result
# look like a completed out-of-range test, tinting every non-player MUF yellow.
if rg -n --fixed-strings 'pcall(D.IsSpellInRange, D,' Decursive/Dcr_12_1.lua; then
    fail 'The MUF range overlay calls D.IsSpellInRange with a shifted method-style signature.'
fi

if ! rg -q --fixed-strings 'DCR_RANGE_KNOWN_RESULT_GUARD_V1' Decursive/Dcr_12_1.lua \
    || ! rg -q --fixed-strings 'pcall(D.IsSpellInRange, spellName, unit)' Decursive/Dcr_12_1.lua \
    || ! rg -q --fixed-strings 'local rangeKnown = ok and isAccessiblePublicValue(value)' Decursive/Dcr_12_1.lua \
    || ! rg -q --fixed-strings 'local ok, value, checked = pcall(UnitInRange, unit)' Decursive/Dcr_12_1.lua \
    || ! rg -q --fixed-strings 'and (checked == true or checked == 1)' Decursive/Dcr_12_1.lua \
    || ! rg -q --fixed-strings 'outOfRange = knownSpellCount == relevantSpellCount' Decursive/Dcr_12_1.lua \
    || ! rg -q --fixed-strings 'local shown = MF.Shown == true' Decursive/Dcr_12_1.lua \
    || ! rg -q --fixed-strings 'if checked ~= true and checked ~= 1 then return nil; end' Decursive/Dcr_utils.lua \
    || ! rg -q --fixed-strings 'if uir == false or uir == 0 then return 0; end' Decursive/Dcr_utils.lua; then
    fail 'The range overlay lacks its known-result or inactive-slot regression guard.'
fi

# All full-square v13 state layers must preserve upstream Decursive's visible
# two-pixel border: 16x16 inside a normal 20x20 MUF, 12x12 for pet MUFs.
if ! rg -q --fixed-strings 'local function syncOwnedOverlayToMUFInner(MF, overlay)' Decursive/Dcr_12_1.lua \
    || [ "$(rg -c --fixed-strings 'return syncOwnedOverlayToMUFInner(MF, overlay)' Decursive/Dcr_12_1.lua)" -lt 3 ] \
    || [ "$(rg -c --fixed-strings 'initializeProviderPriorityButton(btn, p, MF, getMUFInnerAnchor(MF))' Decursive/Dcr_12_1.lua)" -lt 2 ] \
    || ! rg -q --fixed-strings 'holder:SetAllPoints(getMUFInnerAnchor(MF) or MF.Frame)' Decursive/Dcr_12_1.lua; then
    fail 'A range, line-of-sight, cooldown or affliction layer can escape the original inner MUF square.'
fi

# Original Decursive makes "units per line" authoritative in every context and
# re-anchors the MUF grid whenever either spacing value changes. The v13 page
# once saved Y spacing without calling ResetAllPositions(), while its automatic
# raid grid also overrode the user's layout in raids and battlegrounds.
for setting in DebuffsFrameTieSpacing DebuffsFrameXSpacing DebuffsFrameYSpacing; do
    if ! rg -q --fixed-strings "[\"$setting\"] = function" Decursive/Dcr_opt.lua; then
        fail "MUF spacing setting lacks its centralized live-layout action: $setting"
    fi
done
if ! rg -q --fixed-strings 'D.profile.DebuffsFrameYSpacing = D.profile.DebuffsFrameXSpacing;' Decursive/Dcr_opt.lua \
    || ! rg -q --fixed-strings 'function MicroUnitF:GetEffectivePerLine()' Decursive/Dcr_DebuffsFrame.lua \
    || ! rg -q --fixed-strings 'function() return not D.profile or D.profile.DebuffsFrameTieSpacing ~= true end)' Decursive_Options/V13/Pages/MUFs.lua; then
    fail 'Original linked/independent MUF spacing behavior is incomplete.'
fi
if rg -n --fixed-strings 'DebuffsFrameRaidAutoLayout121' \
    Decursive/Dcr_DebuffsFrame.lua Decursive/Dcr_opt.lua \
    Decursive_Options/Dcr_opt_tree.lua Decursive_Options/V13/Pages/MUFs.lua \
    Decursive_Options/Modern/ZD_UI.lua; then
    fail 'A raid/PvP-specific auto-layout can still override original Decursive grid geometry.'
fi
if ! rg -q --fixed-strings 'DebuffsFrameElemScale = 1.5,' Decursive/Dcr_opt.lua \
    || ! rg -q --fixed-strings 'DebuffsFrameXSpacing = 2,' Decursive/Dcr_opt.lua \
    || ! rg -q --fixed-strings 'DebuffsFrameYSpacing = 2,' Decursive/Dcr_opt.lua \
    || ! rg -q --fixed-strings 'number("muf.partySize", 30,' Decursive/V13/Core/SettingsSchema.lua \
    || ! rg -q --fixed-strings 'number("muf.raidSize", 30,' Decursive/V13/Core/SettingsSchema.lua \
    || ! rg -q --fixed-strings 'SetContextMUFSizePixels("PARTY", 30);' Decursive_Options/Dcr_opt_tree.lua \
    || ! rg -q --fixed-strings 'SetContextMUFSizePixels("RAID", 30);' Decursive_Options/Dcr_opt_tree.lua; then
    fail 'The Party 30 / Raid 30 / linked 2-pixel MUF defaults are inconsistent.'
fi

if ! rg -q --fixed-strings 'FlushProtectedAuraSoundRefresh("PLAYER_REGEN_ENABLED")' Decursive/Dcr_Events.lua; then
    fail 'Combat-deferred aura-sound registry changes are not flushed after combat.'
fi

# A full client start can expose PLAYER_ENTERING_WORLD before Decursive has a
# public player GUID and a stable party snapshot. The readiness edge must start
# the bounded MUF recovery, and every settling pass must re-evaluate the
# context scale/auto-hide state that an early solo snapshot may have changed.
if ! rg -q --fixed-strings 'DCR_COLD_LOGIN_MUF_RECOVERY_V1' Decursive/Dcr_Events.lua \
    || ! rg -q --fixed-strings 'if PollTalentsAvaibility() then' Decursive/Dcr_Events.lua \
    || ! rg -q --fixed-strings 'self:ReinitializeDecursiveAfterZone("DECURSIVE_TALENTS_AVAILABLE")' Decursive/Dcr_Events.lua \
    || ! rg -q --fixed-strings 'D.MicroUnitF:ApplyContextMUFScale()' Decursive/Dcr_12_1.lua \
    || ! rg -q --fixed-strings 'if D.AutoHideShowMUFs then D:AutoHideShowMUFs() end' Decursive/Dcr_12_1.lua; then
    fail 'The cold-login MUF readiness or visibility recovery boundary is missing.'
fi

# Saved profile state is not proof that the secure parent or its children are
# actually shown. A full client start can leave ShowDebuffsFrame=true while the
# XML-created parent is still hidden, and the periodic updater is not a valid
# prerequisite for displaying a newly assigned child. Reconcile both states at
# their mutation boundaries and retain an in-game pre-/reload diagnostic.
if ! rg -q --fixed-strings 'function D:SetDebuffsFrameEnabled(enabled)' Decursive/Dcr_opt.lua \
    || ! rg -q --fixed-strings 'local containerShown = D.MFContainer and D.MFContainer:IsShown() or false;' Decursive/Dcr_opt.lua \
    || ! rg -q --fixed-strings 'return D:SetDebuffsFrameEnabled(desiredEnabled);' Decursive/Dcr_opt.lua \
    || ! rg -q --fixed-strings 'MF.Frame:Show();' Decursive/Dcr_DebuffsFrame.lua \
    || ! rg -q --fixed-strings 'D:RefreshDecursiveAfterRoster("CONFIGURATION_COMPLETE")' Decursive/DCR_init.lua \
    || ! rg -q --fixed-strings 'SLASH_ZHAOHUMUF1 = "/zdmuf"' Decursive/Decursive.lua; then
    fail 'The cold-login MUF parent/child convergence or startup diagnostic is missing.'
fi

for toc in Decursive/Decursive.toc Decursive_Options/Decursive_Options.toc; do
    base=${toc%/*}
    while IFS= read -r entry; do
        entry=${entry%$'\r'}
        [ -z "$entry" ] && continue
        case "$entry" in
            '##'*|'#'*) continue ;;
        esac
        normalized=${entry//\\//}
        [ -e "$base/$normalized" ] || fail "$toc references missing file: $entry"
    done < "$toc"
done

lua_runner=''
for candidate in lua lua5.4 lua5.1; do
    if command -v "$candidate" >/dev/null 2>&1; then
        lua_runner="$candidate"
        break
    fi
done

if [ -n "$lua_runner" ]; then
    "$lua_runner" .github/scripts/test-smart-rez.lua || status=1
    "$lua_runner" .github/scripts/test-soul-link-visual.lua || status=1
    "$lua_runner" .github/scripts/test-muf-aura-binding.lua || status=1
    "$lua_runner" .github/scripts/test-muf-native-detection.lua || status=1
    "$lua_runner" .github/scripts/test-cooldown-state-machine.lua || status=1
    "$lua_runner" .github/scripts/test-muf-state-safety.lua || status=1
    "$lua_runner" .github/scripts/test-live-list-startup-sentinels.lua || status=1
    "$lua_runner" .github/scripts/test-dcr-12-1-local-budget.lua || status=1
    "$lua_runner" .github/scripts/test-profile-manager.lua || status=1
    "$lua_runner" .github/scripts/test-profile-io.lua || status=1
    "$lua_runner" .github/scripts/test-profile-pages.lua || status=1
    "$lua_runner" .github/scripts/test-full-environment-variants-static.lua || status=1
    "$lua_runner" .github/scripts/test-cure-bindings.lua || status=1
    "$lua_runner" .github/scripts/test-cure-bindings-static.lua || status=1
    if "$lua_runner" .github/scripts/test-profile-manager.lua --self-test-failure >/dev/null 2>&1; then
        fail 'The profile-manager harness failure self-test unexpectedly returned success.'
    else
        echo 'PASS: profile-manager harness failure self-test returned nonzero.'
    fi
    if "$lua_runner" .github/scripts/test-profile-io.lua --self-test-failure >/dev/null 2>&1; then
        fail 'The ProfileIO harness failure self-test unexpectedly returned success.'
    else
        echo 'PASS: ProfileIO harness failure self-test returned nonzero.'
    fi
    if "$lua_runner" .github/scripts/test-cure-bindings.lua --self-test-failure >/dev/null 2>&1; then
        fail 'The cure-binding harness failure self-test unexpectedly returned success.'
    else
        echo 'PASS: cure-binding harness failure self-test returned nonzero.'
    fi
    if "$lua_runner" .github/scripts/test-cooldown-state-machine.lua --self-test-failure >/dev/null 2>&1; then
        fail 'The cooldown state-machine harness failure self-test unexpectedly returned success.'
    else
        echo 'PASS: cooldown state-machine harness failure self-test returned nonzero.'
    fi
else
    echo 'INFO: no local Lua runtime is available; CI installs Lua 5.4 for behavior harnesses.'
fi

lua_parser=''
if command -v luac >/dev/null 2>&1; then
    lua_parser='luac'
elif command -v luac5.4 >/dev/null 2>&1; then
    lua_parser='luac5.4'
elif command -v luac5.1 >/dev/null 2>&1; then
    lua_parser='luac5.1'
elif command -v texluac >/dev/null 2>&1; then
    lua_parser='texluac'
fi

if [ -n "$lua_parser" ]; then
    while IFS= read -r file; do
        "$lua_parser" -p "$file" || status=1
    done < <(rg --files "${lua_roots[@]}" 2>/dev/null | rg '\.lua$' || true)
else
    echo 'INFO: no local Lua parser is available; CI luacheck remains the full-source parser.'
fi

if command -v xmllint >/dev/null 2>&1; then
    while IFS= read -r file; do
        xmllint --noout "$file" || status=1
    done < <(rg --files "${lua_roots[@]}" 2>/dev/null | rg '\.xml$' || true)
else
    python_command=()
    if command -v python3 >/dev/null 2>&1 \
        && python3 -c 'import sys' >/dev/null 2>&1; then
        python_command=(python3)
    elif command -v python >/dev/null 2>&1 \
        && python -c 'import sys' >/dev/null 2>&1; then
        python_command=(python)
    elif command -v py >/dev/null 2>&1 \
        && py -3 -c 'import sys' >/dev/null 2>&1; then
        python_command=(py -3)
    fi

    if [ "${#python_command[@]}" -gt 0 ]; then
        "${python_command[@]}" - "${lua_roots[@]}" <<'PY' || status=1
import pathlib
import sys
import xml.etree.ElementTree as ET

for root in sys.argv[1:]:
    for path in pathlib.Path(root).rglob("*.xml"):
        ET.parse(path)
PY
    else
        echo 'INFO: no local XML parser is available; XML existence is still checked through both TOCs.'
    fi
fi

if [ "$status" -ne 0 ]; then
    exit "$status"
fi

echo 'OK: v13 source boundaries and package-sensitive syntax checks passed.'
