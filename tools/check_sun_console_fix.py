"""Verify the playable second-chapter fix against actual raster captures."""
import hashlib
import json
import re
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'builds'
SNAPSHOT = ROOT / '.tools/sun-console-release'
report = json.loads((OUT / 'sun-console-release-verification.json').read_text())
assert report['version'] == '1.12.2' and report['failures'] == []
assert report['functional_tests']['total'] == 561 and report['exported_app_checks'] == 56
frozen = json.loads((OUT / 'sun-console-release-source.json').read_text())['files']
report['renderers'] = {}

def numbers(text):
    return np.array([float(v) for v in re.findall(r'-?\d+(?:\.\d+)?(?:e[+-]?\d+)?', text)])

for method in ['gl_compatibility', 'forward_plus']:
    folder = OUT / 'render-iterations/v1121-sun-console-final' / method
    project = ROOT / '.tools/render-background/v1121-sun-console-final' / method
    audit = json.loads((folder / 'sun-console-render-audit.json').read_text())
    assert audit['failures'] == [] and audit['renderer'] == method and audit['display'] == 'X11'
    assert len(audit['captures']) == 6
    assert 'ERROR:' not in (folder / 'sun_console_render_review-render.log').read_text()
    for name, digest in frozen.items():
        path = Path(name)
        if 'tests' in path.parts or path.suffix in ['.uid', '.import'] or path.name == 'export_presets.cfg':
            continue
        assert hashlib.sha256((project / path).read_bytes()).hexdigest() == digest, (method, name)
    frames = {}
    entries = {entry['name']: entry for entry in audit['captures']}
    for name, entry in entries.items():
        path = folder / (name + '.png')
        rgb = np.asarray(Image.open(path).convert('RGB'), dtype=np.float32)
        assert rgb.shape == (800, 1280, 3) and rgb.std() > 8, name
        frames[name] = rgb
    gray = frames['sun-02-board-grayscale']
    assert float((gray.max(2) - gray.min(2)).max()) == 0
    for name in ['sun-03-board-chapter-colour', 'sun-04-board-full-colour', 'sun-05-board-wrong-module', 'sun-06-board-powered']:
        assert np.allclose(numbers(entries[name]['camera']), numbers(entries['sun-02-board-grayscale']['camera']), atol=.001), name
    # Restrict state differences to the board, excluding the menu and skyline.
    states = [frames[name][350:600, 350:930] for name in ['sun-03-board-chapter-colour', 'sun-05-board-wrong-module', 'sun-06-board-powered']]
    deltas = [float(np.abs(a - b).mean()) for a, b in zip(states, states[1:])]
    assert all(delta > .1 for delta in deltas), (method, deltas)
    report['renderers'][method] = {'captures': {name: hashlib.sha256((folder / (name + '.png')).read_bytes()).hexdigest() for name in entries}, 'same_player_camera_for_board_states': True, 'board_state_mean_rgb_changes': deltas, 'production_matches_exported_app': True}

report['actual_render_captures'] = 12
(OUT / 'sun-console-release-verification.json').write_text(json.dumps(report, indent=2) + '\n')
print('SUN_CONSOLE_FIX_VERIFIED: 561 functional checks; 56 exported-app checks; 12 actual raster captures')
