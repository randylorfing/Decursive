"""Compare legacy failures against HEAD without modifying the working addon."""
from pathlib import Path
import os
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
NODE = Path('C:/Users/rlorfing/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node.exe')
GIT = 'C:/Program Files/Git/cmd/git.exe'
env = dict(os.environ, NODE_PATH='D:/Projects/ZDecursive-test-tools/fengari/node_modules')
with tempfile.TemporaryDirectory(prefix='zdecursive-combat-baseline-') as temporary:
    baseline = Path(temporary)
    shutil.copytree(ROOT / 'ZDecursive', baseline / 'ZDecursive')
    for filename in ('DetectionEngine.lua', 'Diagnostics.lua', 'MUFPresentation.lua', 'MUFs.lua'):
        original = subprocess.check_output([GIT, '-C', str(ROOT), 'show', 'HEAD:ZDecursive/' + filename])
        (baseline / 'ZDecursive' / filename).write_bytes(original)
    for test in ('muf-cooldown-contract.lua', 'muf-native-presentation-contract.lua',
                 'muf-native-tooltip-contract.lua', 'muf-visual-init-contract.lua'):
        result = subprocess.run([str(NODE), str(ROOT / 'docs/tests/run-fengari.cjs'), str(ROOT / 'docs/tests' / test)],
                                cwd=baseline, env=env, text=True, capture_output=True)
        print(f'{test}: baseline exit={result.returncode}: {result.stderr.strip()}')
