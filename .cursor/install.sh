#!/usr/bin/env bash
#
# Cloud Agent install phase for Decursive.
#
# Decursive is a World of Warcraft addon; there is no server to run. The
# "application" is the credential-free CI verification pipeline in
# .github/workflows/build-package-and-upload.yml, which lints every Lua source,
# runs the repository invariant checks, packages the addon with the BigWigs
# packager, and validates the packaged artifact. This script installs exactly
# the toolchain those steps need so a Cloud Agent can reproduce CI locally with
# .cursor/verify.sh.
#
# It is idempotent: re-running it converges without rewriting lockfiles or
# reinstalling already-present tools.
set -euo pipefail

# Pin the BigWigs packager to the same reviewed commit the release workflow
# uses (see .github/workflows/build-package-and-upload.yml). Bump both together.
PACKAGER_COMMIT="36b4c3b7b7bd17c835ad8c83fed4976c067edfbe"
PACKAGER_DIR="${HOME}/.cache/decursive-dev/bigwigs-packager"
PACKAGER_BIN="${PACKAGER_DIR}/release-${PACKAGER_COMMIT}.sh"

log() { printf '\n=== %s ===\n' "$*"; }

log "Installing system packages (lua5.4, luarocks, ripgrep, perl)"
# lua5.4 + luac5.4 parse the packaged addon and run the behavior harnesses;
# luarocks builds luacheck; ripgrep and perl back the repository validators.
export DEBIAN_FRONTEND=noninteractive
sudo apt-get update -qq
sudo apt-get install -y -qq \
    lua5.4 liblua5.4-dev luarocks ripgrep perl

log "Installing luacheck (CI's Lua static analyzer)"
if command -v luacheck >/dev/null 2>&1; then
    echo "luacheck already present: $(luacheck --version | head -1)"
else
    sudo luarocks install luacheck
fi

log "Fetching pinned BigWigs packager (${PACKAGER_COMMIT:0:12})"
if [ -f "$PACKAGER_BIN" ]; then
    echo "Packager already cached at ${PACKAGER_BIN}"
else
    mkdir -p "$PACKAGER_DIR"
    tmp="$(mktemp)"
    curl -fsSL \
        "https://raw.githubusercontent.com/BigWigsMods/packager/${PACKAGER_COMMIT}/release.sh" \
        -o "$tmp"
    chmod +x "$tmp"
    mv "$tmp" "$PACKAGER_BIN"
    # Stable convenience symlink used by .cursor/verify.sh.
    ln -sfn "$PACKAGER_BIN" "${PACKAGER_DIR}/release.sh"
    echo "Cached packager at ${PACKAGER_BIN}"
fi

log "Toolchain versions"
lua5.4 -v
luac5.4 -v 2>/dev/null || true
luacheck --version | head -1
rg --version | head -1
perl -e 'print "perl $]\n"'

log "Install complete"
echo "Run .cursor/verify.sh to reproduce the CI verification pipeline locally."
