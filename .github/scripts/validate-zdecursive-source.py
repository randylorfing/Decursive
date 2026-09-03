#!/usr/bin/env python3
"""Validate the maintained ZDecursive source tree before packaging.

Copyright (C) 2006-2026 John Wellesz (upstream Decursive attribution)
Copyright (C) 2026 Randy Lorfing (ZDecursive rebuild and maintenance)
SPDX-License-Identifier: GPL-3.0-or-later
"""

from argparse import ArgumentParser
from pathlib import Path

from zdecursive_validation import Validation, validate_source


def main() -> int:
    parser = ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path.cwd())
    parser.add_argument("--release-tag")
    arguments = parser.parse_args()
    check = Validation()
    validate_source(check, arguments.root, arguments.release_tag)
    return check.finish("ZDecursive source validation")


if __name__ == "__main__":
    raise SystemExit(main())
