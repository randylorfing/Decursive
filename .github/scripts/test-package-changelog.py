#!/usr/bin/env python3
"""Release-note packaging contracts.

Based on Decursive, Copyright (C) 2006-2026 John Wellesz.
Copyright (C) 2026 Randy Lorfing.
GNU General Public License version 3 or later.
"""
from pathlib import Path
from tempfile import TemporaryDirectory
import contextlib
import io

from zdecursive_validation import Validation, compare_source_to_package

MAPPING = "manual-changelog:\n    filename: .github/RELEASE_NOTES.md\n    markup-type: markdown\n"
TITLE = "# Zhaohu's Decursive v13.1.2\n"

def case(name, mapping=MAPPING, notes=TITLE, extra=False, changed=False, expected=True):
    with TemporaryDirectory() as directory:
        root = Path(directory)
        source = root / 'source'
        package = root / 'package/ZDecursive'
        (source / 'ZDecursive').mkdir(parents=True)
        (source / '.github').mkdir()
        package.mkdir(parents=True)
        (source / '.pkgmeta').write_text(mapping)
        if notes is not None:
            (source / '.github/RELEASE_NOTES.md').write_text(notes)
        (source / 'ZDecursive/Main.lua').write_text('return true\n')
        (package / 'Main.lua').write_text('return false\n' if changed else 'return true\n')
        if extra:
            (package / 'CHANGELOG.md').write_text("# Zhaohu's Decursive\n")
        check = Validation()
        with contextlib.redirect_stderr(io.StringIO()):
            compare_source_to_package(check, source, package, {})
        assert (not check.errors) == expected, (name, check.errors)

case('curated source notes are not shipped')
case('generated history cannot leak into manual package', extra=True, expected=False)
case('missing manual notes cannot fall back', notes=None, expected=False)
case('wrong release title rejected', notes=TITLE.replace('v13.1.2', 'v13.1.2-Alpha'), expected=False)
case('duplicate mappings rejected', mapping=MAPPING + MAPPING, expected=False)
case('unrecognized manual mapping rejected', mapping='manual-changelog: Other.md\n', expected=False)
case('later filename cannot override curated notes', mapping=MAPPING + '    filename: Other.md\n', expected=False)
case('later markup cannot override Markdown', mapping=MAPPING + '    markup-type: html\n', expected=False)
case('extra child key rejected', mapping=MAPPING + '    extra: ignored\n', expected=False)
case('changed runtime rejected', changed=True, expected=False)
case('legacy generated history retained', mapping='', extra=True)
case('legacy missing history rejected', mapping='', expected=False)
print('Package changelog contracts: 12/12 passed')
