#!/usr/bin/env python3
"""
ZDecursive release validation helpers.

This file is part of ZDecursive, an independently maintained rebuild of
Decursive. Based on Decursive, Copyright (C) 2006-2026 John Wellesz.
ZDecursive rebuild and ongoing maintenance, Copyright (C) 2026 Randy Lorfing.
Licensed under GNU GPL version 3 or (at your option) any later version.
"""

from __future__ import annotations

import hashlib
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import subprocess
import sys
import xml.etree.ElementTree as ET
import zipfile


ADDON = "ZDecursive"
RELEASE_TAG = "v13.1.0-alpha"
TOC_LOAD_ORDER = [
    "embeds.xml",
    "Diagnostics.lua",
    "PersistentDiagnostics.lua",
    "Defaults.lua",
    "DispelData.lua",
    "Core.lua",
    "Lists.lua",
    "Detection.lua",
    "DetectionEngine.lua",
    "MUFPresentation.lua",
    "MUFs.lua",
    "LiveList.lua",
    "Alerts.lua",
    "Options.lua",
]
REQUIRED_LIBRARY_PATHS = [
    "Libs/Ace3-LICENSE.txt",
    "Libs/LibStub/LibStub.lua",
    "Libs/CallbackHandler-1.0/CallbackHandler-1.0.xml",
    "Libs/AceAddon-3.0/AceAddon-3.0.xml",
    "Libs/AceConfig-3.0/AceConfig-3.0.xml",
    "Libs/AceConsole-3.0/AceConsole-3.0.xml",
    "Libs/AceDB-3.0/AceDB-3.0.xml",
    "Libs/AceEvent-3.0/AceEvent-3.0.xml",
    "Libs/AceGUI-3.0/AceGUI-3.0.xml",
]
HEADER_MARKERS = (
    "GNU General Public License",
    "John Wellesz",
    "Randy Lorfing",
)
TEXT_SUFFIXES = {
    ".cjs", ".js", ".json", ".lua", ".md", ".pkgmeta", ".ps1",
    ".py", ".sh", ".toc", ".txt", ".xml", ".yaml", ".yml",
}


class Validation:
    def __init__(self) -> None:
        self.errors: list[str] = []

    def fail(self, message: str) -> None:
        self.errors.append(message)
        print(f"ERROR: {message}", file=sys.stderr)

    def note(self, message: str) -> None:
        print(f"  {message}")

    def finish(self, label: str) -> int:
        if self.errors:
            print(f"{label}: FAILED ({len(self.errors)} error(s))", file=sys.stderr)
            return 1
        print(f"{label}: PASS")
        return 0


def token(name: str) -> str:
    return "@" + name + "@"


def digest(path: Path) -> str:
    value = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            value.update(chunk)
    return value.hexdigest()


def relative_files(root: Path) -> list[Path]:
    return sorted(
        (path for path in root.rglob("*") if path.is_file()),
        key=lambda path: path.relative_to(root).as_posix().casefold(),
    )


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8-sig")


def check_case_collisions(check: Validation, root: Path, label: str) -> None:
    seen: dict[str, str] = {}
    for path in relative_files(root):
        relative = path.relative_to(root).as_posix()
        if relative == ".git" or relative.startswith(".git/"):
            continue
        folded = relative.casefold()
        prior = seen.get(folded)
        if prior is not None and prior != relative:
            check.fail(f"{label} has a case-insensitive path collision: {prior!r} and {relative!r}")
        else:
            seen[folded] = relative


def resolve_exact(check: Validation, base: Path, reference: str, owner: str) -> Path | None:
    parts = PurePosixPath(reference.replace("\\", "/")).parts
    current = base
    for part in parts:
        if part in ("", "."):
            continue
        if part == "..":
            check.fail(f"{owner} contains a parent-directory reference: {reference}")
            return None
        try:
            names = {entry.name: entry for entry in current.iterdir()}
        except OSError:
            check.fail(f"{owner} reference cannot inspect {current}: {reference}")
            return None
        if part not in names:
            alternatives = [name for name in names if name.casefold() == part.casefold()]
            if alternatives:
                check.fail(f"{owner} reference has wrong filename case: {reference} (disk: {alternatives[0]})")
            else:
                check.fail(f"{owner} reference is missing: {reference}")
            return None
        current = names[part]
    return current


def parse_toc(check: Validation, addon_root: Path) -> tuple[dict[str, str], list[str]]:
    toc = addon_root / "ZDecursive.toc"
    if not toc.is_file():
        check.fail("ZDecursive/ZDecursive.toc is missing")
        return {}, []
    metadata: dict[str, str] = {}
    load_order: list[str] = []
    for number, raw_line in enumerate(read_text(toc).splitlines(), 1):
        line = raw_line.strip()
        if not line:
            continue
        if line.startswith("##"):
            match = re.match(r"^##\s+([^:]+):\s*(.*)$", line)
            if not match:
                check.fail(f"invalid TOC metadata at line {number}: {raw_line}")
                continue
            key, value = match.group(1).strip(), match.group(2).strip()
            if key in metadata:
                check.fail(f"duplicate TOC metadata field: {key}")
            metadata[key] = value
            continue
        if line.startswith("#"):
            continue
        load_order.append(line.replace("\\", "/"))
        resolve_exact(check, addon_root, line, "ZDecursive.toc")
    return metadata, load_order


def validate_toc_contract(
    check: Validation,
    addon_root: Path,
    source: bool,
    expected_version: str | None = None,
    expected_commit: str | None = None,
) -> dict[str, str]:
    metadata, load_order = parse_toc(check, addon_root)
    expected = {
        "Interface": "120100",
        "SavedVariables": "DecursiveRebuildDB, ZDecursiveDiagnosticsDB",
        "OptionalDeps": "DandersFrames",
        "Author": "John Wellesz, Randy Lorfing",
        "X-License": "GNU GPL V3",
        "X-Website": "https://github.com/randylorfing/Decursive",
    }
    for key, value in expected.items():
        if metadata.get(key) != value:
            check.fail(f"TOC {key} must be {value!r}, got {metadata.get(key)!r}")
    if load_order != TOC_LOAD_ORDER:
        check.fail(f"TOC load order differs from the release contract: {load_order!r}")
    if source:
        if metadata.get("Version") != token("project-version"):
            check.fail("source TOC Version must be the BigWigs project-version token")
        if metadata.get("X-Zhaohu-Source-Commit") != token("project-hash"):
            check.fail("source TOC X-Zhaohu-Source-Commit must be the BigWigs project-hash token")
    else:
        version = metadata.get("Version", "")
        commit = metadata.get("X-Zhaohu-Source-Commit", "")
        if expected_version is not None and version != expected_version:
            check.fail(f"packaged TOC Version must be {expected_version!r}, got {version!r}")
        if not version or "@" in version:
            check.fail("packaged TOC Version is empty or contains an unresolved token")
        if expected_commit is not None and commit != expected_commit:
            check.fail(f"packaged source commit must be {expected_commit}, got {commit!r}")
        if not re.fullmatch(r"[0-9a-f]{40}", commit):
            check.fail(f"packaged source commit is not a full lowercase Git hash: {commit!r}")
    return metadata


def validate_xml(check: Validation, addon_root: Path) -> None:
    for path in sorted(addon_root.rglob("*.xml")):
        relative = path.relative_to(addon_root).as_posix()
        try:
            tree = ET.parse(path)
        except ET.ParseError as error:
            check.fail(f"XML parse failed for {relative}: {error}")
            continue
        for element in tree.iter():
            local_name = element.tag.rsplit("}", 1)[-1]
            if local_name not in {"Include", "Script"}:
                continue
            reference = element.attrib.get("file")
            if not reference:
                check.fail(f"{relative} has a {local_name} without a file attribute")
                continue
            owner_base = path.parent
            try:
                owner_relative = owner_base.relative_to(addon_root).as_posix()
            except ValueError:
                owner_relative = "."
            combined = "/".join(part for part in (owner_relative, reference.replace("\\", "/")) if part != ".")
            resolve_exact(check, addon_root, combined, relative)


def validate_headers(check: Validation, repo_root: Path, addon_root: Path, include_tests: bool) -> None:
    candidates = [
        *addon_root.glob("*.lua"),
        *addon_root.glob("*.xml"),
        *addon_root.glob("*.toc"),
    ]
    tool = addon_root / "Tools" / "Export-ZDecursiveDiagnostics.ps1"
    if tool.is_file():
        candidates.append(tool)
    else:
        check.fail("the shipped diagnostics exporter is missing")
    if include_tests:
        candidates.extend((repo_root / "tests").glob("*.lua"))
        candidates.extend((repo_root / "tests").glob("*.ps1"))
    for path in sorted(candidates):
        head = "\n".join(read_text(path).splitlines()[:35])
        relative = path.relative_to(repo_root).as_posix() if path.is_relative_to(repo_root) else path.name
        for marker in HEADER_MARKERS:
            if marker not in head:
                check.fail(f"first-party header in {relative} is missing {marker!r}")


def strip_lua_comments_and_strings(source: str) -> str:
    output: list[str] = []
    index = 0
    length = len(source)
    while index < length:
        char = source[index]
        if source.startswith("--", index):
            long_match = re.match(r"--\[(=*)\[", source[index:])
            if long_match:
                delimiter = "]" + long_match.group(1) + "]"
                end = source.find(delimiter, index + long_match.end())
                index = length if end < 0 else end + len(delimiter)
                output.append("\n")
                continue
            end = source.find("\n", index)
            index = length if end < 0 else end
            output.append("\n")
            continue
        long_match = re.match(r"\[(=*)\[", source[index:])
        if long_match:
            delimiter = "]" + long_match.group(1) + "]"
            end = source.find(delimiter, index + long_match.end())
            index = length if end < 0 else end + len(delimiter)
            output.append(" ")
            continue
        if char in {"'", '"'}:
            quote = char
            index += 1
            while index < length:
                if source[index] == "\\":
                    index += 2
                    continue
                if source[index] == quote:
                    index += 1
                    break
                index += 1
            output.append(" ")
            continue
        output.append(char)
        index += 1
    return "".join(output)


def validate_first_party_lua_style(check: Validation, addon_root: Path) -> None:
    deprecated_globals = (
        "GetSpecialization",
        "GetSpecializationInfo",
        "GetNumSpecializations",
        "GetAddOnMetadata",
        "IsAddOnLoaded",
        "GetAddOnInfo",
        "GetAddOnEnableState",
        "IsPlayerSpell",
        "IsSpellKnown",
        "GetItemCount",
    )
    diagnostic_modules = {
        "Alerts.lua",
        "Detection.lua",
        "Diagnostics.lua",
        "PersistentDiagnostics.lua",
    }
    for path in sorted(addon_root.glob("*.lua")):
        source = read_text(path)
        diagnostic_source = source
        if path.name == "Detection.lua":
            begin = "-- USER_NOTIFICATION_SINK_BEGIN"
            end = "-- USER_NOTIFICATION_SINK_END"
            if source.count(begin) != 1 or source.count(end) != 1:
                check.fail("Detection.lua must contain exactly one bounded ordinary-notification sink")
            else:
                start = source.index(begin)
                stop = source.index(end, start) + len(end)
                diagnostic_source = source[:start] + source[stop:]
        stripped = strip_lua_comments_and_strings(source)
        if ";" in stripped:
            check.fail(f"first-party Lua contains a semicolon: {path.name}")
        if re.search(r"(?<![.\w])print\s*\(", stripped):
            check.fail(f"first-party runtime uses print() instead of copyable diagnostics: {path.name}")
        for name in deprecated_globals:
            if re.search(rf"(?<![.\w:]){name}\b", stripped):
                check.fail(f"first-party Retail runtime references deprecated global {name}: {path.name}")
        if path.name in diagnostic_modules:
            diagnostic_stripped = strip_lua_comments_and_strings(diagnostic_source)
            if re.search(r":\s*Print\s*\(", diagnostic_stripped):
                check.fail(f"diagnostic output uses AceAddon:Print instead of ShowText: {path.name}")
            if re.search(r"\bDEFAULT_CHAT_FRAME\s*:\s*AddMessage\s*\(", diagnostic_stripped):
                check.fail(f"diagnostic output uses DEFAULT_CHAT_FRAME instead of ShowText: {path.name}")


def validate_lua_syntax(check: Validation, addon_root: Path, extra_roots: list[Path] | None = None) -> None:
    files = sorted(addon_root.rglob("*.lua"))
    for root in extra_roots or []:
        files.extend(sorted(root.glob("*.lua")))
    node = os.environ.get("NODE_BINARY") or shutil.which("node")
    parser = Path(__file__).with_name("parse-lua.cjs")
    if not node:
        check.fail("Node.js is unavailable; cannot run the required luaparse Lua 5.1 gate")
        return
    result = subprocess.run(
        [node, str(parser), *(str(path) for path in files)],
        text=True,
        capture_output=True,
        check=False,
    )
    if result.returncode != 0:
        detail = (result.stderr or result.stdout).strip()
        check.fail(f"luaparse Lua 5.1 gate failed (exit {result.returncode}): {detail}")
    else:
        check.note(f"Lua 5.1 syntax: {len(files)} files parsed with luaparse")


def validate_licenses(check: Validation, repo_root: Path | None, addon_root: Path) -> None:
    addon_license = addon_root / "LICENSE.txt"
    if not addon_license.is_file():
        check.fail("ZDecursive/LICENSE.txt is missing")
    else:
        license_text = read_text(addon_license)
        for marker in ("GNU GENERAL PUBLIC LICENSE", "Version 3, 29 June 2007"):
            if marker not in license_text:
                check.fail(f"ZDecursive/LICENSE.txt is not the complete GPLv3 license: missing {marker!r}")
    if repo_root is not None:
        root_license = repo_root / "LICENSE"
        if not root_license.is_file():
            check.fail("root LICENSE is missing")
        elif addon_license.is_file() and root_license.read_bytes() != addon_license.read_bytes():
            check.fail("root LICENSE and ZDecursive/LICENSE.txt are not byte-identical")
    notice = addon_root / "NOTICE.txt"
    if not notice.is_file():
        check.fail("ZDecursive/NOTICE.txt is missing")
    else:
        text = read_text(notice)
        for marker in ("John Wellesz", "Randy Lorfing", "Patrick Bohnet", "Ace3", "LibStub"):
            if marker not in text:
                check.fail(f"ZDecursive/NOTICE.txt is missing attribution for {marker}")
    ace_license = addon_root / "Libs" / "Ace3-LICENSE.txt"
    if not ace_license.is_file() or "Ace3 Development Team" not in read_text(ace_license):
        check.fail("bundled Ace3 license is missing or unrecognized")
    libstub = addon_root / "Libs" / "LibStub" / "LibStub.lua"
    if not libstub.is_file() or "Public Domain" not in read_text(libstub):
        check.fail("bundled LibStub public-domain notice is missing")
    for relative in REQUIRED_LIBRARY_PATHS:
        resolve_exact(check, addon_root, relative, "library inventory")


def validate_tokens(check: Validation, root: Path, source: bool) -> None:
    version_token = token("project-version")
    hash_token = token("project-hash")
    occurrences: list[tuple[str, str]] = []
    for path in relative_files(root):
        relative = path.relative_to(root).as_posix()
        if relative == ".git" or relative.startswith(".git/"):
            continue
        if path.suffix.lower() not in TEXT_SUFFIXES and path.name != ".pkgmeta":
            continue
        try:
            text = read_text(path)
        except (UnicodeDecodeError, OSError):
            continue
        for value, label in ((version_token, "project-version"), (hash_token, "project-hash")):
            for _ in range(text.count(value)):
                occurrences.append((relative, label))
        unresolved = re.findall(r"@(project-[a-z0-9-]+|localization)@", text)
        for value in unresolved:
            if value not in {"project-version", "project-hash"}:
                occurrences.append((relative, value))
    if source:
        expected = sorted([
            ("ZDecursive/ZDecursive.toc", "project-hash"),
            ("ZDecursive/ZDecursive.toc", "project-version"),
        ])
        if sorted(occurrences) != expected:
            check.fail(f"source project-token inventory differs from the contract: {occurrences!r}")
    elif occurrences:
        check.fail(f"packaged output contains unresolved project tokens: {occurrences!r}")


def validate_source_only_absent(check: Validation, addon_root: Path) -> None:
    for path in relative_files(addon_root):
        relative = path.relative_to(addon_root).as_posix()
        folded_parts = {part.casefold() for part in PurePosixPath(relative).parts}
        forbidden = bool(folded_parts & {".git", ".github", "docs", "tests"})
        forbidden = forbidden or (
            path.suffix.lower() in {".b64", ".js", ".md", ".py"}
            and relative != "CHANGELOG.md"
        )
        forbidden = forbidden or path.name in {".gitignore", ".pkgmeta"}
        forbidden = forbidden or path.name.startswith("tmp-")
        if forbidden:
            check.fail(f"source-only file leaked into package: {relative}")
        if path.suffix.lower() == ".ps1" and relative != "Tools/Export-ZDecursiveDiagnostics.ps1":
            check.fail(f"unapproved PowerShell support script in package: {relative}")


def validate_pkgmeta(check: Validation, repo_root: Path) -> None:
    path = repo_root / ".pkgmeta"
    if not path.is_file():
        check.fail(".pkgmeta is missing")
        return
    text = read_text(path)
    required = [
        "package-as: ZDecursive",
        "ZDecursive/ZDecursive: ZDecursive",
        "license-output: LICENSE.txt",
        "- .github",
        "- tests",
        '- "*.md"',
        '- "*.js"',
        '- "*.py"',
        '- "*.b64"',
        '- "tmp-*"',
    ]
    for item in required:
        if item not in text:
            check.fail(f".pkgmeta is missing required one-folder/exclusion directive: {item}")
    if re.search(r"^externals\s*:", text, flags=re.MULTILINE):
        check.fail(".pkgmeta must not fetch duplicate externals; bundled libraries are committed")


def validate_readme(check: Validation, repo_root: Path) -> None:
    path = repo_root / "README.md"
    if not path.is_file():
        check.fail("README.md is missing")
        return
    text = read_text(path)
    for marker in (
        "v13.1.0-alpha",
        "One addon folder: `ZDecursive`",
        "randylorfing/Decursive",
        "DecursiveRebuildDB",
        "ZDecursiveDiagnosticsDB",
        "bounded, sanitized diagnostics",
        "John Wellesz",
        "Randy Lorfing",
    ):
        if marker not in text:
            check.fail(f"README.md is missing release metadata: {marker}")
    if "One addon folder: `Decursive`" in text or "is not this tree" in text:
        check.fail("README.md still contains stale source-repository or folder metadata")


def validate_workflow(check: Validation, repo_root: Path) -> None:
    path = repo_root / ".github" / "workflows" / "verify-zdecursive-release.yml"
    if not path.is_file():
        check.fail("credential-free ZDecursive verification workflow is missing")
        return
    text = read_text(path)
    required = [
        "actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683",
        "36b4c3b7b7bd17c835ad8c83fed4976c067edfbe",
        "- zdecursive",
        "- 'v13.1.0-alpha'",
        "contents: read",
        "luaparse@0.3.1",
        "validate-zdecursive-source.py",
        "validate-zdecursive-package.py",
        "tests/run-fengari.cjs",
        "tests/export-diagnostics-contract.ps1",
        "shell: pwsh",
        "-d \\",
    ]
    for marker in required:
        if marker not in text:
            check.fail(f"verification workflow is missing required marker: {marker}")
    for forbidden in ("secrets.", "CF_API", "CURSEFORGE", "curseforge", "softprops/action-gh-release"):
        if forbidden in text:
            check.fail(f"credential-free workflow contains publishing capability: {forbidden}")
    exporter_contract = repo_root / "tests" / "export-diagnostics-contract.ps1"
    if not exporter_contract.is_file():
        check.fail("functional diagnostics exporter contract is missing")
    else:
        exporter_text = read_text(exporter_contract)
        for marker in (
            "$result.Records -eq 1",
            "$json.schema -eq 1",
            "$json.lastSession -eq 7",
            "$json.records[0].sequence -eq 12",
            "$json.records[0].kind -eq 'ROSTER_CONVERGENCE'",
        ):
            if marker not in exporter_text:
                check.fail(f"functional diagnostics exporter contract is missing assertion: {marker}")


def validate_git_tag(check: Validation, repo_root: Path, release_tag: str | None) -> None:
    if release_tag is None:
        return
    if release_tag != RELEASE_TAG:
        check.fail(f"release tag must be {RELEASE_TAG}, got {release_tag}")
        return
    result = subprocess.run(
        ["git", "tag", "--points-at", "HEAD"],
        cwd=repo_root,
        text=True,
        capture_output=True,
        check=False,
    )
    if result.returncode != 0:
        check.fail(f"cannot inspect tags at HEAD: {result.stderr.strip()}")
        return
    tags = {line.strip() for line in result.stdout.splitlines() if line.strip()}
    if release_tag not in tags:
        check.fail(f"HEAD is not tagged with {release_tag}")


def validate_source(check: Validation, repo_root: Path, release_tag: str | None) -> None:
    repo_root = repo_root.resolve()
    addon_root = repo_root / ADDON
    print(f"Validating ZDecursive source at {repo_root}")
    if not addon_root.is_dir():
        check.fail("source root does not contain ZDecursive/")
        return
    check_case_collisions(check, repo_root, "source tree")
    validate_pkgmeta(check, repo_root)
    validate_readme(check, repo_root)
    validate_workflow(check, repo_root)
    validate_toc_contract(check, addon_root, source=True)
    validate_xml(check, addon_root)
    validate_headers(check, repo_root, addon_root, include_tests=True)
    validate_first_party_lua_style(check, addon_root)
    validate_licenses(check, repo_root, addon_root)
    validate_tokens(check, repo_root, source=True)
    validate_lua_syntax(check, addon_root, [repo_root / "tests"])
    validate_git_tag(check, repo_root, release_tag)


def archive_manifest(check: Validation, archive: Path) -> dict[str, tuple[int, str]]:
    result: dict[str, tuple[int, str]] = {}
    case_seen: dict[str, str] = {}
    try:
        handle = zipfile.ZipFile(archive)
    except (OSError, zipfile.BadZipFile) as error:
        check.fail(f"cannot open ZIP {archive}: {error}")
        return result
    with handle:
        for info in handle.infolist():
            name = info.filename
            if "\\" in name or name.startswith("/") or re.match(r"^[A-Za-z]:", name):
                check.fail(f"ZIP contains an unsafe path: {name!r}")
                continue
            path = PurePosixPath(name)
            if ".." in path.parts:
                check.fail(f"ZIP contains a parent-directory path: {name!r}")
                continue
            folded = name.rstrip("/").casefold()
            prior = case_seen.get(folded)
            normalized_name = name.rstrip("/")
            if prior is not None:
                if prior == normalized_name:
                    check.fail(f"ZIP has a duplicate entry: {name!r}")
                else:
                    check.fail(f"ZIP has a case-insensitive collision: {prior!r} and {name!r}")
            else:
                case_seen[folded] = normalized_name
            if info.is_dir():
                continue
            if not name.startswith(ADDON + "/"):
                check.fail(f"ZIP file is outside the single {ADDON}/ top-level folder: {name}")
                continue
            data = handle.read(info)
            result[name] = (len(data), hashlib.sha256(data).hexdigest())
    if not result:
        check.fail("ZIP has no files")
    return result


def compare_archive_to_expanded(check: Validation, archive: Path, release_root: Path) -> None:
    archived = archive_manifest(check, archive)
    expanded: dict[str, tuple[int, str]] = {}
    addon_root = release_root / ADDON
    for path in relative_files(addon_root):
        name = f"{ADDON}/{path.relative_to(addon_root).as_posix()}"
        expanded[name] = (path.stat().st_size, digest(path))
    if set(archived) != set(expanded):
        check.fail(
            "ZIP/extracted manifest paths differ: "
            f"archive-only={sorted(set(archived) - set(expanded))!r}, "
            f"expanded-only={sorted(set(expanded) - set(archived))!r}"
        )
        return
    for name in sorted(archived):
        if archived[name] != expanded[name]:
            check.fail(f"ZIP/extracted file bytes differ: {name}")


def compare_source_to_package(
    check: Validation,
    source_root: Path,
    addon_root: Path,
    metadata: dict[str, str],
) -> None:
    source_addon = source_root / ADDON
    expected = {path.relative_to(source_addon).as_posix(): path for path in relative_files(source_addon)}
    actual = {path.relative_to(addon_root).as_posix(): path for path in relative_files(addon_root)}
    generated = {"CHANGELOG.md"}
    if set(expected) != set(actual) - generated or set(actual) - set(expected) - generated:
        check.fail(
            "source/package addon manifests differ: "
            f"source-only={sorted(set(expected) - set(actual))!r}, "
            f"package-only={sorted(set(actual) - set(expected) - generated)!r}"
        )
        return
    changelog = actual.get("CHANGELOG.md")
    if changelog is None:
        check.fail("BigWigs generated CHANGELOG.md is missing from the package")
    elif not read_text(changelog).startswith("# Zhaohu's Decursive"):
        check.fail("BigWigs generated CHANGELOG.md has an unexpected title")
    for relative in sorted(expected):
        source_path = expected[relative]
        package_path = actual[relative]
        if relative == "ZDecursive.toc":
            rendered = read_text(source_path)
            rendered = rendered.replace(token("project-version"), metadata.get("Version", ""))
            rendered = rendered.replace(token("project-hash"), metadata.get("X-Zhaohu-Source-Commit", ""))
            if rendered.replace("\r\n", "\n") != read_text(package_path).replace("\r\n", "\n"):
                check.fail("packaged TOC differs from source beyond approved token substitution")
        elif source_path.suffix.lower() in TEXT_SUFFIXES:
            source_text = read_text(source_path).replace("\r\n", "\n")
            package_text = read_text(package_path).replace("\r\n", "\n")
            if source_text != package_text:
                check.fail(f"packaged text differs from source beyond line-ending normalization: {relative}")
        elif digest(source_path) != digest(package_path):
            check.fail(f"packaged binary differs from source: {relative}")


def validate_package(
    check: Validation,
    release_root: Path,
    archive: Path | None,
    source_root: Path | None,
    expected_version: str | None,
    expected_commit: str | None,
    allow_development_version: bool,
) -> None:
    release_root = release_root.resolve()
    print(f"Validating expanded ZDecursive package at {release_root}")
    if not release_root.is_dir():
        check.fail(f"expanded release root does not exist: {release_root}")
        return
    addon_root = release_root / ADDON
    if not addon_root.is_dir():
        check.fail(f"expanded release root must directly contain {ADDON}/")
        return
    allowed_files: set[Path] = set()
    if archive is not None:
        archive = archive.resolve()
        if archive.parent == release_root:
            allowed_files.add(archive)
    for entry in release_root.iterdir():
        if entry == addon_root or entry in allowed_files:
            continue
        check.fail(f"expanded release root has an extra top-level entry: {entry.name}")
    if expected_version is None and not allow_development_version:
        check.fail("release validation requires --expected-version (or explicit --allow-development-version)")
    check_case_collisions(check, addon_root, "expanded package")
    metadata = validate_toc_contract(
        check,
        addon_root,
        source=False,
        expected_version=expected_version,
        expected_commit=expected_commit,
    )
    validate_xml(check, addon_root)
    validate_headers(check, source_root.resolve() if source_root else release_root, addon_root, include_tests=False)
    validate_first_party_lua_style(check, addon_root)
    validate_licenses(check, None, addon_root)
    validate_tokens(check, addon_root, source=False)
    validate_source_only_absent(check, addon_root)
    validate_lua_syntax(check, addon_root)
    if source_root is not None:
        compare_source_to_package(check, source_root.resolve(), addon_root, metadata)
    if archive is not None:
        compare_archive_to_expanded(check, archive, release_root)
