#!/usr/bin/env python3
"""Validate an expanded ZDecursive package and its ZIP, when supplied.

Copyright (C) 2006-2026 John Wellesz (upstream Decursive attribution)
Copyright (C) 2026 Randy Lorfing (ZDecursive rebuild and maintenance)
SPDX-License-Identifier: GPL-3.0-or-later
"""

from argparse import ArgumentParser
from pathlib import Path

from zdecursive_validation import Validation, validate_package


def main() -> int:
    parser = ArgumentParser()
    parser.add_argument("release_root", type=Path)
    parser.add_argument("--archive", type=Path)
    parser.add_argument("--source-root", type=Path)
    parser.add_argument("--expected-version")
    parser.add_argument("--expected-source-commit")
    parser.add_argument("--allow-development-version", action="store_true")
    arguments = parser.parse_args()
    check = Validation()
    validate_package(
        check,
        arguments.release_root,
        arguments.archive,
        arguments.source_root,
        arguments.expected_version,
        arguments.expected_source_commit,
        arguments.allow_development_version,
    )
    return check.finish("ZDecursive package validation")


if __name__ == "__main__":
    raise SystemExit(main())
