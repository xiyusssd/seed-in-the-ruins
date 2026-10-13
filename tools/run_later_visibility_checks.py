"""Run the complete game checks plus first-person readout/access regressions."""
import json
import argparse
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
ENGINE = ROOT / '.tools/Godot.app/Contents/MacOS/Godot'
SCENES = ['menu', 'fps', 'puzzle', 'playability', 'wasteland', 'scenery',
          'tutorial', 'audio_animation', 'repair_feedback', 'w01_access',
          'structural_refinement', 'maintenance_record', 'sun_console_access',
          'later_visibility']
results = {}
parser=argparse.ArgumentParser()
parser.add_argument('--version',default='1.12.3')
version=parser.parse_args().version
prefix='v'+version.replace('.','')
for name in SCENES:
    output = ROOT / 'builds' / f'{prefix}-{name}-tests.log'
    with output.open('w') as log:
        subprocess.run([str(ENGINE), '--headless', '--path', str(ROOT / 'game'),
                        f'res://tests/{name}_flow.tscn'], stdout=log,
                       stderr=subprocess.STDOUT, check=True, timeout=240)
    content = output.read_text()
    assert 'failures=[]' in content and 'ERROR:' not in content, output
    results[name] = int(re.findall(r'(\d+) checks; failures=\[\]', content)[-1])
    print(name, results[name], flush=True)
summary = {'version': version, 'suites': results,
           'total': sum(results.values()), 'failures': []}
(ROOT / 'builds' / ('later-visibility-test-summary.json' if version=='1.12.3' else prefix+'-test-summary.json')).write_text(
    json.dumps(summary, indent=2) + '\n')
print('LATER_VISIBILITY_CHECKS_OK', summary['total'])
