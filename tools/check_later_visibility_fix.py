"""Check release source fingerprints and actual first-person raster evidence."""
import hashlib
import json
from pathlib import Path
import re

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'builds'
report = json.loads((OUT / 'later-visibility-release-verification.json').read_text())
frozen = json.loads((OUT / 'later-visibility-release-source.json').read_text())['files']
summary = json.loads((OUT / 'later-visibility-test-summary.json').read_text())
assert report['version'] == '1.12.3' and report['failures'] == []
assert summary['failures'] == [] and len(summary['suites']) == 14
assert summary['suites']['puzzle'] == 266 and summary['suites']['later_visibility'] >= 168
assert report['exported_app_checks'] == summary['suites']['later_visibility']
report['functional_tests'] = summary
report['renderers'] = {}

def numbers(value):
    return np.array([float(v) for v in re.findall(r'-?\d+(?:\.\d+)?(?:e[+-]?\d+)?', value)])

for method in ['gl_compatibility', 'forward_plus']:
    folder = OUT / 'render-iterations/v1123-later-preview' / method
    project = ROOT / '.tools/render-background/v1123-later-preview' / method
    audit = json.loads((folder / 'later-visibility-render-audit.json').read_text())
    assert audit['failures'] == [] and audit['renderer'] == method
    assert audit['display'] == 'X11' and len(audit['captures']) == 26
    for name, digest in audit['source_sha256'].items():assert digest == frozen[name], (method, name)
    assert 'ERROR:' not in (folder / 'later_visibility_render_review-render.log').read_text()
    for name, digest in frozen.items():
        path = Path(name)
        if 'tests' in path.parts or path.suffix in ['.uid', '.import'] or path.name == 'export_presets.cfg':
            continue
        assert hashlib.sha256((project / path).read_bytes()).hexdigest() == digest, (method, name)
    entries = {entry['name']: entry for entry in audit['captures']}
    frames = {}
    hashes = {}
    for name, entry in entries.items():
        assert entry['supported'] and entry['fov'] == 76.0, name
        path = folder / (name + '.png')
        rgb = np.asarray(Image.open(path).convert('RGB'), dtype=np.float32)
        assert rgb.shape == (800, 1280, 3) and rgb.std() > 8, name
        frames[name] = rgb
        hashes[name] = hashlib.sha256(path.read_bytes()).hexdigest()
    pairs = [('later-01-pressure-initial', 'later-02-pressure-correct')]
    pairs += [(f'later-04-mirror-{i}-initial', f'later-05-mirror-{i}-correct') for i in range(2)]
    pairs += [(f'later-11-bed-{i}-initial', f'later-12-bed-{i}-correct') for i in range(3)]
    pairs += [('later-13-roots-initial', 'later-14-roots-correct')]
    differences = {}
    for first, second in pairs:
        assert np.allclose(numbers(entries[first]['camera']), numbers(entries[second]['camera']), atol=.001), first
        delta = float(np.abs(frames[first][280:750, 230:1050] - frames[second][280:750, 230:1050]).mean())
        assert delta > .05, (method, first, delta)
        differences[first] = delta
    assert sum(entry['panel'] == 'record' for entry in entries.values()) == 5
    report['renderers'][method] = {'captures': hashes, 'same_player_camera_for_state_pairs': True,
                                 'state_mean_rgb_changes': differences,
                                 'production_matches_exported_app': True}
report['actual_render_captures'] = 52
(OUT / 'later-visibility-release-verification.json').write_text(json.dumps(report, indent=2) + '\n')
print('LATER_VISIBILITY_FIX_VERIFIED:', summary['total'], 'functional checks;',
      report['exported_app_checks'], 'exported-app checks; 52 actual raster captures')
